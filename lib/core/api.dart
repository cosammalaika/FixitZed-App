import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class Api {
  /// Resolve the API base URL.
  /// Override at build time with: --dart-define=API_BASE_URL=https://your.host/api

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'https://admin.fixitzed.com/api';
  }
  // static String get baseUrl {
  //   const fromEnv = String.fromEnvironment('API_BASE_URL');
  //   if (fromEnv.isNotEmpty) return fromEnv;
  //   if (kIsWeb) return 'http://localhost:8000/api';
  //   try {
  //     if (Platform.isAndroid) return 'http://10.0.2.2:8000/api';
  //   } catch (_) {}
  //   return 'http://localhost:8000/api';
  // }

  /// Converts a possibly relative media path into an absolute URL that can be
  /// loaded by [NetworkImage]. Falls back to the provided value if already
  /// absolute. Returns an empty string when nothing usable is available.
  static String resolveImageUrl(String? raw) {
    if (raw == null) return '';
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return _normalizeHost(value);
    }

    final base = baseUrl;
    final origin = base.endsWith('/api')
        ? base.substring(0, base.length - 4)
        : base;
    final normalized = value.startsWith('/') ? value.substring(1) : value;
    if (normalized.startsWith('storage/')) {
      return '$origin/$normalized';
    }
    return '$origin/storage/$normalized';
  }

  static String _normalizeHost(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      if ((host == 'localhost' || host == '127.0.0.1') && !kIsWeb) {
        try {
          if (defaultTargetPlatform == TargetPlatform.android) {
            return uri.replace(host: '10.0.2.2').toString();
          }
        } catch (_) {}
      }
      return url;
    } catch (_) {
      return url;
    }
  }
}
