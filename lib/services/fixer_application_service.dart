import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';

class FixerApplicationService {
  Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<bool> apply({required String bio, required List<int> serviceIds}) async {
    final token = await _token();
    if (token == null) return false;
    final res = await http.post(
      Uri.parse('${Api.baseUrl}/fixer/apply'),
      headers: _headers(token),
      body: jsonEncode({
        'bio': bio,
        'service_ids': serviceIds,
      }),
    );
    return res.statusCode >= 200 && res.statusCode < 300;
  }
}
