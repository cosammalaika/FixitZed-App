import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const _kDark = 'settings_dark_mode';

  static final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_kDark) ?? false;
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setDark(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDark, dark);
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  static ThemeData light() {
    const brand = Color(0xFFF1592A);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.light),
      primaryColor: brand,
      useMaterial3: false,
    );
  }

  static ThemeData dark() {
    const brand = Color(0xFFF1592A);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: brand, brightness: Brightness.dark),
      primaryColor: brand,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      useMaterial3: false,
    );
  }
}

