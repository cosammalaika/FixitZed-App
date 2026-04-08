import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:fixitzed_app/services/home_service.dart';
import 'package:fixitzed_app/services/notification_service.dart';
import 'package:fixitzed_app/services/service_request_service.dart';
import 'package:fixitzed_app/services/payment_service.dart';
import 'package:fixitzed_app/services/preload_service.dart';
import 'package:fixitzed_app/services/chooser_availability_service.dart';
import 'package:fixitzed_app/repositories/bookings_repository.dart';
import 'package:fixitzed_app/repositories/categories_repository.dart';
import 'package:fixitzed_app/repositories/favorites_repository.dart';
import 'package:fixitzed_app/repositories/notifications_repository.dart';
import 'package:fixitzed_app/repositories/profile_repository.dart';
import 'package:fixitzed_app/repositories/services_repository.dart';
import 'package:fixitzed_app/state/app_sync.dart';
import 'package:fixitzed_app/state/services_controller.dart';

final homeServiceProvider = Provider<HomeService>((ref) => HomeService());
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
final serviceRequestServiceProvider = Provider<ServiceRequestService>(
  (ref) => ServiceRequestService(),
);
final paymentServiceProvider = Provider<PaymentService>(
  (ref) => PaymentService(),
);

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final repo = ProfileRepository(ref.read(homeServiceProvider));
  ref.onAppSync(AppSyncTopic.auth, (event) async {
    if (_isLogoutEvent(event)) await repo.clearCache();
  });
  return repo;
});
final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(ref.read(homeServiceProvider)),
);
final servicesRepositoryProvider = Provider<ServicesRepository>(
  (ref) => ServicesRepository(ref.read(homeServiceProvider)),
);
final servicesControllerProvider = ChangeNotifierProvider<ServicesController>(
  (ref) => ServicesController(ref.read(servicesRepositoryProvider)),
);
final fixerAvailabilityResolverProvider = Provider<FixerAvailabilityResolver>(
  (ref) => FixerAvailabilityResolver(homeService: ref.read(homeServiceProvider)),
);
final favoritesRepositoryProvider = ChangeNotifierProvider<FavoritesRepository>(
  (ref) {
    final repo = FavoritesRepository();
    ref.onAppSync(AppSyncTopic.auth, (event) async {
      if (_isLogoutEvent(event)) await repo.clearCache();
    });
    return repo;
  },
);
final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  final repo = NotificationsRepository(ref.read(notificationServiceProvider));
  ref.onAppSync(AppSyncTopic.auth, (event) {
    if (_isLogoutEvent(event)) repo.clearCache();
  });
  return repo;
});
final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  final repo = BookingsRepository(
    ref.read(serviceRequestServiceProvider),
    ref.read(paymentServiceProvider),
  );
  ref.onAppSync(AppSyncTopic.auth, (event) {
    if (_isLogoutEvent(event)) repo.clearCache();
  });
  return repo;
});

final preloadServiceProvider = Provider<PreloadService>(
  (ref) => PreloadService(
    profileRepository: ref.read(profileRepositoryProvider),
    categoriesRepository: ref.read(categoriesRepositoryProvider),
    servicesRepository: ref.read(servicesRepositoryProvider),
    favoritesRepository: ref.read(favoritesRepositoryProvider),
    notificationsRepository: ref.read(notificationsRepositoryProvider),
    bookingsRepository: ref.read(bookingsRepositoryProvider),
  ),
);

bool _isLogoutEvent(AppSyncEvent event) {
  final payload = event.payload;
  if (payload is! Map) return false;
  return payload['action']?.toString().trim().toLowerCase() == 'logout';
}
