import 'package:flutter/widgets.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Convenience insets
  static const hMd = EdgeInsets.symmetric(horizontal: md);
  static const vMd = EdgeInsets.symmetric(vertical: md);
  static const hLg = EdgeInsets.symmetric(horizontal: lg);
  static const vLg = EdgeInsets.symmetric(vertical: lg);
  static const allMd = EdgeInsets.all(md);
  static const allLg = EdgeInsets.all(lg);
}
