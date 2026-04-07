import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.brand,
    required this.brandAccent,
    required this.page,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSubtle,
    required this.surfaceTint,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.danger,
    required this.dangerContainer,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.shadow,
  });

  final Color brand;
  final Color brandAccent;
  final Color page;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSubtle;
  final Color surfaceTint;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;
  final Color danger;
  final Color dangerContainer;
  final Color skeletonBase;
  final Color skeletonHighlight;
  final Color shadow;

  LinearGradient get brandGradient => LinearGradient(
    colors: [brand, brandAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get sheetGradient => LinearGradient(
    colors: [surfaceRaised, surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  AppThemeColors copyWith({
    Color? brand,
    Color? brandAccent,
    Color? page,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSubtle,
    Color? surfaceTint,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
    Color? danger,
    Color? dangerContainer,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? shadow,
  }) {
    return AppThemeColors(
      brand: brand ?? this.brand,
      brandAccent: brandAccent ?? this.brandAccent,
      page: page ?? this.page,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceTint: surfaceTint ?? this.surfaceTint,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppThemeColors(
      brand: l(brand, other.brand),
      brandAccent: l(brandAccent, other.brandAccent),
      page: l(page, other.page),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceSubtle: l(surfaceSubtle, other.surfaceSubtle),
      surfaceTint: l(surfaceTint, other.surfaceTint),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      success: l(success, other.success),
      successContainer: l(successContainer, other.successContainer),
      warning: l(warning, other.warning),
      warningContainer: l(warningContainer, other.warningContainer),
      info: l(info, other.info),
      infoContainer: l(infoContainer, other.infoContainer),
      danger: l(danger, other.danger),
      dangerContainer: l(dangerContainer, other.dangerContainer),
      skeletonBase: l(skeletonBase, other.skeletonBase),
      skeletonHighlight: l(skeletonHighlight, other.skeletonHighlight),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension AppThemeX on ThemeData {
  AppThemeColors get fx =>
      extension<AppThemeColors>() ??
      (brightness == Brightness.dark
          ? AppTheme._darkTokens
          : AppTheme._lightTokens);
}

class AppTheme {
  static const _kDark = 'settings_dark_mode';
  static const brand = Color(0xFFF1592A);
  static const brandAccent = Color(0xFFFF8A5C);

  static const _lightTokens = AppThemeColors(
    brand: brand,
    brandAccent: brandAccent,
    page: Color(0xFFF7EFEA),
    surface: Color(0xFFFBF6F1),
    surfaceRaised: Color(0xFFFFF9F4),
    surfaceSubtle: Color(0xFFE9DDD5),
    surfaceTint: Color(0xFFFFDDCC),
    border: Color(0xFFD2C1B6),
    textPrimary: Color(0xFF332319),
    textSecondary: Color(0xFF675B54),
    textMuted: Color(0xFF8A7B73),
    success: Color(0xFF2E7D32),
    successContainer: Color(0xFFDDF0E3),
    warning: Color(0xFFE67E22),
    warningContainer: Color(0xFFFFDEB8),
    info: Color(0xFF1976D2),
    infoContainer: Color(0xFFDCEBFF),
    danger: Color(0xFFD32F2F),
    dangerContainer: Color(0xFFFFDADB),
    skeletonBase: Color(0xFFD8CCC4),
    skeletonHighlight: Color(0xFFECE4DE),
    shadow: Color(0x16000000),
  );

  static const _darkTokens = AppThemeColors(
    brand: brand,
    brandAccent: brandAccent,
    page: Color(0xFF101112),
    surface: Color(0xFF181C20),
    surfaceRaised: Color(0xFF20252D),
    surfaceSubtle: Color(0xFF242A33),
    surfaceTint: Color(0xFF2B211D),
    border: Color(0xFF343B46),
    textPrimary: Color(0xFFF2EAE4),
    textSecondary: Color(0xFFD3C8C0),
    textMuted: Color(0xFF9B918A),
    success: Color(0xFF6AD37C),
    successContainer: Color(0xFF183821),
    warning: Color(0xFFFFB15C),
    warningContainer: Color(0xFF3A2917),
    info: Color(0xFF83B7FF),
    infoContainer: Color(0xFF172A42),
    danger: Color(0xFFFF7A70),
    dangerContainer: Color(0xFF3E1D1C),
    skeletonBase: Color(0xFF2D2D30),
    skeletonHighlight: Color(0xFF3C3C40),
    shadow: Color(0x66000000),
  );

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

  static SystemUiOverlayStyle systemOverlayStyle(
    BuildContext context, {
    Color? statusBarColor,
    Color? navigationBarColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        .copyWith(
          statusBarColor: statusBarColor ?? Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor:
              navigationBarColor ?? theme.scaffoldBackgroundColor,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        );
  }

  static ThemeData light() {
    const tokens = _lightTokens;
    const accent = brandAccent;
    final background = tokens.page;
    final surface = tokens.surface;
    final fill = tokens.surfaceRaised;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.light,
        ).copyWith(
          primary: brand,
          secondary: accent,
          surface: surface,
          surfaceContainerHighest: tokens.surfaceSubtle,
          outline: tokens.border,
          outlineVariant: tokens.border,
          error: tokens.danger,
          onSurface: tokens.textPrimary,
          onSurfaceVariant: tokens.textSecondary,
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
      extensions: const <ThemeExtension<dynamic>>[tokens],
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: brand,
        selectionColor: Color.fromRGBO(0, 0, 0, 0.08),
        selectionHandleColor: brand,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          fontSize: 20,
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: surface,
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return brand;
          return const Color(0xFFE0E0E0);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.35);
          }
          return const Color(0xFFBDBDBD);
        }),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: fill,
        isDense: false,
        labelStyle: base.textTheme.bodyMedium?.copyWith(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: base.textTheme.bodyMedium?.copyWith(
          color: tokens.textMuted,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tokens.border, width: 1.1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: tokens.border, width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brand, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        errorStyle: base.textTheme.bodySmall?.copyWith(
          color: scheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: scheme.outline.withValues(alpha: 0.08),
      cardTheme: CardThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: tokens.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: tokens.textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: base.textTheme.bodyMedium?.copyWith(
          color: tokens.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF2B211D),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: tokens.surfaceSubtle,
        selectedColor: tokens.surfaceTint,
        disabledColor: tokens.surfaceSubtle.withValues(alpha: 0.55),
        labelStyle: base.textTheme.bodySmall?.copyWith(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: base.textTheme.bodySmall?.copyWith(
          color: tokens.brand,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: tokens.border),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: surface,
        selectedItemColor: brand,
        unselectedItemColor: scheme.onSurface.withValues(alpha: 0.45),
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }

  static ThemeData dark() {
    const tokens = _darkTokens;
    const accent = brandAccent;
    final background = tokens.page;
    final surface = tokens.surface;
    const fill = Color.fromRGBO(33, 36, 42, 0.96);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: brand,
          brightness: Brightness.dark,
        ).copyWith(
          primary: brand,
          secondary: accent,
          surface: surface,
          surfaceContainerHighest: tokens.surfaceSubtle,
          outline: tokens.border,
          outlineVariant: tokens.border,
          error: tokens.danger,
          onSurface: tokens.textPrimary,
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
      extensions: const <ThemeExtension<dynamic>>[tokens],
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: brand,
        selectionColor: Color.fromRGBO(255, 255, 255, 0.16),
        selectionHandleColor: brand,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          fontSize: 20,
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: surface,
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return brand;
          return const Color(0xFF525866);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.45);
          }
          return const Color(0xFF2F333C);
        }),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: fill,
        isDense: false,
        labelStyle: base.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFFF5F1EB),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: base.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFFE0D7D0).withValues(alpha: 0.8),
          fontWeight: FontWeight.w400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1.1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1.1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brand, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        errorStyle: base.textTheme.bodySmall?.copyWith(
          color: scheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: scheme.outline.withValues(alpha: 0.15),
      cardTheme: CardThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: tokens.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: tokens.textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: base.textTheme.bodyMedium?.copyWith(
          color: tokens.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surfaceRaised,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: tokens.surfaceSubtle,
        selectedColor: tokens.surfaceTint,
        disabledColor: tokens.surfaceSubtle.withValues(alpha: 0.55),
        labelStyle: base.textTheme.bodySmall?.copyWith(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: base.textTheme.bodySmall?.copyWith(
          color: tokens.brand,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: tokens.border.withValues(alpha: 0.9)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: surface,
        selectedItemColor: brand,
        unselectedItemColor: scheme.onSurface.withValues(alpha: 0.5),
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
}
