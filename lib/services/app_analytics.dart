import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Extremely lightweight analytics/logger wrapper so product events have
/// a single home. Replace the internals with a vendor SDK when available.
class AppAnalytics {
  AppAnalytics._();

  static final AppAnalytics instance = AppAnalytics._();

  void logEvent(String name, {Map<String, dynamic>? parameters}) {
    if (name.isEmpty) return;
    final payload = parameters == null ? '' : jsonEncode(parameters);
    debugPrint('[analytics] $name $payload');
  }

  void logError(
    String name, {
    String? message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? parameters,
  }) {
    final merged = {
      if (parameters != null) ...parameters,
      if (message != null) 'message': message,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };
    logEvent('error:$name', parameters: merged);
  }
}
