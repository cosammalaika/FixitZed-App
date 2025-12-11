import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_app/services/home_service.dart';
import 'package:fixitzed_app/services/notification_service.dart';
import 'package:fixitzed_app/services/service_request_service.dart';
import 'package:fixitzed_app/services/payment_service.dart';
import 'package:fixitzed_app/services/preload_service.dart';
import 'package:fixitzed_app/repositories/bookings_repository.dart';
import 'package:fixitzed_app/repositories/categories_repository.dart';
import 'package:fixitzed_app/repositories/favorites_repository.dart';
import 'package:fixitzed_app/repositories/notifications_repository.dart';
import 'package:fixitzed_app/repositories/profile_repository.dart';
import 'package:fixitzed_app/repositories/services_repository.dart';

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

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.read(homeServiceProvider)),
);
final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(ref.read(homeServiceProvider)),
);
final servicesRepositoryProvider = Provider<ServicesRepository>(
  (ref) => ServicesRepository(ref.read(homeServiceProvider)),
);
final favoritesRepositoryProvider = ChangeNotifierProvider<FavoritesRepository>(
  (ref) => FavoritesRepository(),
);
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.read(notificationServiceProvider)),
);
final bookingsRepositoryProvider = Provider<BookingsRepository>(
  (ref) => BookingsRepository(
    ref.read(serviceRequestServiceProvider),
    ref.read(paymentServiceProvider),
  ),
);

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
