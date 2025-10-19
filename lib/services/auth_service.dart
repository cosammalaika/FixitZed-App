// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api.dart';

class AuthResult {
  final bool success;
  final String? message;
  final List<String> errors;

  const AuthResult({
    required this.success,
    this.message,
    this.errors = const [],
  });

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

  /// Logs in with identifier/email/phone and returns the outcome.
  Future<AuthResult> login(String identifier, String password) async {
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
          final Map<String, dynamic>? user = data['user'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data['user'] as Map)
              : null;
          final statusRaw = user?['status'] ?? user?['account_status'] ?? user?['accountStatus'];
          final status = statusRaw is String ? statusRaw.trim().toLowerCase() : null;
          if (status != null && status.isNotEmpty && status != 'active') {
            await _clearToken();
            return const AuthResult(
              success: false,
              message: 'inactive',
            );
          }
          final msg = _extractMessage(data);
          return AuthResult(success: true, message: msg);
        }
      }
      if (res.statusCode == 200 || res.statusCode == 201) {
        return const AuthResult(
          success: false,
          message: 'Login succeeded but no access token was returned.',
        );
      }
      return _mapError(res);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Unable to reach the server. Please try again.',
      );
    }
  }

  /// Registers a user with province/district selections and optional username.
  Future<AuthResult> register({
    required String firstName,
    String? lastName,
    required String email,
    required String phone,
    required String password,
    required String province,
    required String district,
    String? username,
  }) async {
    try {
      final trimmedLast = lastName?.trim();
      final trimmedUser = username?.trim();
      final displayName = [
        firstName.trim(),
        if (trimmedLast != null && trimmedLast.isNotEmpty) trimmedLast,
      ].where((part) => part.isNotEmpty).join(' ');

      final body = <String, dynamic>{
        'first_name': firstName.trim(),
        if (trimmedLast != null && trimmedLast.isNotEmpty) 'last_name': trimmedLast,
        if (displayName.isNotEmpty) 'name': displayName,
        'email': email,
        'contact_number': phone,
        'password': password,
        'province': province,
        'district': district,
      };

      if (trimmedUser != null && trimmedUser.isNotEmpty) {
        body['username'] = trimmedUser;
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

  Future<AuthResult> forgotPassword(String identifier) async {
    try {
      final res = await _postJson('password/forgot', {
        'identifier': identifier,
      });

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        final msg = _extractMessage(data) ??
            'If we find a matching account, a reset code will be emailed shortly.';
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

  Future<AuthResult> resetPassword({
    required String identifier,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final res = await _postJson('password/reset', {
        'identifier': identifier,
        'token': token,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        final msg = _extractMessage(data) ??
            'Password updated successfully. You can now sign in.';
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

  Future<bool> updateProfilePhoto(String path) async {
    try {
      final trimmed = path.trim();
      if (trimmed.isEmpty) return false;
      final token = await _getToken();
      if (token == null || token.isEmpty) return false;

      final request = http.MultipartRequest('POST', _uri('me'))
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['_method'] = 'PATCH';

      request.files.add(
        await http.MultipartFile.fromPath('profile_photo', trimmed),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return response.statusCode >= 200 && response.statusCode < 300;
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
        final authToken =
            authorisation['token'] ?? authorisation['access_token'];
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
              errors.addAll(
                value
                    .map((e) => e.toString())
                    .where((e) => e.trim().isNotEmpty),
              );
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
