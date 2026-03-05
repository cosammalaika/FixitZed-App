import 'package:fixitzed_app/utils/service_availability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('service availability helpers', () {
    test('prefers canonical available_fixers_count field', () {
      final service = <String, dynamic>{
        'available_fixers_count': 3,
        'fixers_count': 0,
      };

      expect(serviceAvailableFixersCount(service), 3);
      expect(serviceHasAvailableFixers(service), isTrue);
    });

    test('falls back to boolean availability flag', () {
      final service = <String, dynamic>{
        'has_available_fixers': false,
      };

      expect(serviceAvailableFixersCount(service), 0);
      expect(serviceHasAvailableFixers(service), isFalse);
    });

    test('falls back to legacy count fields', () {
      final service = <String, dynamic>{
        'ready_fixers_count': '2',
      };

      expect(serviceAvailableFixersCount(service), 2);
      expect(serviceHasAvailableFixers(service), isTrue);
    });

    test('falls back to embedded fixers list length', () {
      final service = <String, dynamic>{
        'fixers': [
          {'id': 1},
          {'id': 2},
        ],
      };

      expect(serviceAvailableFixersCount(service), 2);
      expect(serviceHasAvailableFixers(service), isTrue);
    });
  });
}

