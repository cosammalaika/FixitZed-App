import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fixitzed_app/services/token_storage.dart';

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/core/date_utils.dart';
import 'package:fixitzed_app/services/local_notification_service.dart';
import 'package:fixitzed_app/services/session_guard.dart';
import 'package:fixitzed_app/state/app_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServiceRequestResult {
  const ServiceRequestResult.success()
    : success = true,
      message = null,
      statusCode = null;

  const ServiceRequestResult.failure({required this.message, this.statusCode})
    : success = false;

  final bool success;
  final String? message;
  final int? statusCode;
}

class CancelRequestResult {
  const CancelRequestResult.success({
    required this.request,
    required this.message,
  }) : success = true,
       statusCode = null;

  const CancelRequestResult.failure({required this.message, this.statusCode})
    : success = false,
      request = null;

  final bool success;
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? request;
}

class ServiceRequestService {
  ServiceRequestService({AppSync? sync}) : _sync = sync ?? AppSync.instance;

  final AppSync _sync;

  Map<String, String> _headers({String? token}) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<String?> _getToken() async {
    return TokenStorage.instance.getToken();
  }

  Uri _uri(String path) => Uri.parse('${Api.baseUrl}/$path');

  Future<ServiceRequestResult> _postTo(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final token = await _getToken();
      final res = await http.post(
        _uri(path),
        headers: _headers(token: token),
        body: jsonEncode(payload),
      );
      await SessionGuard.evaluate(res);

      final status = res.statusCode;
      if (status >= 200 && status < 300) {
        return const ServiceRequestResult.success();
      }

      return ServiceRequestResult.failure(
        message: _extractError(res),
        statusCode: status,
      );
    } catch (_) {
      return const ServiceRequestResult.failure(
        message:
            'Unable to reach the server. Check your connection and try again.',
      );
    }
  }

  Future<ServiceRequestResult> createRequest({
    required String serviceId,
    required DateTime scheduledAt,
    required String location,
    double? locationLat,
    double? locationLng,
    String? couponCode,
    String? customerNote,
  }) async {
    // Try common backend paths in order.
    int? asInt(String? v) {
      if (v == null) return null;
      return int.tryParse(v);
    }

    final formattedSchedule = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(scheduledAt.toLocal());
    final payload = <String, dynamic>{
      'service_id': asInt(serviceId) ?? serviceId,
      'scheduled_at': formattedSchedule,
      'location': location,
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,
      if (couponCode != null && couponCode.isNotEmpty)
        'coupon_code': couponCode,
    };
    final note = customerNote?.trim();
    if (note != null && note.isNotEmpty) {
      payload['customer_note'] = note;
    }
    var lastResult = const ServiceRequestResult.failure(
      message: 'Service unavailable.',
    );
    for (final path in ['requests', 'service-requests', 'bookings']) {
      final result = await _postTo(path, payload);
      if (result.success) {
        _sync.emit(
          AppSyncTopic.bookings,
          payload: <String, dynamic>{
            'action': 'create',
            'serviceId': serviceId,
            'scheduledAt': formattedSchedule,
            'location': location,
          },
        );
        _sync.emit(
          AppSyncTopic.dashboard,
          payload: const <String, dynamic>{'source': 'bookings'},
        );
        return result;
      }
      if (result.statusCode == 404) {
        // Ignore missing legacy routes and try the next fallback.
        continue;
      }
      lastResult = result;
    }
    return lastResult;
  }

  Future<CancelRequestResult> cancelRequest(
    int requestId, {
    required String reasonKey,
    String? note,
  }) async {
    final trimmedNote = note?.trim();
    final payload = <String, dynamic>{
      'reason_key': reasonKey,
      if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
    };

    try {
      final token = await _getToken();
      final headers = _headers(token: token);
      final postEndpoints = [
        'requests/$requestId/cancel',
        'service-requests/$requestId/cancel',
      ];
      var lastResult = const CancelRequestResult.failure(
        message: 'Unable to cancel this booking right now.',
      );
      for (final path in postEndpoints) {
        final res = await http.post(
          _uri(path),
          headers: headers,
          body: jsonEncode(payload),
        );
        await SessionGuard.evaluate(res);
        if (res.statusCode == 404) {
          continue;
        }
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final body = jsonDecode(res.body);
          final request = _unwrapRequestMap(body);
          _sync.emit(
            AppSyncTopic.bookings,
            payload: <String, dynamic>{
              'action': 'cancel',
              'requestId': requestId,
            },
          );
          _sync.emit(
            AppSyncTopic.dashboard,
            payload: const <String, dynamic>{'source': 'bookings'},
          );
          return CancelRequestResult.success(
            request: request,
            message: _extractMessage(res) ?? 'Booking cancelled successfully.',
          );
        }

        lastResult = CancelRequestResult.failure(
          message: _extractError(res),
          statusCode: res.statusCode,
        );
      }

      return lastResult;
    } catch (_) {
      return const CancelRequestResult.failure(
        message:
            'Unable to reach the server. Check your connection and try again.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> listRequests() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        _uri('requests'),
        headers: _headers(token: token),
      );
      await SessionGuard.evaluate(res);
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
        final mapped = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _maybeNotifyStatus(mapped);
        return mapped;
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>?> getRequest(int id) async {
    try {
      final token = await _getToken();
      final headers = _headers(token: token);
      for (final path in [
        'requests/$id',
        'service-requests/$id',
        'bookings/$id',
      ]) {
        final res = await http.get(_uri(path), headers: headers);
        await SessionGuard.evaluate(res);
        if (res.statusCode == 404) continue;
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = jsonDecode(res.body);
          final map = _unwrapRequestMap(data);
          if (map != null) return map;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _maybeNotifyStatus(List<Map<String, dynamic>> requests) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStatuses = prefs.getString('request_status_cache');
      final cachedFixers = prefs.getString('request_fixer_cache');
      final previousStatuses = cachedStatuses != null
          ? _decodeStatusCache(cachedStatuses)
          : <String, String>{};
      final previousFixers = cachedFixers != null
          ? _decodeStatusCache(cachedFixers)
          : <String, String>{};

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

      await prefs.setString(
        'request_status_cache',
        jsonEncode(currentStatuses),
      );
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
      final resolved = stringify(
        fixer['id'] ?? fixer['fixer_id'] ?? fixer['user_id'],
      );
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
    final fallback = (req['service_name'] ?? req['serviceTitle'] ?? 'Service')
        .toString();
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

  String _extractError(http.Response res) {
    String? message;
    try {
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) {
        final msg = data['message'];
        if (msg is String && msg.trim().isNotEmpty) {
          message = msg.trim();
        } else if (data['errors'] is Map) {
          final errors = data['errors'] as Map;
          for (final entry in errors.entries) {
            final value = entry.value;
            if (value is List && value.isNotEmpty) {
              message = value.first.toString();
              break;
            }
            if (value != null) {
              message = value.toString();
              break;
            }
          }
        }
      }
    } catch (_) {}

    if (message != null && message.isNotEmpty) {
      return message;
    }

    switch (res.statusCode) {
      case 401:
        return 'Your session expired. Please sign in again.';
      case 403:
        return 'Please verify your account before booking a service.';
      case 404:
        return 'Booking service is temporarily unavailable.';
      case 422:
        return 'We could not validate the booking details. Please review and try again.';
      case 429:
        return 'Too many attempts. Wait a moment and try again.';
      default:
        return 'The server rejected the booking (status ${res.statusCode}).';
    }
  }

  String? _extractMessage(http.Response res) {
    try {
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {}

    return null;
  }
}

Map<String, String> _decodeStatusCache(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is Map) {
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }
  return <String, String>{};
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

Map<String, dynamic>? _unwrapRequestMap(dynamic data) {
  if (data is Map<String, dynamic>) {
    for (final key in ['data', 'request', 'service_request', 'booking']) {
      final inner = data[key];
      if (inner is Map) return Map<String, dynamic>.from(inner);
    }
    return Map<String, dynamic>.from(data);
  }
  return null;
}
