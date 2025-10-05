import 'package:meta/meta.dart';

@immutable
class BookingsSnapshot {
  const BookingsSnapshot({
    required this.bookings,
    required this.payments,
    required this.fetchedAt,
  });

  final List<Map<String, dynamic>> bookings;
  final Map<int, Map<String, dynamic>> payments;
  final DateTime fetchedAt;

  bool get hasOutstandingPayments {
    return bookings.any((booking) {
      final id = (booking['id'] as num?)?.toInt();
      if (id == null) return false;
      final payment = payments[id];
      if (payment == null) return false;
      final status = (payment['status'] ?? '').toString().toLowerCase();
      return status != 'paid';
    });
  }

  BookingsSnapshot copyWith({
    List<Map<String, dynamic>>? bookings,
    Map<int, Map<String, dynamic>>? payments,
    DateTime? fetchedAt,
  }) {
    return BookingsSnapshot(
      bookings: bookings ?? this.bookings,
      payments: payments ?? this.payments,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }
}
