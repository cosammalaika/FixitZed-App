import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_app/common/connectivity/connectivity_controller.dart';
import 'package:fixitzed_app/repositories/cached_list_resource.dart';
import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/utils/home_flow_log.dart';
import 'package:fixitzed_app/utils/service_utils.dart';

enum HomeCollectionViewState { loading, data, empty, offline, failure }

class HomeCollectionState {
  const HomeCollectionState({
    this.items = const <dynamic>[],
    this.viewState = HomeCollectionViewState.loading,
    this.isRefreshing = false,
    this.fromCache = false,
    this.isDerived = false,
    this.error,
    this.fetchedAt,
  });

  final List<dynamic> items;
  final HomeCollectionViewState viewState;
  final bool isRefreshing;
  final bool fromCache;
  final bool isDerived;
  final CachedListFailure? error;
  final DateTime? fetchedAt;

  bool get hasData => items.isNotEmpty;
  bool get isInitialLoading =>
      viewState == HomeCollectionViewState.loading && items.isEmpty;
  bool get isEmptyState =>
      viewState == HomeCollectionViewState.empty && items.isEmpty;
  bool get isOfflineState =>
      viewState == HomeCollectionViewState.offline && items.isEmpty;
  bool get isFailureState =>
      viewState == HomeCollectionViewState.failure && items.isEmpty;

