import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_app/core/api.dart';
import 'package:fixitzed_app/state/service_providers.dart';
import 'package:fixitzed_app/state/app_sync.dart';

class DashboardState {
  const DashboardState({
    this.name = '',
    this.location = '',
    this.avatarUrl,
    this.categories = const <dynamic>[],
    this.services = const <dynamic>[],
    this.hasUnread = false,
    this.error,
    this.isInactive = false,
    this.areCategoriesLoading = false,
    this.hasResolvedCategories = false,
  });

  final String name;
  final String location;
  final String? avatarUrl;
  final List<dynamic> categories;
  final List<dynamic> services;
  final bool hasUnread;
  final String? error;
  final bool isInactive;
  final bool areCategoriesLoading;
  final bool hasResolvedCategories;

  DashboardState copyWith({
    String? name,
    String? location,
    String? avatarUrl,
    List<dynamic>? categories,
    List<dynamic>? services,
    bool? hasUnread,
    String? error,
    bool? isInactive,
    bool? areCategoriesLoading,
    bool? hasResolvedCategories,
  }) {
    return DashboardState(
      name: name ?? this.name,
      location: location ?? this.location,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      categories: categories ?? this.categories,
      services: services ?? this.services,
      hasUnread: hasUnread ?? this.hasUnread,
      error: error ?? this.error,
      isInactive: isInactive ?? this.isInactive,
      areCategoriesLoading: areCategoriesLoading ?? this.areCategoriesLoading,
      hasResolvedCategories:
          hasResolvedCategories ?? this.hasResolvedCategories,
    );
  }
}

class DashboardController extends AsyncNotifier<DashboardState> {
  static const _minCategoriesLoaderDuration = Duration(milliseconds: 500);
  bool _syncRegistered = false;
  bool _forceProfileRefreshNext = false;

  @override
  FutureOr<DashboardState> build() {
    _registerSync();
    final initial = _initialFromCache();
    final shouldShowCategoriesLoader = initial.categories.isEmpty;
    final seeded = initial.copyWith(
      areCategoriesLoading: shouldShowCategoriesLoader,
      hasResolvedCategories: !shouldShowCategoriesLoader,
    );
    unawaited(_refreshFromNetwork(showLoading: shouldShowCategoriesLoader));
    return seeded;
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    final shouldShowLoader =
        current == null ||
        current.categories.isEmpty ||
        !current.hasResolvedCategories;
    await _refreshFromNetwork(showLoading: shouldShowLoader);
  }

  void _registerSync() {
    if (_syncRegistered) return;
    _syncRegistered = true;

    void handleEvent(AppSyncEvent _) => unawaited(refresh());

    ref.onAppSync(AppSyncTopic.dashboard, (event) {
      if (_isProfileMutationEvent(event)) {
        _forceProfileRefreshNext = true;
      }
      handleEvent(event);
    });
    ref.onAppSync(AppSyncTopic.notifications, (event) {
      handleEvent(event);
    });
  }

  Future<void> _refreshFromNetwork({bool showLoading = false}) async {
    final startedAt = DateTime.now();
    if (showLoading) {
      final current = state.valueOrNull ?? const DashboardState();
      final loadingState = current.copyWith(
        areCategoriesLoading: true,
        hasResolvedCategories: false,
      );
      state = const AsyncValue<DashboardState>.loading().copyWithPrevious(
        AsyncValue<DashboardState>.data(loadingState),
      );
    }
    final result = await AsyncValue.guard(_fetchDashboard);
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _minCategoriesLoaderDuration - elapsed;
    if (showLoading && remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }

    state = result.whenData(
      (data) => data.copyWith(
        areCategoriesLoading: false,
        hasResolvedCategories: true,
      ),
    );
  }

