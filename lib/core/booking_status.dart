enum BookingStatus { pending, accepted, completed, cancelled, unknown }

BookingStatus parseBookingStatus(dynamic raw) {
  final s = (raw ?? '').toString().trim().toLowerCase();

  switch (s) {
    case 'pending':
    case 'awaiting':
    case 'requested':
    case 'open':
      return BookingStatus.pending;

    case 'accepted':
    case 'assigned':
    case 'approved':
      return BookingStatus.accepted;

    case 'completed':
    case 'done':
      return BookingStatus.completed;

    case 'cancelled':
    case 'canceled':
    case 'rejected':
      return BookingStatus.cancelled;

    default:
      return BookingStatus.unknown;
  }
}

String bookingStatusLabel(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return 'Pending';
    case BookingStatus.accepted:
      return 'Accepted';
    case BookingStatus.completed:
      return 'Completed';
    case BookingStatus.cancelled:
      return 'Cancelled';
    case BookingStatus.unknown:
      // Safest fallback: never imply acceptance from unknown values.
      return 'Pending';
  }
}
