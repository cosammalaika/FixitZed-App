import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/services/session_guard.dart';

class LocationsService {
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

  Future<List<Map<String, dynamic>>> list() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        _uri('locations'),
        headers: _headers(token: token),
      );
      await SessionGuard.evaluate(res);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List list;
        if (data is List) {
          list = data;
        } else if (data is Map) {
          list = (data['data'] is List) ? data['data'] as List : [];
        } else {
          list = [];
        }
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }
}
