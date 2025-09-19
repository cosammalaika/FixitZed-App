import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsKeys {
  static const pushNotifications = 'settings_push_notifications';
  static const emailNotifications = 'settings_email_notifications';
  static const darkMode = 'settings_dark_mode';
  static const biometricLogin = 'settings_biometric_login';
  static const language = 'settings_language';
}

class AppSettings {
  static Future<bool> getPushEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(AppSettingsKeys.pushNotifications) ?? true;
  }

  static Future<bool> getBiometricEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(AppSettingsKeys.biometricLogin) ?? false;
  }

  static Future<void> setPushEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(AppSettingsKeys.pushNotifications, v);
  }

  static Future<void> setBiometricEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(AppSettingsKeys.biometricLogin, v);
  }
}