  HomeCollectionState copyWith({
    List<dynamic>? items,
    HomeCollectionViewState? viewState,
    bool? isRefreshing,
    bool? fromCache,
    bool? isDerived,
    CachedListFailure? error,
    bool clearError = false,
    DateTime? fetchedAt,
  }) {
    return HomeCollectionState(
      items: items ?? this.items,
      viewState: viewState ?? this.viewState,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      fromCache: fromCache ?? this.fromCache,
      isDerived: isDerived ?? this.isDerived,
      error: clearError ? null : (error ?? this.error),
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}

class HomeCatalogState {
  const HomeCatalogState({
    this.categories = const HomeCollectionState(),
    this.services = const HomeCollectionState(),
  });

  final HomeCollectionState categories;
  final HomeCollectionState services;

  HomeCatalogState copyWith({
    HomeCollectionState? categories,
    HomeCollectionState? services,
  }) {
    return HomeCatalogState(
      categories: categories ?? this.categories,
      services: services ?? this.services,
    );
  }
}

class HomeCatalogController extends Notifier<HomeCatalogState> {
  Future<void>? _bootstrapFuture;
  Future<void>? _refreshFuture;

  @override
  HomeCatalogState build() {
    ref.listen<ConnectivityStatus>(connectivityProvider, (
      previous,
      next,
    ) {
      _handleConnectivityChange(previous, next);
    });

    final servicesSnapshot = ref.read(servicesRepositoryProvider).snapshot();
    final categoriesSnapshot = ref
        .read(categoriesRepositoryProvider)
        .subcategoriesSnapshot();
    final seeded = _buildStateFromSnapshots(
      servicesSnapshot: servicesSnapshot,
      categoriesSnapshot: categoriesSnapshot,
    );

    unawaited(_bootstrap());
    return seeded;
  }

  Future<void> ensureLoaded({String reason = 'ensure_loaded'}) async {
    await _refreshIfNeeded(forceRefresh: false, reason: reason);
  }

  Future<void> refresh({String reason = 'manual_refresh'}) async {
    await _refreshIfNeeded(forceRefresh: true, reason: reason);
  }

  Future<void> handleAppResumed() async {
    final servicesRepo = ref.read(servicesRepositoryProvider);
    final categoriesRepo = ref.read(categoriesRepositoryProvider);
    final shouldRefresh =
        servicesRepo.isStale() || categoriesRepo.isSubcategoriesStale();

    HomeFlowLog.log(
      'home_catalog',
      shouldRefresh ? 'resume_refresh_requested' : 'resume_refresh_skipped',
      details: <String, Object?>{
        'services_stale': servicesRepo.isStale(),
        'categories_stale': categoriesRepo.isSubcategoriesStale(),
      },
    );

    if (!shouldRefresh) return;
    await _refreshIfNeeded(forceRefresh: false, reason: 'app_resumed');
  }

  Future<void> _bootstrap() async {
    final existing = _bootstrapFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final future = _runBootstrap();
    _bootstrapFuture = future;
    try {
      await future;
    } finally {
      if (identical(_bootstrapFuture, future)) {
        _bootstrapFuture = null;
      }
    }
  }

  Future<void> _runBootstrap() async {
    final servicesRepo = ref.read(servicesRepositoryProvider);
    final categoriesRepo = ref.read(categoriesRepositoryProvider);

    await Future.wait<void>([
      servicesRepo.ensureHydrated(),
      categoriesRepo.ensureHydrated(),
    ]);
    if (!ref.mounted) return;

    final hydratedState = _buildStateFromSnapshots(
      servicesSnapshot: servicesRepo.snapshot(),
      categoriesSnapshot: categoriesRepo.subcategoriesSnapshot(),
    );
    state = hydratedState;

    await _refreshIfNeeded(forceRefresh: false, reason: 'bootstrap');
  }

  Future<void> _refreshIfNeeded({
    required bool forceRefresh,
    required String reason,
  }) async {
    final servicesRepo = ref.read(servicesRepositoryProvider);
    final categoriesRepo = ref.read(categoriesRepositoryProvider);
    final shouldFetchServices = forceRefresh || servicesRepo.isStale();
    final shouldFetchCategories =
        forceRefresh || categoriesRepo.isSubcategoriesStale();

    if (!shouldFetchServices && !shouldFetchCategories) {
      HomeFlowLog.log(
        'home_catalog',
        'fetch_skipped_due_to_cache',
        details: <String, Object?>{
          'reason': reason,
          'services_count': state.services.items.length,
          'categories_count': state.categories.items.length,
        },
      );
      return;
    }

    final inflight = _refreshFuture;
    if (inflight != null) {
      HomeFlowLog.log(
        'home_catalog',
        'fetch_joined_inflight',
        details: <String, Object?>{'reason': reason},
      );
      await inflight;
      return;
    }

    final future = _performRefresh(
      forceRefresh: forceRefresh,
      reason: reason,
      shouldFetchServices: shouldFetchServices,
      shouldFetchCategories: shouldFetchCategories,
    );
    _refreshFuture = future;
    try {
      await future;
    } finally {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    }
  }

  Future<void> _performRefresh({
    required bool forceRefresh,
    required String reason,
    required bool shouldFetchServices,
    required bool shouldFetchCategories,
  }) async {
    HomeFlowLog.log(
      'home_catalog',
      'fetch_start',
      details: <String, Object?>{
        'reason': reason,
        'force': forceRefresh,
        'fetch_services': shouldFetchServices,
        'fetch_categories': shouldFetchCategories,
      },
    );

    state = state.copyWith(
      services: _markRefreshing(state.services, shouldFetchServices),
      categories: _markRefreshing(state.categories, shouldFetchCategories),
    );

    final servicesRepo = ref.read(servicesRepositoryProvider);
    final categoriesRepo = ref.read(categoriesRepositoryProvider);

    final servicesFuture = shouldFetchServices
        ? servicesRepo.fetchServices(
            forceRefresh: forceRefresh,
            reason: reason,
          )
        : Future<CachedListFetchResult>.value(
            CachedListFetchResult.fromSnapshot(servicesRepo.snapshot()),
          );

    final categoriesFuture = shouldFetchCategories
        ? categoriesRepo.fetchSubcategoriesResource(
            forceRefresh: forceRefresh,
            reason: reason,
          )
        : Future<CachedListFetchResult>.value(
            CachedListFetchResult.fromSnapshot(
              categoriesRepo.subcategoriesSnapshot(),
            ),
          );

    final results = await Future.wait<CachedListFetchResult>([
      servicesFuture,
      categoriesFuture,
    ]);
    if (!ref.mounted) return;

    final servicesResult = results[0];
    final categoriesResult = results[1];
    final nextServices = _stateFromResult(
      previous: state.services,
      result: servicesResult,
    );
    final nextCategories = _resolveCategoriesState(
      previous: state.categories,
      servicesState: nextServices,
      result: categoriesResult,
    );

    state = state.copyWith(
      services: nextServices,
      categories: nextCategories,
    );

    HomeFlowLog.log(
      'home_catalog',
      'fetch_complete',
      details: <String, Object?>{
        'reason': reason,
        'services_state': nextServices.viewState.name,
        'services_count': nextServices.items.length,
        'categories_state': nextCategories.viewState.name,
        'categories_count': nextCategories.items.length,
      },
    );
  }

  HomeCatalogState _buildStateFromSnapshots({
    required CachedListSnapshot servicesSnapshot,
    required CachedListSnapshot categoriesSnapshot,
  }) {
    final servicesState = servicesSnapshot.hasData
        ? HomeCollectionState(
            items: List<dynamic>.from(servicesSnapshot.items),
            viewState: HomeCollectionViewState.data,
            fromCache: true,
            fetchedAt: servicesSnapshot.fetchedAt,
          )
        : const HomeCollectionState();

    final resolvedCategories = categoriesSnapshot.hasData
        ? List<dynamic>.from(categoriesSnapshot.items)
        : deriveSubcategoryOptions(servicesSnapshot.items);
    final categoriesState = resolvedCategories.isNotEmpty
        ? HomeCollectionState(
            items: resolvedCategories,
            viewState: HomeCollectionViewState.data,
            fromCache: true,
            isDerived: !categoriesSnapshot.hasData,
            fetchedAt: categoriesSnapshot.fetchedAt ?? servicesSnapshot.fetchedAt,
          )
        : const HomeCollectionState();

    return HomeCatalogState(
      categories: categoriesState,
      services: servicesState,
    );
  }

  HomeCollectionState _markRefreshing(
    HomeCollectionState current,
    bool shouldRefresh,
  ) {
    if (!shouldRefresh) return current;
    if (current.hasData) {
      return current.copyWith(isRefreshing: true, clearError: true);
    }
    return current.copyWith(
      viewState: HomeCollectionViewState.loading,
      isRefreshing: true,
      clearError: true,
    );
  }

  HomeCollectionState _stateFromResult({
    required HomeCollectionState previous,
    required CachedListFetchResult result,
  }) {
    if (result.hasData) {
      return HomeCollectionState(
        items: List<dynamic>.from(result.items),
        viewState: HomeCollectionViewState.data,
        isRefreshing: false,
        fromCache: result.fromCache,
        error: result.failure,
        fetchedAt: result.fetchedAt ?? previous.fetchedAt,
      );
    }

    final failure = result.failure;
    if (failure != null) {
      return HomeCollectionState(
        items: const <dynamic>[],
        viewState: failure.isOfflineLike
            ? HomeCollectionViewState.offline
            : HomeCollectionViewState.failure,
        isRefreshing: false,
        fromCache: false,
        error: failure,
        fetchedAt: previous.fetchedAt,
      );
    }

    return HomeCollectionState(
      items: const <dynamic>[],
      viewState: HomeCollectionViewState.empty,
      isRefreshing: false,
      fromCache: result.fromCache,
      fetchedAt: result.fetchedAt ?? previous.fetchedAt,
    );
  }

  HomeCollectionState _resolveCategoriesState({
    required HomeCollectionState previous,
    required HomeCollectionState servicesState,
    required CachedListFetchResult result,
  }) {
    final directState = _stateFromResult(previous: previous, result: result);
    if (directState.hasData || servicesState.items.isEmpty) {
      return directState;
    }

    final derived = deriveSubcategoryOptions(servicesState.items);
    if (derived.isEmpty) {
      return directState;
    }

    HomeFlowLog.log(
      'home_catalog',
      'categories_derived_from_services',
      details: <String, Object?>{'count': derived.length},
    );

    return HomeCollectionState(
      items: derived,
      viewState: HomeCollectionViewState.data,
      isRefreshing: false,
      fromCache: true,
      isDerived: true,
      error: result.failure,
      fetchedAt: result.fetchedAt ?? servicesState.fetchedAt ?? previous.fetchedAt,
    );
  }

  void _handleConnectivityChange(
    ConnectivityStatus? previous,
    ConnectivityStatus next,
  ) {
    if (previous?.isOnline == false && next.isOnline) {
      HomeFlowLog.log('home_catalog', 'connectivity_restored');
      unawaited(_refreshIfNeeded(forceRefresh: true, reason: 'connectivity_restored'));
      return;
    }

    if (previous?.isOnline != true || next.isOnline) {
      return;
    }

    HomeFlowLog.log('home_catalog', 'connectivity_lost');
    state = state.copyWith(
      services: _markOfflineIfNeeded(state.services),
      categories: _markOfflineIfNeeded(state.categories),
    );
  }

  HomeCollectionState _markOfflineIfNeeded(HomeCollectionState current) {
    if (current.hasData) {
      return current.copyWith(isRefreshing: false);
    }
    return current.copyWith(
      viewState: HomeCollectionViewState.offline,
      isRefreshing: false,
    );
  }
}

final homeCatalogControllerProvider =
    NotifierProvider<HomeCatalogController, HomeCatalogState>(
      HomeCatalogController.new,
    );
