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

  /// Adds or replaces a single cache-busting `v` query param.
  /// This avoids duplicate `?v=...&v=...` URLs when multiple layers rebuild.
  static String withCacheBust(String url, String token) {
    final trimmedUrl = url.trim();
    final trimmedToken = token.trim();
    if (trimmedUrl.isEmpty || trimmedToken.isEmpty) return trimmedUrl;

    try {
      final uri = Uri.parse(trimmedUrl);
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['v'] = trimmedToken;
      return uri.replace(queryParameters: qp).toString();
    } catch (_) {
      return trimmedUrl;
    }
  }

  static String _normalizeHost(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      if ((host == 'localhost' || host == '127.0.0.1') && !kIsWeb) {
        final apiOrigin = Uri.tryParse(baseUrl);
        final apiHost = apiOrigin?.host ?? '';
        final apiHostIsLocal = apiHost == 'localhost' || apiHost == '127.0.0.1';
        if (apiOrigin != null && apiHost.isNotEmpty && !apiHostIsLocal) {
          final targetPort = apiOrigin.hasPort ? apiOrigin.port : null;
          return uri
              .replace(
                scheme: apiOrigin.scheme.isEmpty ? uri.scheme : apiOrigin.scheme,
                host: apiHost,
                port: targetPort,
              )
              .toString();
        }
        try {
          if (defaultTargetPlatform == TargetPlatform.android) {
            return uri.replace(host: '10.0.2.2').toString();
          }
        } catch (_) {}
      }

      final apiOrigin = Uri.tryParse(baseUrl);
      if (apiOrigin != null &&
          apiOrigin.scheme == 'https' &&
          uri.scheme == 'http' &&
          uri.host == apiOrigin.host) {
        final targetPort = apiOrigin.hasPort ? apiOrigin.port : null;
        return uri.replace(scheme: 'https', port: targetPort).toString();
      }
      return url;
    } catch (_) {
      return url;
    }
  }
}
