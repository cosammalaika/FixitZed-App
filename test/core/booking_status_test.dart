import 'package:fixitzed_app/core/booking_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseBookingStatus', () {
    test('maps pending variants to pending', () {
      expect(parseBookingStatus('pending'), BookingStatus.pending);
      expect(parseBookingStatus('awaiting'), BookingStatus.pending);
      expect(parseBookingStatus('requested'), BookingStatus.pending);
      expect(parseBookingStatus('open'), BookingStatus.pending);
    });

    test('maps accepted variants to accepted', () {
      expect(parseBookingStatus('accepted'), BookingStatus.accepted);
      expect(parseBookingStatus('assigned'), BookingStatus.accepted);
    });

    test('maps completed variants to completed', () {
      expect(parseBookingStatus('completed'), BookingStatus.completed);
      expect(parseBookingStatus('done'), BookingStatus.completed);
    });

    test('maps cancelled variants to cancelled', () {
      expect(parseBookingStatus('cancelled'), BookingStatus.cancelled);
      expect(parseBookingStatus('canceled'), BookingStatus.cancelled);
      expect(parseBookingStatus('rejected'), BookingStatus.cancelled);
    });

    test('maps unknown to unknown and safe label', () {
      expect(parseBookingStatus('not-a-real-status'), BookingStatus.unknown);
      expect(bookingStatusLabel(BookingStatus.unknown), 'Pending');
    });
  });
}
