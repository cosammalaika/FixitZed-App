// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';

  /// WHY: Ensure Laravel returns JSON validation; send JSON bodies for consistency.
  Map<String, String> _headers({String? token}) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => Uri.parse('${Api.baseUrl}/$path');

  Future<http.Response> _postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return http.post(
      _uri(path),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> _patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return http.patch(
      _uri(path),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> _putJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return http.put(
      _uri(path),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Returns true if authenticated and token saved.
  Future<bool> login(String email, String password) async {
    try {
      final res = await _postJson('login', {
        'email': email,
        'password': password,
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        String? token;
        if (data is Map<String, dynamic>) {
          // Common token shapes across Laravel stacks
          token = (data['token'] ?? data['access_token'])?.toString();
          if ((token == null || token.isEmpty) && data['data'] is Map) {
            final d = data['data'] as Map;
            token = (d['token'] ?? d['access_token'])?.toString();
          }
          if ((token == null || token.isEmpty) && data['authorisation'] is Map) {
            final a = data['authorisation'] as Map;
            token = (a['token'] ?? a['access_token'])?.toString();
          }
        }
        if (token != null && token.isNotEmpty) {
          await _saveToken(token);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Registers a user. Always sends required fields and
  /// conditionally includes optional fields like address/username when provided.
  Future<bool> register(
    String name,
    String email,
    String phone,
    String password, {
    String? address,
    String? username,
  }) async {
    try {
      final body = <String, dynamic>{
        'name': name,
        'email': email,
        'contact_number': phone,
        'password': password,
      };

      final addr = address?.trim();
      if (addr != null && addr.isNotEmpty) {
        body['address'] = addr;
      }

      final user = username?.trim();
      if (user != null && user.isNotEmpty) {
        body['username'] = user;
      }

      final res = await _postJson('register', body);

      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = (data['token'] ?? '') as String;
        if (token.isEmpty) return false;
        await _saveToken(token);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final token = await _getToken();
      if (token != null && token.isNotEmpty) {
        await http.post(
          _uri('logout'),
          headers: _headers(token: token),
          body: jsonEncode({}),
        );
      }
    } catch (_) {
      // WHY: Network/API failures shouldn't block local logout.
    } finally {
      await _clearToken();
    }
  }

  /// Updates the authenticated user's profile.
  /// Tries PATCH /me with the provided fields; returns true on 2xx.
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    try {
      final token = await _getToken();
      final body = <String, dynamic>{};
      if (firstName != null) body['first_name'] = firstName;
      if (lastName != null) body['last_name'] = lastName;
      if (email != null) body['email'] = email;
      if (body.isEmpty) return false;

      final res = await _patchJson('me', body, token: token);
      if (res.statusCode >= 200 && res.statusCode < 300) return true;

      // Fallback: some backends use /profile
      final res2 = await _patchJson('profile', body, token: token);
      return res2.statusCode >= 200 && res2.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Changes the authenticated user's password. Tries common API shapes.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await _getToken();
      final commonBody = <String, dynamic>{
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPassword,
      };

      // Try typical endpoints (Laravel/Sanctum/Jetstream-style)
      final attempts = <Future<http.Response>>[
        _postJson('password', commonBody, token: token),
        _postJson('change-password', commonBody, token: token),
        _patchJson('me/password', commonBody, token: token),
        _putJson('me/password', commonBody, token: token),
        _patchJson('profile/password', commonBody, token: token),
      ];

      for (final fut in attempts) {
        try {
          final res = await fut;
          if (res.statusCode >= 200 && res.statusCode < 300) return true;
        } catch (_) {
          // ignore and try next
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
