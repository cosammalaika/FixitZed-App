import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';

class HomeService {
  Map<String, String> _headers({String? token}) => {
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      const preferredKeys = [
        'data',
        'results',
        'items',
        'payload',
        'fixers',
        'records',
      ];
      for (final key in preferredKeys) {
        if (!data.containsKey(key)) continue;
        final nested = _extractList(data[key]);
        if (nested.isNotEmpty) return nested;
      }
      for (final value in data.values) {
        final nested = _extractList(value);
        if (nested.isNotEmpty) return nested;
      }
    }
    return const [];
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('${Api.baseUrl}/$path');
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        if (query != null) ...query.map((k, v) => MapEntry(k, '$v')),
      },
    );
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>?> fetchMe() async {
    try {
      final token = await _getToken();
      final res = await http.get(_uri('me'), headers: _headers(token: token));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> fetchCategories() async {
    try {
      final res = await http.get(_uri('categories'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = _extractList(data);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> fetchServices() async {
    try {
      final res = await http.get(_uri('services'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = _extractList(data);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> fetchFixers({int limit = 10}) async {
    try {
      // Prefer new compact top-fixers endpoint when available
      final res = await http.get(
        _uri('fixers/top', {'limit': limit}),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = _extractList(data);
        if (list.isNotEmpty) return list;
      }
      // Fallback to legacy /fixers
      final res2 = await http.get(_uri('fixers'), headers: _headers());
      if (res2.statusCode == 200) {
        final data = jsonDecode(res2.body);
        final list = _extractList(data);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return [];
  }

  /// Fetches the full list of fixers (not just top),
  /// attempting to include service/skills data when the API provides it.
  Future<List<dynamic>> fetchAllFixers() async {
    try {
      // Primary: generic list
      final res = await http.get(_uri('fixers'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = _extractList(data);
        if (list.isNotEmpty) return list;
      }
      // Fallback: sometimes exposed under /users?role=fixer
      final res2 = await http.get(
        _uri('users', {'role': 'fixer'}),
        headers: _headers(),
      );
      if (res2.statusCode == 200) {
        final data = jsonDecode(res2.body);
        final list = _extractList(data);
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    return [];
  }

  /// Best-effort: if your API exposes a list endpoint e.g. GET /coupons
  /// or returns a featured coupon from /coupons?active=1, we try both.
  Future<Map<String, dynamic>?> fetchFeaturedCoupon() async {
    for (final path in ['coupons', 'coupons?active=1']) {
      try {
        final res = await http.get(_uri(path), headers: _headers());
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List && data.isNotEmpty)
            return Map<String, dynamic>.from(data.first as Map);
          if (data is Map) {
            if (data['data'] is List && (data['data'] as List).isNotEmpty) {
              return Map<String, dynamic>.from(
                (data['data'] as List).first as Map,
              );
            }
            return Map<String, dynamic>.from(data as Map);
          }
        }
      } catch (_) {
        // ignore and try next
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchCoupons() async {
    try {
      final res = await http.get(_uri('coupons'), headers: _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = _extractList(data);
        if (list.isNotEmpty) {
          return list
              .whereType<Map>()
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e),
              )
              .toList();
        }
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }
}
