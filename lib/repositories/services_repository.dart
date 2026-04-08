import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/repositories/cached_list_resource.dart';
import 'package:fixitzed_app/services/home_service.dart';
import 'package:fixitzed_app/utils/home_flow_log.dart';

/// Cache for service catalog lists.
class ServicesRepository {
  ServicesRepository(this._api);

  static const Duration ttl = Duration(minutes: 10);
  static const Duration _minRefreshGap = Duration(seconds: 30);
  static const _cacheStorageKey = 'services_repository.cache';
  static const _cacheFetchedAtKey = 'services_repository.cache_fetched_at';

  final HomeService _api;

  List<dynamic>? _cache;
  DateTime? _lastFetch;
  DateTime? _lastAttemptAt;
  CachedListFailure? _lastFailure;
  Future<void>? _hydrateFuture;
  Future<CachedListFetchResult>? _inflight;
  bool _hydratedFromStorage = false;

  List<dynamic>? get cached =>
      _cache == null ? null : List<dynamic>.from(_cache!);
  DateTime? get lastFetch => _lastFetch;
  bool get isFetching => _inflight != null;

  List<dynamic> getCachedServices() {
    return _cache == null ? <dynamic>[] : List<dynamic>.from(_cache!);
  }

  CachedListSnapshot snapshot() {
    return CachedListSnapshot(
      items: _cache == null ? const <dynamic>[] : List<dynamic>.from(_cache!),
      fetchedAt: _lastFetch,
    );
  }

  bool isStale() => snapshot().isStale(ttl);

  Future<void> ensureHydrated() async {
    if (_hydratedFromStorage) return;
    final existing = _hydrateFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final future = _hydrateFromStorage();
    _hydrateFuture = future;
    try {
      await future;
    } finally {
      _hydrateFuture = null;
    }
  }

  Future<CachedListFetchResult> fetchServices({
    bool forceRefresh = false,
    String reason = 'unknown',
  }) async {
    await ensureHydrated();

    final snapshot = this.snapshot();
    if (!forceRefresh && snapshot.hasData && !snapshot.isStale(ttl)) {
      HomeFlowLog.log(
        'services_repo',
        'fetch_skipped_cache_hit',
        details: <String, Object?>{
          'reason': reason,
          'count': snapshot.items.length,
        },
      );
      return CachedListFetchResult.fromSnapshot(snapshot);
    }

    final now = DateTime.now();
    if (!forceRefresh &&
        _lastAttemptAt != null &&
        now.difference(_lastAttemptAt!) < _minRefreshGap) {
      HomeFlowLog.log(
        'services_repo',
        'fetch_skipped_min_gap',
        details: <String, Object?>{
          'reason': reason,
          'count': snapshot.items.length,
        },
      );
      if (!snapshot.hasData && _lastFailure != null) {
        return CachedListFetchResult(
          items: const <dynamic>[],
          fetchedAt: snapshot.fetchedAt,
          fromCache: false,
          networkFetched: false,
          backendReturnedEmpty: false,
          failure: _lastFailure,
        );
      }
      return CachedListFetchResult.fromSnapshot(snapshot);
    }

    final inflight = _inflight;
    if (!forceRefresh && inflight != null) {
      HomeFlowLog.log(
        'services_repo',
        'fetch_joined_inflight',
        details: <String, Object?>{'reason': reason},
      );
      return inflight;
    }

    _lastAttemptAt = now;
    HomeFlowLog.log(
      'services_repo',
      'fetch_start',
      details: <String, Object?>{
        'reason': reason,
        'force': forceRefresh,
        'cached_count': snapshot.items.length,
      },
    );

    final future = _fetchFromNetwork(reason: reason);
    _inflight = future;
    try {
      return await future;
    } finally {
      if (identical(_inflight, future)) {
        _inflight = null;
      }
    }
  }

  Future<List<dynamic>> getServices({bool forceRefresh = false}) async {
    final result = await fetchServices(
      forceRefresh: forceRefresh,
      reason: forceRefresh ? 'get_services_forced' : 'get_services',
    );
    return List<dynamic>.from(result.items);
  }

  Future<List<dynamic>> refreshServices({bool silent = true}) async {
    final result = await fetchServices(
      forceRefresh: true,
      reason: silent ? 'refresh_silent' : 'refresh_manual',
    );
    return List<dynamic>.from(result.items);
  }

  Future<CachedListFetchResult> _fetchFromNetwork({
    required String reason,
  }) async {
    try {
      final data = await _api.fetchServices(forceRefresh: true);
      final normalized = List<dynamic>.from(data);
      _cache = normalized;
      _lastFetch = DateTime.now();
      _lastFailure = null;
      await _persistCache();
      HomeFlowLog.log(
        'services_repo',
        'fetch_success',
        details: <String, Object?>{
          'reason': reason,
          'count': normalized.length,
          'empty': normalized.isEmpty,
        },
      );
      return CachedListFetchResult(
        items: List<dynamic>.from(normalized),
        fetchedAt: _lastFetch,
        fromCache: false,
        networkFetched: true,
        backendReturnedEmpty: normalized.isEmpty,
      );
    } catch (error) {
      final failure = CachedListFailure.fromError(error);
      _lastFailure = failure;
      final fallback = snapshot();
      if (fallback.hasData) {
        HomeFlowLog.log(
          'services_repo',
          'fetch_failure_stale_cache_fallback',
          details: <String, Object?>{
            'reason': reason,
            'kind': failure.kind.name,
            'message': failure.message,
            'count': fallback.items.length,
          },
        );
        return CachedListFetchResult(
          items: List<dynamic>.from(fallback.items),
          fetchedAt: fallback.fetchedAt,
          fromCache: true,
          networkFetched: false,
          backendReturnedEmpty: false,
          failure: failure,
        );
      }

      HomeFlowLog.log(
        'services_repo',
        'fetch_failure',
        details: <String, Object?>{
          'reason': reason,
          'kind': failure.kind.name,
          'message': failure.message,
        },
      );
      return CachedListFetchResult(
        items: const <dynamic>[],
        fetchedAt: null,
        fromCache: false,
        networkFetched: false,
        backendReturnedEmpty: false,
        failure: failure,
      );
    }
  }

  Future<void> _hydrateFromStorage() async {
    if (_hydratedFromStorage) return;
    _hydratedFromStorage = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_cacheStorageKey);
      if (rawJson != null && rawJson.trim().isNotEmpty) {
        final decoded = jsonDecode(rawJson);
        if (decoded is List) {
          _cache = List<dynamic>.from(decoded);
        }
      }
      final fetchedAtMs = prefs.getInt(_cacheFetchedAtKey);
      if (fetchedAtMs != null && fetchedAtMs > 0) {
        _lastFetch = DateTime.fromMillisecondsSinceEpoch(fetchedAtMs);
      }
    } catch (_) {
      HomeFlowLog.log('services_repo', 'hydrate_failure');
    }
  }

  Future<void> _persistCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheStorageKey, jsonEncode(_cache ?? const []));
      await prefs.setInt(
        _cacheFetchedAtKey,
        (_lastFetch ?? DateTime.now()).millisecondsSinceEpoch,
      );
    } catch (_) {
      HomeFlowLog.log('services_repo', 'persist_failure');
    }
  }
}
