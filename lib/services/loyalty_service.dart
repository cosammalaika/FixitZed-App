import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/services/session_guard.dart';

class LoyaltyService {
  Future<Map<String, dynamic>?> summary() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return null;

    final res = await http.get(
      Uri.parse('${Api.baseUrl}/loyalty'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    await SessionGuard.evaluate(res);

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body is Map && body['data'] is Map) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
    }
    return null;
  }
}
