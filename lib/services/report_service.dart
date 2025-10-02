import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportService {
  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final h = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Future<bool> submit({
    required String type, // 'user' or 'fixer'
    required String subject,
    required String message,
    int? targetId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${Api.baseUrl}/reports'),
        headers: await _headers(),
        body: jsonEncode({
          'type': type,
          'subject': subject,
          'message': message,
          if (targetId != null) 'target_id': targetId,
        }),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {}
    return false;
  }
}

