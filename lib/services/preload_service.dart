import 'dart:async';

import 'package:fixitzed_app/repositories/bookings_repository.dart';
import 'package:fixitzed_app/repositories/categories_repository.dart';
import 'package:fixitzed_app/repositories/favorites_repository.dart';
import 'package:fixitzed_app/repositories/notifications_repository.dart';
import 'package:fixitzed_app/repositories/profile_repository.dart';
import 'package:fixitzed_app/repositories/services_repository.dart';

/// PreloadService warms up high-traffic endpoints right after auth:
/// - /api/me (profile)
/// - /categories + /subcategories
/// - /services
/// - /notifications?page=1
/// - /requests (bookings) and payment lookups
/// Triggered after login success and on startup once token is validated.
class PreloadService {
  PreloadService({
    required ProfileRepository profileRepository,
    required CategoriesRepository categoriesRepository,
    required ServicesRepository servicesRepository,
    required FavoritesRepository favoritesRepository,
    required NotificationsRepository notificationsRepository,
    required BookingsRepository bookingsRepository,
  })  : _profileRepository = profileRepository,
        _categoriesRepository = categoriesRepository,
        _servicesRepository = servicesRepository,
        _favoritesRepository = favoritesRepository,
        _notificationsRepository = notificationsRepository,
        _bookingsRepository = bookingsRepository;

  final ProfileRepository _profileRepository;
  final CategoriesRepository _categoriesRepository;
  final ServicesRepository _servicesRepository;
  final FavoritesRepository _favoritesRepository;
  final NotificationsRepository _notificationsRepository;
  final BookingsRepository _bookingsRepository;

  Future<void> preloadAll() async {
    final tasks = <Future<void>>[
      _profileRepository.getProfile().then((_) {}, onError: (_) {}),
      _categoriesRepository.getCategories().then((_) {}, onError: (_) {}),
      _categoriesRepository.getSubcategories().then((_) {}, onError: (_) {}),
      _servicesRepository.getServices().then((_) {}, onError: (_) {}),
      _favoritesRepository.getFavoriteIds().then((_) {}, onError: (_) {}),
      _notificationsRepository.getNotifications().then((_) {}, onError: (_) {}),
      _warmBookings(),
    ];
    await Future.wait(tasks.map((f) => f.catchError((_) {})));
  }

  Future<void> _warmBookings() async {
    try {
      final requests = await _bookingsRepository.getRequests();
      for (final r in requests) {
        final id = (r['id'] as num?)?.toInt();
        if (id == null) continue;
        unawaited(_bookingsRepository.getPayment(id));
      }
    } catch (_) {}
  }
}
