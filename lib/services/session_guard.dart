import 'package:fixitzed_app/services/session_manager.dart';
import 'package:http/http.dart' as http;

class SessionGuard {
  SessionGuard._();

  static Future<void> evaluate(http.BaseResponse response) async {
    if (_shouldInspect(response.statusCode)) {
      await SessionManager.instance.confirmActiveSessionOrLogout(
        response.statusCode,
      );
    }
  }

  static bool _shouldInspect(int statusCode) {
    return statusCode == 401 || statusCode == 419 || statusCode == 423;
  }
}
