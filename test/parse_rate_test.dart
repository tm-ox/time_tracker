import 'package:flutter_test/flutter_test.dart';
import 'package:timedart/util/parse_rate.dart';

void main() {
  group('parseRate', () {
    test('empty is valid and means no rate', () {
      final r = parseRate('');
      expect(r.value, isNull);
      expect(r.error, isNull);
    });

    test('whitespace-only is treated as empty', () {
      final r = parseRate('   ');
      expect(r.value, isNull);
      expect(r.error, isNull);
    });

    test('a number parses', () {
      final r = parseRate('42.5');
      expect(r.value, 42.5);
      expect(r.error, isNull);
    });

    test('surrounding whitespace is trimmed', () {
      expect(parseRate('  90 ').value, 90);
    });

    test('non-numeric is an error, not a silent null', () {
      final r = parseRate('5o');
      expect(r.value, isNull);
      expect(r.error, isNotNull);
    });
  });

  group('rateText', () {
    test('null is empty', () => expect(rateText(null), ''));
    test('whole rate has no trailing decimal', () {
      expect(rateText(100), '100');
      expect(rateText(100.0), '100');
    });
    test('fractional rate keeps its decimals', () {
      expect(rateText(95.5), '95.5');
      expect(rateText(95.25), '95.25');
    });
  });
}
