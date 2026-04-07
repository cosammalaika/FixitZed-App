// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/services/api_client.dart';
import 'package:fixitzed_app/state/app_sync.dart';
import 'package:fixitzed_app/services/session_manager.dart';
import 'package:fixitzed_app/services/fcm_service.dart';

class AuthResult {
  final bool success;
  final String? message;
  final List<String> errors;
  final Map<String, String> fieldErrors;

  const AuthResult({
    required this.success,
    this.message,
    this.errors = const [],
    this.fieldErrors = const {},
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

  String? fieldErrorFor(Iterable<String> keys) {
    for (final key in keys) {
      final value = fieldErrors[key];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}

class AvatarUploadDebugSnapshot {
  final String? filePath;
  final int? fileSizeBytes;
  final String? requestUrl;
  final int? uploadStatusCode;
  final String uploadResponseSnippet;
  final String uploadResponseHeadersSnippet;
  final int? meStatusCode;
  final String meResponseSnippet;
  final String? meProfilePhotoPath;
  final String? meProfilePhotoUrl;
  final String? meAvatarUrl;
  final String? meResolvedAvatarUrl;
  final String? meAvatarVersionToken;
  final String? error;
  final DateTime? updatedAt;

  const AvatarUploadDebugSnapshot({
    this.filePath,
    this.fileSizeBytes,
    this.requestUrl,
    this.uploadStatusCode,
    this.uploadResponseSnippet = '',
    this.uploadResponseHeadersSnippet = '',
    this.meStatusCode,
    this.meResponseSnippet = '',
    this.meProfilePhotoPath,
    this.meProfilePhotoUrl,
    this.meAvatarUrl,
    this.meResolvedAvatarUrl,
    this.meAvatarVersionToken,
    this.error,
    this.updatedAt,
  });

  AvatarUploadDebugSnapshot copyWith({
    String? filePath,
    int? fileSizeBytes,
    String? requestUrl,
    int? uploadStatusCode,
    String? uploadResponseSnippet,
    String? uploadResponseHeadersSnippet,
    int? meStatusCode,
    String? meResponseSnippet,
    String? meProfilePhotoPath,
    String? meProfilePhotoUrl,
    String? meAvatarUrl,
    String? meResolvedAvatarUrl,
    String? meAvatarVersionToken,
    String? error,
    DateTime? updatedAt,
    bool clearError = false,
  }) {
    return AvatarUploadDebugSnapshot(
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      requestUrl: requestUrl ?? this.requestUrl,
      uploadStatusCode: uploadStatusCode ?? this.uploadStatusCode,
      uploadResponseSnippet:
          uploadResponseSnippet ?? this.uploadResponseSnippet,
      uploadResponseHeadersSnippet:
          uploadResponseHeadersSnippet ?? this.uploadResponseHeadersSnippet,
      meStatusCode: meStatusCode ?? this.meStatusCode,
      meResponseSnippet: meResponseSnippet ?? this.meResponseSnippet,
      meProfilePhotoPath: meProfilePhotoPath ?? this.meProfilePhotoPath,
      meProfilePhotoUrl: meProfilePhotoUrl ?? this.meProfilePhotoUrl,
      meAvatarUrl: meAvatarUrl ?? this.meAvatarUrl,
      meResolvedAvatarUrl: meResolvedAvatarUrl ?? this.meResolvedAvatarUrl,
      meAvatarVersionToken: meAvatarVersionToken ?? this.meAvatarVersionToken,
      error: clearError ? null : (error ?? this.error),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AuthService {
  AuthService({AppSync? sync}) : _sync = sync ?? AppSync.instance;

  final AppSync _sync;
  static final ValueNotifier<AvatarUploadDebugSnapshot> avatarUploadDebug =
      ValueNotifier<AvatarUploadDebugSnapshot>(
        const AvatarUploadDebugSnapshot(),
      );

  Uri _uri(String path) => Uri.parse('${Api.baseUrl}/$path');

  Future<http.Response> _postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return ApiClient.instance.post(path, body: body, auth: token != null);
  }

  Future<http.Response> _patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return ApiClient.instance.patch(path, body: body, auth: token != null);
  }

  Future<http.Response> _putJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return ApiClient.instance.put(path, body: body, auth: token != null);
  }

  Future<void> _saveToken(String token) {
    return SessionManager.instance.storeToken(token);
  }

  Future<String?> _getToken() {
    return SessionManager.instance.readToken();
  }

  Future<void> _clearToken() {
    return SessionManager.instance.removeToken();
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
          final user = data['user'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data['user'] as Map)
              : null;
          final statusRaw =
              user?['status'] ??
              user?['account_status'] ??
              user?['accountStatus'];
          final status = statusRaw is String
              ? statusRaw.trim().toLowerCase()
              : null;
          if (status != null && status.isNotEmpty && status != 'active') {
            await _clearToken();
            return const AuthResult(success: false, message: 'inactive');
          }
          final msg = _extractMessage(data);
          _sync.emit(
            AppSyncTopic.profile,
            payload: const <String, dynamic>{'action': 'login'},
          );
          _sync.emit(
            AppSyncTopic.auth,
            payload: const <String, dynamic>{'action': 'login'},
          );
          _sync.emit(
            AppSyncTopic.dashboard,
            payload: const <String, dynamic>{'source': 'auth'},
          );
          _sync.emit(
            AppSyncTopic.notifications,
            payload: const <String, dynamic>{'source': 'auth'},
          );
          _sync.emit(
            AppSyncTopic.bookings,
            payload: const <String, dynamic>{'source': 'auth'},
          );
          _sync.emit(
            AppSyncTopic.wallet,
            payload: const <String, dynamic>{'source': 'auth'},
          );
          await FcmService.instance.registerTokenForCurrentUser();
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
        if (trimmedLast != null && trimmedLast.isNotEmpty)
          'last_name': trimmedLast,
        if (displayName.isNotEmpty) 'name': displayName,
        'email': email.trim().toLowerCase(),
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
        await FcmService.instance.registerTokenForCurrentUser();
        final msg = _extractMessage(data);
        _sync.emit(
          AppSyncTopic.profile,
          payload: const <String, dynamic>{'action': 'register'},
        );
        _sync.emit(
          AppSyncTopic.auth,
          payload: const <String, dynamic>{'action': 'register'},
        );
        _sync.emit(
          AppSyncTopic.dashboard,
          payload: const <String, dynamic>{'source': 'auth'},
        );
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
      await ApiClient.instance.post('logout', body: const {}, auth: true);
    } catch (_) {
      // WHY: Network/API failures shouldn't block local logout.
    } finally {
      // Clear device push token so notifications stop for this account.
      await FcmService.instance.unregisterTokenForCurrentUser();
      await FcmService.instance.deleteToken();
      await SessionManager.instance.finalizeLogout(reason: 'manual');
    }
  }

  Future<void> handleSessionExpired({String reason = 'sessionExpired'}) {
    return SessionManager.instance.ensureForcedLogout(reason: reason);
  }

  Future<AuthResult> deleteAccount() async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        return const AuthResult(success: false, message: 'Not signed in.');
      }

      try {
        await FcmService.instance.unregisterTokenForCurrentUser();
      } catch (_) {
        // Best effort only; backend account deletion clears device tokens too.
      }

      final res = await ApiClient.instance.delete(
        'me',
        body: const {},
        auth: true,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = _tryDecodeJsonMap(res.body);
        await SessionManager.instance.finalizeLogout(reason: 'accountDeleted');
        return AuthResult(
          success: true,
          message: _extractMessage(data) ?? 'Your account has been deleted.',
        );
      }

      return _mapError(res);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Unable to delete your account. Please try again.',
      );
    }
  }

  Future<AuthResult> forgotPassword(String identifier) async {
    try {
      final res = await _postJson('password/forgot', {
        'identifier': identifier,
      });

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        final msg =
            _extractMessage(data) ??
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
        final msg =
            _extractMessage(data) ??
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
  Future<AuthResult> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        return const AuthResult(success: false, message: 'Not signed in.');
      }

      final trimmedFirst = firstName?.trim();
      final trimmedLast = lastName?.trim();
      final trimmedEmail = email?.trim().toLowerCase();

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
      final fullName = [
        trimmedFirst,
        trimmedLast,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();
      if (fullName.isNotEmpty) {
        body['name'] = fullName; // Laravel Jetstream style
        body['full_name'] = fullName;
      }
      if (body.isEmpty) {
        return const AuthResult(success: false, message: 'Nothing to update.');
      }

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
            _announceProfileUpdate();
            return const AuthResult(success: true);
          }
          if (resPatch.statusCode != 404 && resPatch.statusCode != 405) {
            return _mapError(resPatch);
          }
        } catch (_) {}
        try {
          final resPut = await _putJson(path, body, token: token);
          if (resPut.statusCode >= 200 && resPut.statusCode < 300) {
            _announceProfileUpdate();
            return const AuthResult(success: true);
          }
          if (resPut.statusCode != 404 && resPut.statusCode != 405) {
            return _mapError(resPut);
          }
        } catch (_) {}
        try {
          final resPost = await _postJson(path, body, token: token);
          if (resPost.statusCode >= 200 && resPost.statusCode < 300) {
            _announceProfileUpdate();
            return const AuthResult(success: true);
          }
          if (resPost.statusCode != 404 && resPost.statusCode != 405) {
            return _mapError(resPost);
          }
        } catch (_) {}
      }
      return const AuthResult(
        success: false,
        message: 'Failed to update profile.',
      );
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Unable to reach the server. Please try again.',
      );
    }
  }

  Future<bool> updateProfilePhoto(String path) async {
    try {
      final trimmed = path.trim();
      if (trimmed.isEmpty) return false;
      final token = await _getToken();
      if (token == null || token.isEmpty) return false;

      final endpoint = _uri('me');
      if (kDebugMode) {
        avatarUploadDebug.value = AvatarUploadDebugSnapshot(
          filePath: trimmed,
          requestUrl: endpoint.toString(),
          updatedAt: DateTime.now(),
        );
      }
      final request = http.MultipartRequest('POST', _uri('me'))
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['_method'] = 'PATCH';

      final filePart = await http.MultipartFile.fromPath(
        'profile_photo',
        trimmed,
      );
      _setAvatarUploadDebug(
        (current) => current.copyWith(
          fileSizeBytes: filePart.length,
          updatedAt: DateTime.now(),
          clearError: true,
        ),
      );
      _logProfilePhoto(
        'before upload path="$trimmed" bytes=${filePart.length} url=$endpoint',
      );
      request.files.add(filePart);

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      _logProfilePhoto('upload response headers=${response.headers}');
      _logProfilePhoto(
        'upload response status=${response.statusCode} body=${_logSnippet(response.body, max: 300)}',
      );
      _setAvatarUploadDebug(
        (current) => current.copyWith(
          uploadStatusCode: response.statusCode,
          uploadResponseHeadersSnippet: _headersSnippet(
            response.headers,
            max: 300,
          ),
          uploadResponseSnippet: _logSnippet(response.body, max: 200),
          updatedAt: DateTime.now(),
          clearError: true,
        ),
      );

      final responseBody = _tryDecodeJsonMap(response.body);
      _logProfilePhotoResponseFields('upload response', responseBody);

      final ok = response.statusCode >= 200 && response.statusCode < 300;
      var hasAvatarPayload = _responseHasAvatarPayload(responseBody);
      Map<String, dynamic>? meBody;
      if (ok) {
        final meRes = await http.get(
          _uri('me'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        meBody = _tryDecodeJsonMap(meRes.body);
        _logProfilePhoto('GET /me after upload headers=${meRes.headers}');
        _logProfilePhoto(
          'GET /me after upload status=${meRes.statusCode} body=${_logSnippet(meRes.body, max: 300)}',
        );
        _logProfilePhotoResponseFields('GET /me after upload', meBody);
        _logProfilePhotoResolvedAvatar('GET /me after upload', meBody);
        final meOk = meRes.statusCode >= 200 && meRes.statusCode < 300;
        hasAvatarPayload =
            hasAvatarPayload || (meOk && _responseHasAvatarPayload(meBody));
        _setAvatarUploadDebug(
          (current) => current.copyWith(
            meStatusCode: meRes.statusCode,
            meResponseSnippet: _logSnippet(meRes.body, max: 200),
            meProfilePhotoPath: _payloadField(meBody, [
              'profile_photo_path',
              'profilePhotoPath',
            ]),
            meProfilePhotoUrl: _payloadField(meBody, [
              'profile_photo_url',
              'profilePhotoUrl',
            ]),
            meAvatarUrl: _payloadField(meBody, ['avatar_url', 'avatarUrl']),
            meResolvedAvatarUrl: _resolvedAvatarFromPayload(meBody),
            meAvatarVersionToken: _avatarVersionTokenFromPayload(meBody),
            updatedAt: DateTime.now(),
            clearError: true,
          ),
        );
      }
      if (ok && !hasAvatarPayload) {
        _logProfilePhoto(
          'upload succeeded but avatar fields were missing from upload response and fallback /me',
        );
        _setAvatarUploadDebug(
          (current) => current.copyWith(
            error: 'Missing avatar fields in upload response and GET /me',
            updatedAt: DateTime.now(),
          ),
        );
        return false;
      }
      if (ok) {
        _announceProfileUpdate();
      }
      return ok;
    } catch (e, st) {
      _logProfilePhoto('upload error: $e');
      _setAvatarUploadDebug(
        (current) =>
            current.copyWith(error: e.toString(), updatedAt: DateTime.now()),
      );
      if (kDebugMode) {
        debugPrint(st.toString());
      }
      return false;
    }
  }

  void _setAvatarUploadDebug(
    AvatarUploadDebugSnapshot Function(AvatarUploadDebugSnapshot current)
    updater,
  ) {
    if (!kDebugMode) return;
    avatarUploadDebug.value = updater(avatarUploadDebug.value);
  }

  void _announceProfileUpdate() {
    _sync.emit(
      AppSyncTopic.profile,
      payload: const <String, dynamic>{'action': 'profileUpdated'},
    );
    _sync.emit(
      AppSyncTopic.dashboard,
      payload: const <String, dynamic>{'source': 'profile'},
    );
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

  void _logProfilePhoto(String message) {
    if (!kDebugMode) return;
    debugPrint('[AuthService.updateProfilePhoto] $message');
  }

  String _logSnippet(String raw, {int max = 500}) {
    final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= max) return compact;
    return '${compact.substring(0, max)}...';
  }

  String _headersSnippet(Map<String, String> headers, {int max = 500}) {
    final text = headers.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    return _logSnippet(text, max: max);
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }

  bool _responseHasAvatarPayload(Map<String, dynamic>? body) {
    if (body == null) return false;
    final user = _extractUserFromPayload(body);
    if (user == null) return false;

    const keys = [
      'avatar_url',
      'avatarUrl',
      'profile_photo_url',
      'profile_photo_path',
      'profilePhotoUrl',
      'profilePhotoPath',
    ];
    for (final key in keys) {
      final value = user[key];
      if (value == null) continue;
      final s = value.toString().trim();
      if (s.isNotEmpty && s.toLowerCase() != 'null') return true;
    }
    return false;
  }

  Map<String, dynamic>? _extractUserFromPayload(Map<String, dynamic> body) {
    final user = body['user'];
    if (user is Map<String, dynamic>) return user;
    if (user is Map) {
      return user.map((k, v) => MapEntry(k.toString(), v));
    }
    return body;
  }

  void _logProfilePhotoResponseFields(
    String label,
    Map<String, dynamic>? body,
  ) {
    if (!kDebugMode) return;
    if (body == null) {
      debugPrint('[AuthService.updateProfilePhoto] $label fields: <non-json>');
      return;
    }
    final user = _extractUserFromPayload(body) ?? <String, dynamic>{};
    final avatarUrl = user['avatar_url'] ?? user['avatarUrl'];
    final profilePhotoUrl =
        user['profile_photo_url'] ?? user['profilePhotoUrl'];
    final profilePhotoPath =
        user['profile_photo_path'] ?? user['profilePhotoPath'];
    final avatarUpdatedAt =
        body['avatar_updated_at'] ??
        user['avatar_updated_at'] ??
        user['avatarUpdatedAt'] ??
        user['updated_at'] ??
        user['updatedAt'];

    debugPrint(
      '[AuthService.updateProfilePhoto] $label fields: '
      'avatar_url=$avatarUrl, profile_photo_url=$profilePhotoUrl, '
      'profile_photo_path=$profilePhotoPath, avatar_updated_at=$avatarUpdatedAt',
    );
  }

  void _logProfilePhotoResolvedAvatar(
    String label,
    Map<String, dynamic>? body,
  ) {
    if (!kDebugMode) return;
    final resolved = _resolvedAvatarFromPayload(body);
    final version = _avatarVersionTokenFromPayload(body);
    debugPrint(
      '[AuthService.updateProfilePhoto] $label resolved_avatar=$resolved version=$version',
    );
  }

  String? _payloadField(Map<String, dynamic>? body, List<String> keys) {
    if (body == null) return null;
    final user = _extractUserFromPayload(body) ?? const <String, dynamic>{};
    for (final key in keys) {
      final value = user[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') continue;
      return text;
    }
    return null;
  }

  String? _avatarVersionTokenFromPayload(Map<String, dynamic>? body) {
    if (body == null) return null;
    final user = _extractUserFromPayload(body) ?? const <String, dynamic>{};
    const keys = [
      'avatar_updated_at',
      'avatarUpdatedAt',
      'profile_photo_updated_at',
      'profilePhotoUpdatedAt',
      'updated_at',
      'updatedAt',
    ];
    for (final key in keys) {
      final value = body[key] ?? user[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') continue;
      return text;
    }
    return null;
  }

  String? _resolvedAvatarFromPayload(Map<String, dynamic>? body) {
    if (body == null) return null;
    final rawAvatar = _payloadField(body, const [
      'avatar_url',
      'avatarUrl',
      'profile_photo_url',
      'profilePhotoUrl',
      'profile_photo_path',
      'profilePhotoPath',
    ]);
    if (rawAvatar == null) return null;
    final resolved = Api.resolveImageUrl(rawAvatar);
    if (resolved.isEmpty) return null;
    final version = _avatarVersionTokenFromPayload(body);
    if (version == null || version.isEmpty) return resolved;
    return Api.withCacheBust(resolved, version);
  }

  AuthResult _mapError(http.Response res) {
    String? message;
    final errors = <String>[];
    final fieldErrors = <String, String>{};
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        final msg = body['message'] ?? body['error'] ?? body['status'];
        if (msg is String && msg.trim().isNotEmpty) {
          message = msg.trim();
        }
        final err = body['errors'];
        if (err is Map) {
          err.forEach((key, value) {
            String? firstFieldError;
            if (value is List) {
              final values = value
                  .map((e) => e.toString())
                  .where((e) => e.trim().isNotEmpty)
                  .toList();
              if (values.isNotEmpty) {
                errors.addAll(values);
                firstFieldError = values.first;
              }
            } else if (value != null) {
              final text = value.toString();
              if (text.trim().isNotEmpty) {
                errors.add(text);
                firstFieldError = text;
              }
            }
            final keyText = key.toString().trim();
            if (keyText.isNotEmpty && firstFieldError != null) {
              fieldErrors[keyText] = firstFieldError;
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

    return AuthResult(
      success: false,
      message: message,
      errors: errors,
      fieldErrors: fieldErrors,
    );
  }
}
