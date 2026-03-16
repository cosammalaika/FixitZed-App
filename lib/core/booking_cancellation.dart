class BookingCancellationReason {
  const BookingCancellationReason({required this.key, required this.label});

  final String key;
  final String label;
}

const bookingCancellationReasons = <BookingCancellationReason>[
  BookingCancellationReason(
    key: 'no_longer_needed',
    label: 'I no longer need the service',
  ),
  BookingCancellationReason(
    key: 'booked_by_mistake',
    label: 'I booked by mistake',
  ),
  BookingCancellationReason(
    key: 'found_another_fixer',
    label: 'I found another fixer',
  ),
  BookingCancellationReason(key: 'other', label: 'Other'),
];

BookingCancellationReason? bookingCancellationReasonByKey(String? key) {
  if (key == null) return null;
  for (final option in bookingCancellationReasons) {
    if (option.key == key) {
      return option;
    }
  }
  return null;
}

String normalizeBookingStatusKey(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return 'pending';
  return normalized
      .replaceAll(RegExp(r'[^a-z]'), '_')
      .replaceAll(RegExp('_+'), '_');
}

bool isCancelledBookingStatus(String value) {
  final normalized = normalizeBookingStatusKey(value);
  return normalized == 'cancelled' || normalized == 'canceled';
}

bool isCustomerCancelableBookingStatus(String value) {
  final normalized = normalizeBookingStatusKey(value);
  return normalized == 'pending' || normalized == 'accepted';
}

String formatCancellationActor(String? value) {
  final normalized = normalizeBookingStatusKey(value ?? '');
  switch (normalized) {
    case 'customer':
      return 'Customer';
    case 'fixer':
      return 'Fixer';
    case 'admin':
      return 'Admin';
    default:
      return '—';
  }
}
