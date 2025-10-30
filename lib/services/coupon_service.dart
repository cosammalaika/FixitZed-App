import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/services/session_guard.dart';

class CouponService {
  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path) => Uri.parse('${Api.baseUrl}/$path');

  Future<Map<String, dynamic>?> validate(
    String code, {
    String? serviceId,
  }) async {
    try {
      final headers = await _headers();
      final res = await http.post(
        _uri('coupons/validate'),
        headers: headers,
        body: jsonEncode({
          'code': code.trim(),
          if (serviceId != null) 'service_id': serviceId,
        }),
      );
      await SessionGuard.evaluate(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map) return Map<String, dynamic>.from(data);
      } else {
        // Fallback: attempt client-side resolution via GET /coupons
        // to handle case-insensitive matches or alternate backends.
        final listRes = await http.get(_uri('coupons'), headers: headers);
        await SessionGuard.evaluate(listRes);
        if (listRes.statusCode == 200) {
          final body = jsonDecode(listRes.body);
          List items;
          if (body is Map && body['data'] is List) {
            items = body['data'] as List;
          } else if (body is List) {
            items = body;
          } else {
            items = const [];
          }
          final idx = items.indexWhere((e) {
            final m = e is Map ? e : null;
            if (m == null) return false;
            final c = (m['code'] ?? '').toString();
            return c.toLowerCase().trim() == code.toLowerCase().trim();
          });
          if (idx >= 0) {
            final item = Map<String, dynamic>.from(items[idx] as Map);
            return {'success': true, 'data': item};
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
