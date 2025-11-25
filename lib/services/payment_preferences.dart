import 'package:shared_preferences/shared_preferences.dart';

class PaymentPreferences {
  static const _methodKey = 'settings_default_payment_method';

  static Future<void> setDefaultMethod(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_methodKey, code);
  }

  static Future<String?> defaultMethod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_methodKey);
  }
}
