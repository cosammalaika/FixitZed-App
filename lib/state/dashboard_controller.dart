import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import 'service_providers.dart';

class DashboardState {
  const DashboardState({
    this.name = '',
    this.location = '',
    this.avatarUrl,
    this.categories = const <dynamic>[],
    this.services = const <dynamic>[],
    this.hasUnread = false,
    this.error,
  });

  final String name;
  final String location;
  final String? avatarUrl;
  final List<dynamic> categories;
  final List<dynamic> services;
  final bool hasUnread;
  final String? error;

  DashboardState copyWith({
    String? name,
    String? location,
    String? avatarUrl,
    List<dynamic>? categories,
    List<dynamic>? services,
    bool? hasUnread,
    String? error,
  }) {
    return DashboardState(
      name: name ?? this.name,
      location: location ?? this.location,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      categories: categories ?? this.categories,
      services: services ?? this.services,
      hasUnread: hasUnread ?? this.hasUnread,
      error: error ?? this.error,
    );
  }
}

class DashboardController extends AutoDisposeAsyncNotifier<DashboardState> {
  @override
  FutureOr<DashboardState> build() {
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncValue<DashboardState>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(_fetch);
  }

  Future<DashboardState> _fetch() async {
    final homeService = ref.read(homeServiceProvider);
    final notificationService = ref.read(notificationServiceProvider);

    Map<String, dynamic>? me;
    List<dynamic> categories = const [];
    List<dynamic> services = const [];
    List<dynamic> notifications = const [];
    String? error;

    try {
      final meFuture = homeService.fetchMe();
      final categoriesFuture = homeService.fetchCategories();
      final servicesFuture = homeService.fetchServices();
      final notificationsFuture = notificationService.fetch(page: 1);

      me = await meFuture;
      categories = await categoriesFuture;
      services = await servicesFuture;
      notifications = await notificationsFuture;
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
      categories: List<dynamic>.from(categories),
      services: List<dynamic>.from(services),
      hasUnread: hasUnread,
      error: error,
    );
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

  String _resolveLocation(Map<String, dynamic> raw) {
    final city = (raw['city'] ?? '').toString().trim();
    final country = (raw['country'] ?? '').toString().trim();
    final address = (raw['address'] ?? raw['location'] ?? '').toString().trim();

    if (city.isNotEmpty && country.isNotEmpty) return '$city, $country';
    if (address.isNotEmpty) return address;
    if (city.isNotEmpty) return city;
    return '';
  }

  String? _resolveAvatar(Map<String, dynamic> raw) {
    final avatarRaw =
        (raw['profile_photo_path'] ??
                raw['avatar'] ??
                raw['photo'] ??
                raw['profile_photo_url'] ??
                raw['profile_image'] ??
                raw['image'])
            ?.toString();
    final resolved = Api.resolveImageUrl(avatarRaw);
    return resolved.isEmpty ? null : resolved;
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
}

final dashboardControllerProvider =
    AutoDisposeAsyncNotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );
