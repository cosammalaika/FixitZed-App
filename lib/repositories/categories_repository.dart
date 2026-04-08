import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:fixitzed_app/repositories/cached_list_resource.dart';
import 'package:fixitzed_app/services/home_service.dart';
import 'package:fixitzed_app/utils/home_flow_log.dart';

/// Cache for categories and subcategories lists.
class CategoriesRepository {
  CategoriesRepository(this._api);

  static const Duration ttl = Duration(minutes: 15);
  static const Duration _minRefreshGap = Duration(seconds: 30);
  static const _categoriesStorageKey = 'categories_repository.categories';
  static const _categoriesFetchedAtKey =
      'categories_repository.categories_fetched_at';
  static const _subcategoriesStorageKey =
      'categories_repository.subcategories';
  static const _subcategoriesFetchedAtKey =
      'categories_repository.subcategories_fetched_at';

  final HomeService _api;

  List<dynamic>? _categories;
  List<dynamic>? _subcategories;
  DateTime? _categoriesFetchedAt;
  DateTime? _subcategoriesFetchedAt;
  DateTime? _categoriesLastAttemptAt;
  DateTime? _subcategoriesLastAttemptAt;
  CachedListFailure? _categoriesLastFailure;
  CachedListFailure? _subcategoriesLastFailure;
  Future<void>? _hydrateFuture;
  Future<CachedListFetchResult>? _categoriesInflight;
  Future<CachedListFetchResult>? _subcategoriesInflight;
  bool _hydratedFromStorage = false;

  List<dynamic>? get cachedCategories =>
      _categories == null ? null : List<dynamic>.from(_categories!);

  List<dynamic>? get cachedSubcategories =>
      _subcategories == null ? null : List<dynamic>.from(_subcategories!);

  CachedListSnapshot categoriesSnapshot() {
    return CachedListSnapshot(
      items: _categories == null
          ? const <dynamic>[]
          : List<dynamic>.from(_categories!),
      fetchedAt: _categoriesFetchedAt,
    );
  }

  CachedListSnapshot subcategoriesSnapshot() {
    return CachedListSnapshot(
      items: _subcategories == null
          ? const <dynamic>[]
          : List<dynamic>.from(_subcategories!),
      fetchedAt: _subcategoriesFetchedAt,
    );
  }

  bool isCategoriesStale() => categoriesSnapshot().isStale(ttl);
  bool isSubcategoriesStale() => subcategoriesSnapshot().isStale(ttl);

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

  Future<CachedListFetchResult> fetchCategories({
    bool forceRefresh = false,
    String reason = 'unknown',
  }) async {
    await ensureHydrated();
    final snapshot = categoriesSnapshot();
    if (!forceRefresh && snapshot.hasData && !snapshot.isStale(ttl)) {
      HomeFlowLog.log(
        'categories_repo',
        'fetch_skipped_cache_hit',
        details: <String, Object?>{
          'target': 'categories',
          'reason': reason,
          'count': snapshot.items.length,
        },
      );
      return CachedListFetchResult.fromSnapshot(snapshot);
    }

    final now = DateTime.now();
    if (!forceRefresh &&
        _categoriesLastAttemptAt != null &&
        now.difference(_categoriesLastAttemptAt!) < _minRefreshGap) {
      HomeFlowLog.log(
        'categories_repo',
        'fetch_skipped_min_gap',
        details: <String, Object?>{
          'target': 'categories',
          'reason': reason,
          'count': snapshot.items.length,
        },
      );
      if (!snapshot.hasData && _categoriesLastFailure != null) {
        return CachedListFetchResult(
          items: const <dynamic>[],
          fetchedAt: snapshot.fetchedAt,
          fromCache: false,
          networkFetched: false,
          backendReturnedEmpty: false,
          failure: _categoriesLastFailure,
        );
      }
      return CachedListFetchResult.fromSnapshot(snapshot);
    }

    final inflight = _categoriesInflight;
    if (!forceRefresh && inflight != null) {
      HomeFlowLog.log(
        'categories_repo',
        'fetch_joined_inflight',
        details: <String, Object?>{'target': 'categories', 'reason': reason},
      );
      return inflight;
    }

    _categoriesLastAttemptAt = now;
    final future = _fetchCategoriesFromNetwork(reason: reason);
    _categoriesInflight = future;
    try {
      return await future;
    } finally {
      if (identical(_categoriesInflight, future)) {
        _categoriesInflight = null;
      }
    }
  }

  Future<CachedListFetchResult> fetchSubcategoriesResource({
    bool forceRefresh = false,
    String reason = 'unknown',
    int? categoryId,
  }) async {
    await ensureHydrated();
    if (categoryId != null) {
      return _fetchSubcategoriesForCategory(
        categoryId: categoryId,
        reason: reason,
      );
    }

    final snapshot = subcategoriesSnapshot();
    if (!forceRefresh && snapshot.hasData && !snapshot.isStale(ttl)) {
      HomeFlowLog.log(
        'categories_repo',
        'fetch_skipped_cache_hit',
        details: <String, Object?>{
          'target': 'subcategories',
          'reason': reason,
          'count': snapshot.items.length,
        },
      );
      return CachedListFetchResult.fromSnapshot(snapshot);
    }

    final now = DateTime.now();
    if (!forceRefresh &&
        _subcategoriesLastAttemptAt != null &&
        now.difference(_subcategoriesLastAttemptAt!) < _minRefreshGap) {
      HomeFlowLog.log(
        'categories_repo',
        'fetch_skipped_min_gap',
        details: <String, Object?>{
          'target': 'subcategories',
          'reason': reason,
          'count': snapshot.items.length,
        },
      );
      if (!snapshot.hasData && _subcategoriesLastFailure != null) {
        return CachedListFetchResult(
          items: const <dynamic>[],
          fetchedAt: snapshot.fetchedAt,
          fromCache: false,
          networkFetched: false,
          backendReturnedEmpty: false,
          failure: _subcategoriesLastFailure,
        );
      }
      return CachedListFetchResult.fromSnapshot(snapshot);
    }

    final inflight = _subcategoriesInflight;
    if (!forceRefresh && inflight != null) {
      HomeFlowLog.log(
        'categories_repo',
        'fetch_joined_inflight',
        details: <String, Object?>{
          'target': 'subcategories',
          'reason': reason,
        },
      );
      return inflight;
    }

    _subcategoriesLastAttemptAt = now;
    final future = _fetchSubcategoriesFromNetwork(reason: reason);
    _subcategoriesInflight = future;
    try {
      return await future;
    } finally {
      if (identical(_subcategoriesInflight, future)) {
        _subcategoriesInflight = null;
      }
    }
  }

  Future<List<dynamic>> getCategories({bool forceRefresh = false}) async {
    final result = await fetchCategories(
      forceRefresh: forceRefresh,
      reason: forceRefresh ? 'get_categories_forced' : 'get_categories',
    );
    return List<dynamic>.from(result.items);
  }

  Future<List<dynamic>> getSubcategories({
    bool forceRefresh = false,
    int? categoryId,
  }) async {
    final result = await fetchSubcategoriesResource(
      forceRefresh: forceRefresh,
      reason: forceRefresh ? 'get_subcategories_forced' : 'get_subcategories',
      categoryId: categoryId,
    );
    return List<dynamic>.from(result.items);
  }

