import '../../services/payment_service.dart';
import '../../services/service_request_service.dart';
import '../models/bookings_snapshot.dart';

class BookingsRepository {
  BookingsRepository(this._requests, this._payments);

  final ServiceRequestService _requests;
  final PaymentService _payments;

  Future<BookingsSnapshot> fetchBookings() async {
    final bookings = await _requests.listRequests();
    final paymentMap = <int, Map<String, dynamic>>{};

    for (final booking in bookings) {
      final id = (booking['id'] as num?)?.toInt();
      if (id == null) continue;
      try {
        final payment = await _payments.get(id);
        if (payment != null) {
          paymentMap[id] = Map<String, dynamic>.from(payment);
        }
      } catch (_) {
        // Ignore individual payment failures to prevent entire list failing
      }
    }

    return BookingsSnapshot(
      bookings: bookings,
      payments: paymentMap,
      fetchedAt: DateTime.now(),
    );
  }
}
