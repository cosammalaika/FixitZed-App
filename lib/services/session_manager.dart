import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:fixitzed_app/state/app_sync.dart';
import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/services/fcm_service.dart';
import 'package:fixitzed_app/services/favorites_service.dart';
import 'package:fixitzed_app/services/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SessionValidationResult {
  valid,
  missingToken,
  invalidToken,
  accountDisabled,
  indeterminate,
}

class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  final AppSync _sync = AppSync.instance;
  Future<SessionValidationResult>? _sessionValidationInFlight;

  Future<void> storeToken(String token) =>
      TokenStorage.instance.saveToken(token);

  Future<String?> readToken() async {
    return TokenStorage.instance.getToken();
  }

  Future<void> removeToken() async {
    await TokenStorage.instance.clearToken();
  }

  Future<void> finalizeLogout({String reason = 'manual'}) async {
    await removeToken();
    await FcmService.instance.deleteToken();
    await _clearLocalUserCaches(
      clearRememberedIdentifier: reason == 'accountDeleted',
    );
    _broadcastLogout(reason: reason);
  }

  Future<void> ensureForcedLogout({String reason = 'sessionExpired'}) async {
    final current = await readToken();
    if (current == null) return;
    await removeToken();
    await _clearLocalUserCaches();
    _broadcastLogout(reason: reason);
  }

  Future<SessionValidationResult> probeStoredSession() async {
    final existing = _sessionValidationInFlight;
    if (existing != null) return existing;

    final future = _probeStoredSession();
    _sessionValidationInFlight = future;
    return future.whenComplete(() {
      if (identical(_sessionValidationInFlight, future)) {
        _sessionValidationInFlight = null;
      }
    });
  }

  Future<void> confirmActiveSessionOrLogout(int statusCode) async {
    if (!_shouldInspect(statusCode)) return;

    final result = await probeStoredSession();
    if (result == SessionValidationResult.invalidToken) {
      await ensureForcedLogout(reason: 'sessionExpired');
      return;
    }
    if (result == SessionValidationResult.accountDisabled) {
      await ensureForcedLogout(reason: 'accountDisabled');
    }
  }

  Future<void> _clearLocalUserCaches({
    bool clearRememberedIdentifier = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove('profile_repository.me_cache'),
        prefs.remove('profile_repository.me_cache_fetched_at'),
        prefs.remove('request_status_cache'),
        prefs.remove('request_fixer_cache'),
        prefs.remove('local_notif_seen'),
        prefs.remove('settings_push_notifications'),
        prefs.remove('settings_email_notifications'),
        if (clearRememberedIdentifier) prefs.remove('remember_identifier'),
        if (clearRememberedIdentifier) prefs.remove('remember_email'),
        FavoritesService.clear(),
      ]);
    } catch (_) {
      // Cache cleanup should not block logout or account deletion.
    }
  }

  void _broadcastLogout({required String reason}) {
    final payload = <String, dynamic>{'action': 'logout', 'reason': reason};

    final sourcePayload = <String, dynamic>{
      'source': 'auth',
      'action': 'logout',
      'reason': reason,
    };

    _sync.emit(AppSyncTopic.profile, payload: payload);
    _sync.emit(AppSyncTopic.dashboard, payload: sourcePayload);
    _sync.emit(AppSyncTopic.notifications, payload: sourcePayload);
    _sync.emit(AppSyncTopic.bookings, payload: sourcePayload);
    _sync.emit(AppSyncTopic.wallet, payload: sourcePayload);
    _sync.emit(AppSyncTopic.auth, payload: payload);
  }

  Future<SessionValidationResult> _probeStoredSession() async {
    final token = await readToken();
    if (token == null || token.isEmpty) {
      return SessionValidationResult.missingToken;
    }

    try {
      final res = await http
          .get(
            Uri.parse('${Api.baseUrl}/me'),
            headers: <String, String>{
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) return SessionValidationResult.valid;
      if (res.statusCode == 423) {
        return SessionValidationResult.accountDisabled;
      }
      if (_shouldInspect(res.statusCode)) {
        return SessionValidationResult.invalidToken;
      }
    } on TimeoutException {
      return SessionValidationResult.indeterminate;
    } on http.ClientException {
      return SessionValidationResult.indeterminate;
    } catch (_) {
      return SessionValidationResult.indeterminate;
    }

    return SessionValidationResult.indeterminate;
  }

  bool _shouldInspect(int statusCode) {
    return statusCode == 401 || statusCode == 419 || statusCode == 423;
  }
}
