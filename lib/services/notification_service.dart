import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';

class NotificationService {
  Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Uri _uri(String path) => Uri.parse('${Api.baseUrl}/$path');

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<List<Map<String, dynamic>>> fetch({int page = 1}) async {
    try {
      final token = await _token();
      if (token == null || token.isEmpty) return [];
      final res = await http.get(_uri('notifications?page=$page'), headers: _headers(token));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is List) {
          return body.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        if (body is Map) {
          // Laravel: { success: true, data: { data: [...], ...pagination } }
          final data = body['data'];
          if (data is Map && data['data'] is List) {
            return (data['data'] as List)
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
          if (data is List) {
            return data.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      }
    } catch (_) {}
    return [];
  }

  Future<bool> markRead(int id) async {
    try {
      final token = await _token();
      if (token == null || token.isEmpty) return false;
      final res = await http.patch(_uri('notifications/$id/read'), headers: _headers(token), body: jsonEncode({}));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllRead() async {
    try {
      final token = await _token();
      if (token == null || token.isEmpty) return false;
      final res = await http.post(_uri('notifications/read-all'), headers: _headers(token), body: jsonEncode({}));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
