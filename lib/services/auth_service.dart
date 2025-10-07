// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';

class AuthResult {
  final bool success;
  final String? message;
  final List<String> errors;

  const AuthResult({required this.success, this.message, this.errors = const []});

  String? get displayMessage {
    if (message != null && message!.trim().isNotEmpty) {
      return message!.trim();
    }
    if (errors.isNotEmpty) {
      return errors.join('\n');
    }
    return null;
  }
}

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
  Future<bool> login(String identifier, String password) async {
    try {
      final res = await _postJson('login', {
        'identifier': identifier,
        'password': password,
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final token = _extractToken(data);
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
  Future<AuthResult> register(
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
        final data = jsonDecode(res.body);
        final token = _extractToken(data);
        if (token == null || token.isEmpty) {
          return const AuthResult(
            success: false,
            message: 'Registration succeeded but no access token was returned.',
          );
        }
        await _saveToken(token);
        final msg = _extractMessage(data);
        return AuthResult(success: true, message: msg);
      }
      return _mapError(res);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Unable to reach the server. Please try again.',
      );
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
  /// Be tolerant of different API shapes (endpoints, methods, field names).
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return false;

      final trimmedFirst = firstName?.trim();
      final trimmedLast = lastName?.trim();
      final trimmedEmail = email?.trim();

      // Build a body that covers common naming conventions.
      final body = <String, dynamic>{};
      if (trimmedFirst != null && trimmedFirst.isNotEmpty) {
        body['first_name'] = trimmedFirst;
        body['firstName'] = trimmedFirst; // some APIs use camelCase
      }
      if (trimmedLast != null && trimmedLast.isNotEmpty) {
        body['last_name'] = trimmedLast;
        body['lastName'] = trimmedLast; // camelCase variant
      }
      if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
        body['email'] = trimmedEmail;
      }
      final fullName = [trimmedFirst, trimmedLast]
          .where((s) => s != null && s!.isNotEmpty)
          .map((s) => s!)
          .join(' ')
          .trim();
      if (fullName.isNotEmpty) {
        body['name'] = fullName; // Laravel Jetstream style
        body['full_name'] = fullName;
      }
      if (body.isEmpty) return false;

      // Try a series of common endpoints/methods used by Laravel/Node backends.
      final endpoints = <String>[
        'me',
        'profile',
        'user',
        'users/me',
        'user/profile-information', // Jetstream
        'profile/update',
        'users/profile',
      ];
      for (final path in endpoints) {
        // Try PATCH, then PUT, then POST
        try {
          final resPatch = await _patchJson(path, body, token: token);
          if (resPatch.statusCode >= 200 && resPatch.statusCode < 300) {
            return true;
          }
        } catch (_) {}
        try {
          final resPut = await _putJson(path, body, token: token);
          if (resPut.statusCode >= 200 && resPut.statusCode < 300) {
            return true;
          }
        } catch (_) {}
        try {
          final resPost = await _postJson(path, body, token: token);
          if (resPost.statusCode >= 200 && resPost.statusCode < 300) {
            return true;
          }
        } catch (_) {}
      }
      return false;
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

  String? _extractToken(dynamic data) {
    if (data is Map<String, dynamic>) {
      final direct = data['token'] ?? data['access_token'];
      if (direct is String && direct.isNotEmpty) return direct;

      final nestedData = data['data'];
      if (nestedData is Map) {
        final innerToken = nestedData['token'] ?? nestedData['access_token'];
        if (innerToken is String && innerToken.isNotEmpty) return innerToken;
      }

      final authorisation = data['authorisation'];
      if (authorisation is Map) {
        final authToken = authorisation['token'] ?? authorisation['access_token'];
        if (authToken is String && authToken.isNotEmpty) return authToken;
      }
    }
    return null;
  }

  String? _extractMessage(dynamic data) {
    if (data is Map) {
      final msg = data['message'] ?? data['msg'] ?? data['status'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    return null;
  }

  AuthResult _mapError(http.Response res) {
    String? message;
    final errors = <String>[];
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        final msg = body['message'] ?? body['error'] ?? body['status'];
        if (msg is String && msg.trim().isNotEmpty) {
          message = msg.trim();
        }
        final err = body['errors'];
        if (err is Map) {
          err.forEach((_, value) {
            if (value is List) {
              errors.addAll(value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty));
            } else if (value != null) {
              final text = value.toString();
              if (text.trim().isNotEmpty) errors.add(text);
            }
          });
        }
      }
    } catch (_) {
      // leave message/errors as collected
    }

    message ??= res.statusCode >= 500
        ? 'Our servers are busy right now. Please try again shortly.'
        : 'Please double-check your details and try again.';

    return AuthResult(success: false, message: message, errors: errors);
  }
}