  Future<CachedListFetchResult> _fetchCategoriesFromNetwork({
    required String reason,
  }) async {
    HomeFlowLog.log(
      'categories_repo',
      'fetch_start',
      details: <String, Object?>{
        'target': 'categories',
        'reason': reason,
        'cached_count': categoriesSnapshot().items.length,
      },
    );

    try {
      final data = await _api.fetchCategories();
      final normalized = List<dynamic>.from(data);
      _categories = normalized;
      _categoriesFetchedAt = DateTime.now();
      _categoriesLastFailure = null;
      await _persist();
      HomeFlowLog.log(
        'categories_repo',
        'fetch_success',
        details: <String, Object?>{
          'target': 'categories',
          'reason': reason,
          'count': normalized.length,
          'empty': normalized.isEmpty,
        },
      );
      return CachedListFetchResult(
        items: List<dynamic>.from(normalized),
        fetchedAt: _categoriesFetchedAt,
        fromCache: false,
        networkFetched: true,
        backendReturnedEmpty: normalized.isEmpty,
      );
    } catch (error) {
      final failure = CachedListFailure.fromError(error);
      _categoriesLastFailure = failure;
      final fallback = categoriesSnapshot();
      if (fallback.hasData) {
        HomeFlowLog.log(
          'categories_repo',
          'fetch_failure_stale_cache_fallback',
          details: <String, Object?>{
            'target': 'categories',
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
        'categories_repo',
        'fetch_failure',
        details: <String, Object?>{
          'target': 'categories',
          'reason': reason,
          'kind': failure.kind.name,
          'message': failure.message,
        },
      );
      return CachedListFetchResult(
        items: const <dynamic>[],
        fromCache: false,
        networkFetched: false,
        backendReturnedEmpty: false,
        failure: failure,
      );
    }
  }

  Future<CachedListFetchResult> _fetchSubcategoriesFromNetwork({
    required String reason,
  }) async {
    HomeFlowLog.log(
      'categories_repo',
      'fetch_start',
      details: <String, Object?>{
        'target': 'subcategories',
        'reason': reason,
        'cached_count': subcategoriesSnapshot().items.length,
      },
    );

    try {
      final data = await _api.fetchSubcategories();
      final normalized = List<dynamic>.from(data);
      _subcategories = normalized;
      _subcategoriesFetchedAt = DateTime.now();
      _subcategoriesLastFailure = null;
      await _persist();
      HomeFlowLog.log(
        'categories_repo',
        'fetch_success',
        details: <String, Object?>{
          'target': 'subcategories',
          'reason': reason,
          'count': normalized.length,
          'empty': normalized.isEmpty,
        },
      );
      return CachedListFetchResult(
        items: List<dynamic>.from(normalized),
        fetchedAt: _subcategoriesFetchedAt,
        fromCache: false,
        networkFetched: true,
        backendReturnedEmpty: normalized.isEmpty,
      );
    } catch (error) {
      final failure = CachedListFailure.fromError(error);
      _subcategoriesLastFailure = failure;
      final fallback = subcategoriesSnapshot();
      if (fallback.hasData) {
        HomeFlowLog.log(
          'categories_repo',
          'fetch_failure_stale_cache_fallback',
          details: <String, Object?>{
            'target': 'subcategories',
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
        'categories_repo',
        'fetch_failure',
        details: <String, Object?>{
          'target': 'subcategories',
          'reason': reason,
          'kind': failure.kind.name,
          'message': failure.message,
        },
      );
      return CachedListFetchResult(
        items: const <dynamic>[],
        fromCache: false,
        networkFetched: false,
        backendReturnedEmpty: false,
        failure: failure,
      );
    }
  }

  Future<CachedListFetchResult> _fetchSubcategoriesForCategory({
    required int categoryId,
    required String reason,
  }) async {
    HomeFlowLog.log(
      'categories_repo',
      'fetch_start',
      details: <String, Object?>{
        'target': 'subcategories_by_category',
        'reason': reason,
        'category_id': categoryId,
      },
    );

    try {
      final data = await _api.fetchSubcategories(categoryId: categoryId);
      final normalized = List<dynamic>.from(data);
      HomeFlowLog.log(
        'categories_repo',
        'fetch_success',
        details: <String, Object?>{
          'target': 'subcategories_by_category',
          'reason': reason,
          'category_id': categoryId,
          'count': normalized.length,
          'empty': normalized.isEmpty,
        },
      );
      return CachedListFetchResult(
        items: normalized,
        fromCache: false,
        networkFetched: true,
        backendReturnedEmpty: normalized.isEmpty,
      );
    } catch (error) {
      final failure = CachedListFailure.fromError(error);
      HomeFlowLog.log(
        'categories_repo',
        'fetch_failure',
        details: <String, Object?>{
          'target': 'subcategories_by_category',
          'reason': reason,
          'category_id': categoryId,
          'kind': failure.kind.name,
          'message': failure.message,
        },
      );
      return CachedListFetchResult(
        items: const <dynamic>[],
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

      final rawCategories = prefs.getString(_categoriesStorageKey);
      if (rawCategories != null && rawCategories.trim().isNotEmpty) {
        final decoded = jsonDecode(rawCategories);
        if (decoded is List) {
          _categories = List<dynamic>.from(decoded);
        }
      }

      final rawSubcategories = prefs.getString(_subcategoriesStorageKey);
      if (rawSubcategories != null && rawSubcategories.trim().isNotEmpty) {
        final decoded = jsonDecode(rawSubcategories);
        if (decoded is List) {
          _subcategories = List<dynamic>.from(decoded);
        }
      }

      final categoriesFetchedAtMs = prefs.getInt(_categoriesFetchedAtKey);
      if (categoriesFetchedAtMs != null && categoriesFetchedAtMs > 0) {
        _categoriesFetchedAt = DateTime.fromMillisecondsSinceEpoch(
          categoriesFetchedAtMs,
        );
      }

      final subcategoriesFetchedAtMs = prefs.getInt(_subcategoriesFetchedAtKey);
      if (subcategoriesFetchedAtMs != null && subcategoriesFetchedAtMs > 0) {
        _subcategoriesFetchedAt = DateTime.fromMillisecondsSinceEpoch(
          subcategoriesFetchedAtMs,
        );
      }
    } catch (_) {
      HomeFlowLog.log('categories_repo', 'hydrate_failure');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _categoriesStorageKey,
        jsonEncode(_categories ?? const []),
      );
      await prefs.setString(
        _subcategoriesStorageKey,
        jsonEncode(_subcategories ?? const []),
      );
      await prefs.setInt(
        _categoriesFetchedAtKey,
        (_categoriesFetchedAt ?? DateTime.now()).millisecondsSinceEpoch,
      );
      await prefs.setInt(
        _subcategoriesFetchedAtKey,
        (_subcategoriesFetchedAt ?? DateTime.now()).millisecondsSinceEpoch,
      );
    } catch (_) {
      HomeFlowLog.log('categories_repo', 'persist_failure');
    }
  }
}
