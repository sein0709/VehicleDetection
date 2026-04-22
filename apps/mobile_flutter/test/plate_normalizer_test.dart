import 'package:flutter_test/flutter_test.dart';
import 'package:greyeye_mobile/features/sites/services/plate_normalizer.dart';

void main() {
  group('PlateNormalizer.normalize', () {
    test('accepts canonical 2-digit-prefix plate', () {
      expect(PlateNormalizer.normalize('12가3456'), '12가3456');
    });

    test('accepts canonical 3-digit-prefix plate', () {
      expect(PlateNormalizer.normalize('123나4567'), '123나4567');
    });

    test('strips whitespace before validating', () {
      expect(PlateNormalizer.normalize(' 12 가 3456 '), '12가3456');
      expect(PlateNormalizer.normalize('12\t가\t3456'), '12가3456');
    });

    test('rejects plates without Hangul middle character', () {
      expect(PlateNormalizer.normalize('12A3456'), isNull);
      expect(PlateNormalizer.normalize('123456'), isNull);
    });

    test('rejects too-short prefixes / suffixes', () {
      expect(PlateNormalizer.normalize('1가3456'), isNull);
      expect(PlateNormalizer.normalize('12가345'), isNull);
    });

    test('rejects empty input', () {
      expect(PlateNormalizer.normalize(''), isNull);
      expect(PlateNormalizer.normalize('   '), isNull);
    });
  });

  group('PlateNormalizer.isValid', () {
    test('agrees with normalize', () {
      expect(PlateNormalizer.isValid('12가3456'), isTrue);
      expect(PlateNormalizer.isValid('not a plate'), isFalse);
    });
  });
}
