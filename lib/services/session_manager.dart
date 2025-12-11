import 'package:fixitzed_app/state/app_sync.dart';
import 'package:fixitzed_app/services/fcm_service.dart';
import 'package:fixitzed_app/services/token_storage.dart';

class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  final AppSync _sync = AppSync.instance;

  Future<void> storeToken(String token) => TokenStorage.instance.saveToken(token);

  Future<String?> readToken() async {
    return TokenStorage.instance.getToken();
  }

  Future<void> removeToken() async {
    await TokenStorage.instance.clearToken();
  }

  Future<void> finalizeLogout({String reason = 'manual'}) async {
    await removeToken();
    await FcmService.instance.deleteToken();
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
