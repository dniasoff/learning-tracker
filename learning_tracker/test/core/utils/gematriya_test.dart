import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/utils/gematriya.dart';

void main() {
  group('Gematriya.forNumber', () {
    test('single digits', () {
      expect(Gematriya.forNumber(1), 'א');
      expect(Gematriya.forNumber(2), 'ב');
      expect(Gematriya.forNumber(9), 'ט');
    });

    test('tens', () {
      expect(Gematriya.forNumber(10), 'י');
      expect(Gematriya.forNumber(11), 'יא');
      expect(Gematriya.forNumber(14), 'יד');
      expect(Gematriya.forNumber(17), 'יז');
      expect(Gematriya.forNumber(20), 'כ');
      expect(Gematriya.forNumber(21), 'כא');
      expect(Gematriya.forNumber(99), 'צט');
    });

    test('15 and 16 use טו and טז', () {
      expect(Gematriya.forNumber(15), 'טו');
      expect(Gematriya.forNumber(16), 'טז');
    });

    test('hundreds', () {
      expect(Gematriya.forNumber(100), 'ק');
      expect(Gematriya.forNumber(200), 'ר');
      expect(Gematriya.forNumber(300), 'ש');
      expect(Gematriya.forNumber(400), 'ת');
      expect(Gematriya.forNumber(500), 'תק');
      expect(Gematriya.forNumber(800), 'תת');
      expect(Gematriya.forNumber(900), 'תתק');
    });

    test('mixed hundreds + tens + ones', () {
      expect(Gematriya.forNumber(115), 'קטו');
      expect(Gematriya.forNumber(116), 'קטז');
      expect(Gematriya.forNumber(123), 'קכג');
      expect(Gematriya.forNumber(248), 'רמח');
      expect(Gematriya.forNumber(613), 'תריג');
      expect(Gematriya.forNumber(999), 'תתקצט');
    });

    test('rejects out-of-range', () {
      expect(() => Gematriya.forNumber(0), throwsArgumentError);
      expect(() => Gematriya.forNumber(-1), throwsArgumentError);
      expect(() => Gematriya.forNumber(1000), throwsArgumentError);
    });
  });

  group('Gematriya.parse', () {
    test('single letters', () {
      expect(Gematriya.parse('א'), 1);
      expect(Gematriya.parse('י'), 10);
      expect(Gematriya.parse('ק'), 100);
    });

    test('combinations', () {
      expect(Gematriya.parse('יא'), 11);
      expect(Gematriya.parse('טו'), 15);
      expect(Gematriya.parse('טז'), 16);
      expect(Gematriya.parse('קטו'), 115);
      expect(Gematriya.parse('תריג'), 613);
    });

    test('final letters', () {
      // Final forms have same numeric value as their non-final counterparts.
      expect(Gematriya.parse('ך'), 20);
      expect(Gematriya.parse('ם'), 40);
      expect(Gematriya.parse('ן'), 50);
      expect(Gematriya.parse('ף'), 80);
      expect(Gematriya.parse('ץ'), 90);
    });

    test('strips geresh/gershayim', () {
      expect(Gematriya.parse('א׳'), 1);
      expect(Gematriya.parse('י״א'), 11);
      expect(Gematriya.parse("ק'"), 100);
    });

    test('rejects invalid input', () {
      expect(Gematriya.parse(''), isNull);
      expect(Gematriya.parse('abc'), isNull);
      expect(Gematriya.parse('a'), isNull);
      expect(Gematriya.parse('h'), isNull);
    });
  });

  group('round-trip 1..999', () {
    test('forNumber → parse returns the original', () {
      for (var n = 1; n <= 999; n++) {
        final hebrew = Gematriya.forNumber(n);
        expect(Gematriya.parse(hebrew), n, reason: 'failed for n=$n');
      }
    });
  });
}
