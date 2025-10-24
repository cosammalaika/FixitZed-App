import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const _kDark = 'settings_dark_mode';

  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

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
    const accent = Color(0xFFFF8A5C);
    const background = Color(0xFFFEFAF7);
    const surface = Colors.white;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.light,
        ).copyWith(
          primary: brand,
          secondary: accent,
          background: background,
          surface: surface,
          onSurface: const Color(0xFF332319),
          onBackground: const Color(0xFF332319),
        );

    final base = ThemeData(
      brightness: Brightness.light,
      colorScheme: scheme,
      primaryColor: brand,
      scaffoldBackgroundColor: background,
      cardColor: surface,
      useMaterial3: false,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: scheme.onBackground,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onBackground,
          fontSize: 20,
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: surface,
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return brand;
          return const Color(0xFFE0E0E0);
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return accent.withOpacity(0.35);
          }
          return const Color(0xFFBDBDBD);
        }),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withOpacity(0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withOpacity(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: brand, width: 1.5),
        ),
      ),
      dividerColor: scheme.outline.withOpacity(0.08),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: surface,
        selectedItemColor: brand,
        unselectedItemColor: scheme.onSurface.withOpacity(0.45),
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }

  static ThemeData dark() {
    const brand = Color(0xFFF1592A);
    const accent = Color(0xFFFF8A5C);
    const background = Color(0xFF101112);
    const surface = Color(0xFF181C20);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.dark,
        ).copyWith(
          primary: brand,
          secondary: accent,
          background: background,
          surface: surface,
          onSurface: const Color(0xFFF2EAE4),
          onBackground: const Color(0xFFF2EAE4),
        );

    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      primaryColor: brand,
      scaffoldBackgroundColor: background,
      cardColor: surface,
      useMaterial3: false,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: scheme.onBackground,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onBackground,
          fontSize: 20,
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: surface,
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return brand;
          return const Color(0xFF525866);
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return accent.withOpacity(0.45);
          }
          return const Color(0xFF2F333C);
        }),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0xFF1F242C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withOpacity(0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: brand, width: 1.5),
        ),
      ),
      dividerColor: scheme.outline.withOpacity(0.15),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: surface,
        selectedItemColor: brand,
        unselectedItemColor: scheme.onSurface.withOpacity(0.5),
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
}
