import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../core/date_utils.dart';
import 'local_notification_service.dart';

class ServiceRequestService {
  Map<String, String> _headers({String? token}) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Uri _uri(String path) => Uri.parse('${Api.baseUrl}/$path');

  Future<bool> _postTo(String path, Map payload) async {
    try {
      final token = await _getToken();
      final res = await http.post(
        _uri(path),
        headers: _headers(token: token),
        body: jsonEncode(payload),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createRequest({
    required String serviceId,
    required DateTime scheduledAt,
    required String location,
    double? locationLat,
    double? locationLng,
    String status = 'pending',
    String? couponCode,
  }) async {
    // Try common backend paths in order.
    int? asInt(String? v) {
      if (v == null) return null;
      return int.tryParse(v);
    }
    final payload = <String, dynamic>{
      'service_id': asInt(serviceId) ?? serviceId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'location': location,
      'status': status,
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,
      if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
    };
    for (final path in [
      'requests',
      'service-requests',
      'bookings',
    ]) {
      final ok = await _postTo(path, payload);
      if (ok) return true;
    }
    return false;
  }

  Future<bool> cancelRequest(int requestId) async {
    try {
      final token = await _getToken();
      final headers = _headers(token: token);
      final postEndpoints = [
        'requests/$requestId/cancel',
        'service-requests/$requestId/cancel',
      ];
      for (final path in postEndpoints) {
        final res = await http.post(_uri(path), headers: headers);
        if (res.statusCode >= 200 && res.statusCode < 300) return true;
      }

      final res = await http.patch(
        _uri('requests/$requestId'),
        headers: headers,
        body: jsonEncode({'status': 'cancelled'}),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> listRequests() async {
    try {
      final token = await _getToken();
      final res = await http.get(_uri('requests'), headers: _headers(token: token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List list;
        if (data is List) {
          list = data;
        } else if (data is Map) {
          final candidates = ['data', 'results', 'items', 'requests'];
          List? inner;
          for (final k in candidates) {
            if (data[k] is List) {
              inner = data[k] as List;
              break;
            }
          }
          list = inner ?? data.values.whereType<List>().firstOrNull ?? [];
        } else {
          list = [];
        }
        final mapped =
            list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        await _maybeNotifyStatus(mapped);
        return mapped;
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<void> _maybeNotifyStatus(List<Map<String, dynamic>> requests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStatuses = prefs.getString('request_status_cache');
      final cachedFixers = prefs.getString('request_fixer_cache');
      final previousStatuses =
          cachedStatuses != null ? _decodeStatusCache(cachedStatuses) : <String, String>{};
      final previousFixers =
          cachedFixers != null ? _decodeStatusCache(cachedFixers) : <String, String>{};

      final currentStatuses = <String, String>{};
      final currentFixers = <String, String>{};
      final suppressInitialNotifications =
          previousStatuses.isEmpty && previousFixers.isEmpty;

      for (final req in requests) {
        final id = _extractId(req);
        if (id == null) continue;
        final status = _extractStatus(req);
        final statusValue = status ?? '';
        currentStatuses[id] = statusValue;

        final fixerId = _extractFixerId(req) ?? '';
        currentFixers[id] = fixerId;

        if (suppressInitialNotifications) {
          continue;
        }

        final previousStatus = previousStatuses[id];
        final previousFixerId = previousFixers[id] ?? '';

        final service = _extractServiceName(req);
        final scheduled = parseAppDate(
          req['scheduled_at'] ?? req['scheduledAt'] ?? req['schedule'],
        );
        final when = scheduled != null
            ? DateFormat('d MMM HH:mm').format(scheduled)
            : null;

        if (status != null && previousStatus != status) {
          final normalized = _normalizeStatus(status);
          if (normalized != null) {
            final title = normalized == 'accepted'
                ? 'Request accepted'
                : 'Fixer sent a bill';
            final body = normalized == 'accepted'
                ? 'Your $service request is confirmed${when != null ? ' for $when' : ''}.'
                : 'A payment request has been issued${when != null ? ' • due $when' : ''}.';

            await LocalNotificationService.instance.showInstant(
              id: id.hashCode ^ normalized.hashCode,
              title: title,
              body: body,
              payload: 'booking_status:$id:$normalized',
            );
          }
        }

        final hasNewFixer = previousFixerId != fixerId && fixerId.isNotEmpty;
        if (hasNewFixer) {
          await LocalNotificationService.instance.showInstant(
            id: id.hashCode ^ fixerId.hashCode,
            title: 'Fixer found',
            body:
                'We matched your $service request${when != null ? ' for $when' : ''}. Waiting for the fixer to accept.',
            payload: 'booking_status:$id:fixer_pending_acceptance',
          );
        }
      }

      await prefs.setString('request_status_cache', jsonEncode(currentStatuses));
      await prefs.setString('request_fixer_cache', jsonEncode(currentFixers));
    } catch (_) {
      // Swallow errors to keep fetch resilient.
    }
  }

  String? _extractId(Map<String, dynamic> req) {
    final raw = req['id'] ?? req['uuid'] ?? req['reference'];
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  String? _extractStatus(Map<String, dynamic> req) {
    final raw = req['status'] ?? req['state'];
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  String? _extractFixerId(Map<String, dynamic> req) {
    String? stringify(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty || text == '0') return null;
      return text;
    }

    for (final key in [
      'fixer_id',
      'fixerId',
      'assigned_fixer_id',
      'assignedFixerId',
      'fixer_user_id',
    ]) {
      final resolved = stringify(req[key]);
      if (resolved != null) return resolved;
    }

    final fixer = req['fixer'];
    if (fixer is Map) {
      final resolved = stringify(fixer['id'] ?? fixer['fixer_id'] ?? fixer['user_id']);
      if (resolved != null) return resolved;
    }

    return null;
  }

  String _extractServiceName(Map<String, dynamic> req) {
    final service = req['service'];
    if (service is Map) {
      final name = (service['name'] ?? service['title']).toString().trim();
      if (name.isNotEmpty) return name;
    }
    final fallback = (req['service_name'] ?? req['serviceTitle'] ?? 'Service').toString();
    return fallback.trim().isEmpty ? 'Service' : fallback.trim();
  }

  String? _normalizeStatus(String status) {
    final value = status.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    switch (value) {
      case 'accepted':
        return 'accepted';
      case 'awaitingpayment':
      case 'awaitingbill':
      case 'awaitinginvoice':
      case 'awaitingcustomerpayment':
        return 'awaiting_payment';
      default:
        return null;
    }
  }
}

Map<String, String> _decodeStatusCache(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
  }
  return <String, String>{};
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
