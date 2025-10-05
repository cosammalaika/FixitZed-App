import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/home_service.dart';
import '../services/notification_service.dart';
import '../services/service_request_service.dart';
import '../services/payment_service.dart';

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