  Future<DashboardState> _fetchDashboard() async {
    final profileRepo = ref.read(profileRepositoryProvider);
    final servicesRepo = ref.read(servicesRepositoryProvider);
    final notificationsRepo = ref.read(notificationsRepositoryProvider);

    Map<String, dynamic>? me;
    var services = <dynamic>[];
    var notifications = <dynamic>[];
    String? error;
    var inactive = false;

    try {
      final forceProfileRefresh = _forceProfileRefreshNext;
      _forceProfileRefreshNext = false;
      me = await profileRepo.getProfile(forceRefresh: forceProfileRefresh);
      final userMap = _extractUserMap(me);
      inactive = _isInactive(userMap);
      if (!inactive) {
        final servicesFuture = servicesRepo.getServices();
        final notificationsFuture = notificationsRepo.getNotifications();

        services = await servicesFuture;
        notifications = await notificationsFuture;
      }
    } catch (err) {
      error = err.toString();
    }

    final userMap = _extractUserMap(me);
    final name = _resolveName(userMap);
    final location = _resolveLocation(userMap);
    final avatarUrl = _resolveAvatar(userMap);
    final hasUnread = _detectUnread(notifications);

    return DashboardState(
      name: name,
      location: location,
      avatarUrl: avatarUrl,
      categories: _deriveCategories(services),
      services: List<dynamic>.from(services),
      hasUnread: hasUnread,
      error: error,
      isInactive: inactive,
      areCategoriesLoading: false,
      hasResolvedCategories: true,
    );
  }

  bool _isProfileMutationEvent(AppSyncEvent event) {
    final payload = event.payload;
    if (payload is! Map) return false;
    final source = payload['source']?.toString().trim().toLowerCase();
    final action = payload['action']?.toString().trim().toLowerCase();
    return source == 'profile' || action == 'profileupdated';
  }

  Map<String, dynamic> _extractUserMap(Map<String, dynamic>? me) {
    if (me == null) return <String, dynamic>{};
    if (me['user'] is Map) {
      return Map<String, dynamic>.from(me['user'] as Map);
    }
    return Map<String, dynamic>.from(me);
  }

  String _resolveName(Map<String, dynamic> raw) {
    final first =
        (raw['first_name'] ?? raw['firstname'] ?? raw['firstName'] ?? '')
            .toString()
            .trim();
    final last = (raw['last_name'] ?? raw['lastname'] ?? raw['lastName'] ?? '')
        .toString()
        .trim();
    final combined = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (combined.isNotEmpty) return combined;

    final fallback =
        (raw['name'] ??
                raw['full_name'] ??
                raw['fullName'] ??
                raw['username'] ??
                '')
            .toString()
            .trim();
    return fallback;
  }

