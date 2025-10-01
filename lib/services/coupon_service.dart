import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/api.dart';

class CouponService {
  Map<String, String> _headers() => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Uri _uri(String path) => Uri.parse('${Api.baseUrl}/$path');

  Future<Map<String, dynamic>?> validate(String code, {String? serviceId}) async {
    try {
      final res = await http.post(
        _uri('coupons/validate'),
        headers: _headers(),
        body: jsonEncode({
          'code': code,
          if (serviceId != null) 'service_id': serviceId,
        }),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } catch (_) {}
    return null;
  }
}

