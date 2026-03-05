import 'package:fixitzed_app/utils/phone_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeZambianNumber', () {
    test('keeps +260 numbers unchanged', () {
      expect(normalizeZambianNumber('+260979871199'), '+260979871199');
    });

    test('replaces leading 0 with +260', () {
      expect(normalizeZambianNumber('0979871199'), '+260979871199');
    });

    test('prepends +260 to 9-digit local number', () {
      expect(normalizeZambianNumber('979871199'), '+260979871199');
    });

    test('normalizes spaced and punctuated numbers', () {
      expect(normalizeZambianNumber('(0979) 871-199'), '+260979871199');
    });
  });

  group('formatZambianNumberForDisplay', () {
    test('formats normalized number for UI', () {
      expect(
        formatZambianNumberForDisplay('979871199'),
        '+260 979 871 199',
      );
    });
  });
}
