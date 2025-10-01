import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';

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
    String? fixerId,
    required DateTime scheduledAt,
    required String location,
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
      if (fixerId != null) 'fixer_id': asInt(fixerId) ?? fixerId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'location': location,
      'status': status,
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
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
