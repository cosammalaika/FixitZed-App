import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fixitzed_app/services/home_service.dart';
import 'package:fixitzed_app/services/notification_service.dart';
import 'package:fixitzed_app/services/service_request_service.dart';
import 'package:fixitzed_app/services/payment_service.dart';

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