  List<dynamic> _deriveCategories(List<dynamic> services) {
    if (services.isEmpty) return const <dynamic>[];
    final set = <String, String>{}; // key -> label
    for (final raw in services) {
      if (raw is! Map) continue;
      final cat =
          (raw['category'] ?? raw['category_name'] ?? raw['categoryName'] ?? '')
              .toString()
              .trim();
      final normalized = cat.isEmpty ? 'general' : cat.toLowerCase();
      if (!set.containsKey(normalized)) {
        final label = cat.isEmpty ? 'General' : cat;
        set[normalized] = label;
      }
    }
    final list = set.entries
        .map((e) => {'id': e.key, 'name': e.value})
        .toList();
    list.sort(
      (a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo(
        (b['name'] ?? '').toString().toLowerCase(),
      ),
    );
    return list;
  }

  String _resolveLocation(Map<String, dynamic> raw) {
    final city = (raw['city'] ?? '').toString().trim();
    final country = (raw['country'] ?? '').toString().trim();
    final address = (raw['address'] ?? raw['location'] ?? '').toString().trim();
    final province = (raw['province'] ?? raw['province_name'] ?? '')
        .toString()
        .trim();
    final district = (raw['district'] ?? raw['district_name'] ?? '')
        .toString()
        .trim();

    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    if (address.isNotEmpty) return address;
    final parts = [province, district].where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(', ');
    if (city.isNotEmpty) return city;
    return '';
  }

  String? _resolveAvatar(Map<String, dynamic> raw) {
    final avatarRaw =
        (raw['avatar_url'] ??
                raw['avatarUrl'] ??
                raw['profile_photo_path'] ??
                raw['avatar'] ??
                raw['photo'] ??
                raw['profile_photo_url'] ??
                raw['profile_image'] ??
                raw['image'])
            ?.toString();
    final resolved = Api.resolveImageUrl(avatarRaw);
    if (resolved.isEmpty) return null;

    final versionToken = _resolveAvatarVersionToken(raw);
    if (versionToken.isEmpty) return resolved;
    return Api.withCacheBust(resolved, versionToken);
  }

  String _resolveAvatarVersionToken(Map<String, dynamic> raw) {
    const keys = [
      'avatar_updated_at',
      'avatarUpdatedAt',
      'profile_photo_updated_at',
      'profilePhotoUpdatedAt',
      'updated_at',
      'updatedAt',
    ];

    for (final key in keys) {
      final value = raw[key];
      if (value == null) continue;
      final token = value.toString().trim();
      if (token.isEmpty || token.toLowerCase() == 'null') continue;
      return token;
    }

    return '';
  }

  bool _detectUnread(List<dynamic> notifications) {
    for (final n in notifications) {
      if (n is! Map) continue;
      final readVal = n['read'] ?? n['read_at'] ?? n['is_read'];
      bool read;
      if (readVal is bool) {
        read = readVal;
      } else if (readVal is num) {
        read = readVal != 0;
      } else if (readVal is String) {
        final v = readVal.trim().toLowerCase();
        read = v.isNotEmpty && v != '0' && v != 'false';
      } else {
        read = false;
      }
      if (!read) return true;
    }
    return false;
  }

  bool _isInactive(Map<String, dynamic> user) {
    final status =
        (user['status'] ?? user['account_status'] ?? user['state'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
    final activeField = user['active'] ?? user['is_active'] ?? user['isActive'];
    if (activeField is bool) {
      if (activeField) return false;
      return true;
    }
    if (activeField is num) {
      if (activeField == 1) return false;
      if (activeField == 0) return true;
    }
    if (activeField is String) {
      final v = activeField.toLowerCase().trim();
      if (v == '1' || v == 'true' || v == 'yes') return false;
      if (v == '0' || v == 'false' || v == 'no') return true;
    }
    const blockedValues = {
      'inactive',
      'blocked',
      'disabled',
      'suspended',
      'deactivated',
    };
    return blockedValues.contains(status);
  }

  DashboardState _initialFromCache() {
    final profileRepo = ref.read(profileRepositoryProvider);
    final categoriesRepo = ref.read(categoriesRepositoryProvider);
    final servicesRepo = ref.read(servicesRepositoryProvider);
    final notificationsRepo = ref.read(notificationsRepositoryProvider);

    final me = profileRepo.cached;
    final categories = categoriesRepo.cachedSubcategories ?? const <dynamic>[];
    final services = servicesRepo.cached ?? const <dynamic>[];
    final notifications =
        notificationsRepo.cached ?? const <Map<String, dynamic>>[];

    final userMap = _extractUserMap(me);
    final name = _resolveName(userMap);
    final location = _resolveLocation(userMap);
    final avatarUrl = _resolveAvatar(userMap);
    final hasUnread = _detectUnread(notifications);

    return DashboardState(
      name: name,
      location: location,
      avatarUrl: avatarUrl,
      categories: List<dynamic>.from(categories),
      services: List<dynamic>.from(services),
      hasUnread: hasUnread,
      isInactive: _isInactive(userMap),
      areCategoriesLoading: false,
      hasResolvedCategories: categories.isNotEmpty,
    );
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );
