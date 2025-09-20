import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class Api {
  /// Resolve a sensible default API base per platform.
  /// - Android emulator: 10.0.2.2
  /// - iOS simulator/Web/desktop: localhost
  /// You can override at build time: --dart-define=API_BASE_URL=https://your.host/api
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://localhost:8000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000/api';
    } catch (_) {}
    return 'http://localhost:8000/api';
  }

  /// Converts a possibly relative media path into an absolute URL that can be
  /// loaded by [NetworkImage]. Falls back to the provided value if already
  /// absolute. Returns an empty string when nothing usable is available.
  static String resolveImageUrl(String? raw) {
    if (raw == null) return '';
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    final base = baseUrl;
    final origin = base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
    final normalized = value.startsWith('/') ? value.substring(1) : value;
    if (normalized.startsWith('storage/')) {
      return '$origin/$normalized';
    }
    return '$origin/storage/$normalized';
  }
}
