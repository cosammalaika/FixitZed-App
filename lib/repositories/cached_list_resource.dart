import 'dart:async';

enum CachedListFailureKind { offline, timeout, backend, parse, unknown }

class CachedListFailure {
  const CachedListFailure({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  final CachedListFailureKind kind;
  final String message;
  final int? statusCode;

  bool get isOfflineLike =>
      kind == CachedListFailureKind.offline ||
      kind == CachedListFailureKind.timeout;

  String get userMessage {
    return switch (kind) {
      CachedListFailureKind.offline =>
        'You appear to be offline. We will retry automatically.',
      CachedListFailureKind.timeout =>
        'The request timed out. We will retry automatically.',
      CachedListFailureKind.backend =>
        'The server is having trouble right now.',
      CachedListFailureKind.parse => 'We received an unexpected response.',
      CachedListFailureKind.unknown =>
        'Something went wrong while loading this data.',
    };
  }

  static CachedListFailure fromError(Object error) {
    final raw = error.toString().trim();
    final lowered = raw.toLowerCase();

    if (error is TimeoutException || lowered.contains('timed out')) {
      return CachedListFailure(
        kind: CachedListFailureKind.timeout,
        message: raw,
      );
    }

    if (error is FormatException ||
        lowered.contains('formatexception') ||
        lowered.contains('unexpected character') ||
        lowered.contains('type ') && lowered.contains(' is not a subtype')) {
      return CachedListFailure(
        kind: CachedListFailureKind.parse,
        message: raw,
      );
    }

    if (_looksOffline(lowered)) {
      return CachedListFailure(
        kind: CachedListFailureKind.offline,
        message: raw,
      );
    }

    final statusCode = _extractStatusCode(raw);
    if (statusCode != null) {
      return CachedListFailure(
        kind: CachedListFailureKind.backend,
        message: raw,
        statusCode: statusCode,
      );
    }

    return CachedListFailure(
      kind: CachedListFailureKind.unknown,
      message: raw,
    );
  }

  static bool _looksOffline(String lowered) {
    return lowered.contains('socketexception') ||
        lowered.contains('failed host lookup') ||
        lowered.contains('network is unreachable') ||
        lowered.contains('connection refused') ||
        lowered.contains('connection closed') ||
        lowered.contains('software caused connection abort') ||
        lowered.contains('clientexception with socketexception') ||
        lowered.contains('no address associated with hostname') ||
        lowered.contains('network request failed') ||
        lowered.contains('connection error') ||
        lowered.contains('os error');
  }

  static int? _extractStatusCode(String raw) {
    final patterns = <RegExp>[
      RegExp(r'http[_\s:]+(\d{3})', caseSensitive: false),
      RegExp(r'status[_\s:]+(\d{3})', caseSensitive: false),
      RegExp(r'\b(\d{3})\b'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(raw);
      final value = match?.group(1);
      if (value == null) continue;
      final parsed = int.tryParse(value);
      if (parsed != null && parsed >= 400 && parsed <= 599) {
        return parsed;
      }
    }
    return null;
  }
}

class CachedListSnapshot {
  const CachedListSnapshot({
    this.items = const <dynamic>[],
    this.fetchedAt,
  });

  final List<dynamic> items;
  final DateTime? fetchedAt;

  bool get hasData => items.isNotEmpty;

  bool isStale(Duration ttl) {
    final fetchedAt = this.fetchedAt;
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > ttl;
  }
}

class CachedListFetchResult {
  const CachedListFetchResult({
    required this.items,
    this.fetchedAt,
    required this.fromCache,
    required this.networkFetched,
    required this.backendReturnedEmpty,
    this.failure,
  });

  final List<dynamic> items;
  final DateTime? fetchedAt;
  final bool fromCache;
  final bool networkFetched;
  final bool backendReturnedEmpty;
  final CachedListFailure? failure;

  bool get hasData => items.isNotEmpty;

  factory CachedListFetchResult.fromSnapshot(CachedListSnapshot snapshot) {
    return CachedListFetchResult(
      items: List<dynamic>.from(snapshot.items),
      fetchedAt: snapshot.fetchedAt,
      fromCache: snapshot.items.isNotEmpty,
      networkFetched: false,
      backendReturnedEmpty: false,
    );
  }
}
