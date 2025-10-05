import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/bookings_repository.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/user_repository.dart';
import 'service_providers.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    ref.read(homeServiceProvider),
    ref.read(notificationServiceProvider),
  );
});

final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  return BookingsRepository(
    ref.read(serviceRequestServiceProvider),
    ref.read(paymentServiceProvider),
  );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(homeServiceProvider));
});
