import 'package:fixitzed_app/state/app_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  SessionManager._();

  static const tokenKey = 'auth_token';
  static final SessionManager instance = SessionManager._();

  final AppSync _sync = AppSync.instance;

  Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(tokenKey);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }

  Future<void> finalizeLogout({String reason = 'manual'}) async {
    await removeToken();
    _broadcastLogout(reason: reason);
  }

  Future<void> ensureForcedLogout({String reason = 'sessionExpired'}) async {
    final current = await readToken();
    if (current == null) return;
    await removeToken();
    _broadcastLogout(reason: reason);
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
}
