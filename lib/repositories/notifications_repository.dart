import 'dart:async';

import 'package:fixitzed_app/services/notification_service.dart';
import 'package:fixitzed_app/services/token_storage.dart';

class NotificationsLoadResult {
  const NotificationsLoadResult({
    required this.items,
    required this.success,
    required this.usedCacheFallback,
  });

  final List<Map<String, dynamic>> items;
  final bool success;
  final bool usedCacheFallback;
}

/// Cache for notifications page 1.
class NotificationsRepository {
  NotificationsRepository(this._api);

  final NotificationService _api;

  List<Map<String, dynamic>>? _cache;
  DateTime? _lastFetch;
  static const _ttl = Duration(minutes: 5);
  static const _minRefreshGap = Duration(seconds: 20);
  Future<NotificationsLoadResult>? _inFlight;

  List<Map<String, dynamic>>? get cached =>
      _cache == null ? null : List<Map<String, dynamic>>.from(_cache!);

  bool _isStale() {
    final fetchedAt = _lastFetch;
    if (fetchedAt == null) return true;
    return DateTime.now().difference(fetchedAt) > _ttl;
  }

  Future<List<Map<String, dynamic>>> getNotifications({
    bool forceRefresh = false,
  }) async {
    final result = await loadNotifications(forceRefresh: forceRefresh);
    return result.items;
  }

  Future<NotificationsLoadResult> loadNotifications({
    bool forceRefresh = false,
  }) async {
    final token = await TokenStorage.instance.getToken();
    if (token == null || token.isEmpty) {
      clearCache();
      return const NotificationsLoadResult(
        items: <Map<String, dynamic>>[],
        success: true,
        usedCacheFallback: false,
      );
    }

    if (!forceRefresh && _cache != null && !_isStale()) {
      return NotificationsLoadResult(
        items: List<Map<String, dynamic>>.from(_cache!),
        success: true,
        usedCacheFallback: false,
      );
    }

    final cached = _cache;
    if (!forceRefresh &&
        cached != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _minRefreshGap) {
      return NotificationsLoadResult(
        items: List<Map<String, dynamic>>.from(cached),
        success: true,
        usedCacheFallback: false,
      );
    }

    final existing = _inFlight;
    if (existing != null) return existing;

    final future = _loadFromNetwork();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  Future<NotificationsLoadResult> _loadFromNetwork() async {
    final result = await _api.fetchResult(page: 1);
    if (result.success) {
      _cache = List<Map<String, dynamic>>.from(result.items);
      _lastFetch = DateTime.now();
      return NotificationsLoadResult(
        items: List<Map<String, dynamic>>.from(_cache!),
        success: true,
        usedCacheFallback: false,
      );
    }

    final cached = _cache;
    if (cached != null) {
      return NotificationsLoadResult(
        items: List<Map<String, dynamic>>.from(cached),
        success: false,
        usedCacheFallback: true,
      );
    }

    return const NotificationsLoadResult(
      items: <Map<String, dynamic>>[],
      success: false,
      usedCacheFallback: false,
    );
  }

  void clearCache() {
    _cache = null;
    _lastFetch = null;
  }
}
