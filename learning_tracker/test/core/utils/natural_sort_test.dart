import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/utils/natural_sort.dart';

void main() {
  group('compareNaturalString', () {
    test('numeric runs compared numerically — "1:2" sorts before "1:10"', () {
      expect(
        compareNaturalString('Mishnah Berakhot 1:2', 'Mishnah Berakhot 1:10'),
        lessThan(0),
      );
      expect(
        compareNaturalString('Mishnah Berakhot 1:10', 'Mishnah Berakhot 1:2'),
        greaterThan(0),
      );
    });

    test('mixed alpha-numeric — lex on alpha, numeric on digits', () {
      final inputs = ['Perek 10', 'Perek 2', 'Perek 1', 'Perek 11']
        ..sort(compareNaturalString);
      expect(inputs, ['Perek 1', 'Perek 2', 'Perek 10', 'Perek 11']);
    });

    test('equal strings return 0', () {
      expect(
        compareNaturalString('Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:1'),
        0,
      );
    });

    test('empty strings are equal', () {
      expect(compareNaturalString('', ''), 0);
    });

    test('empty vs non-empty — empty sorts first', () {
      expect(compareNaturalString('', 'a'), lessThan(0));
      expect(compareNaturalString('a', ''), greaterThan(0));
    });

    test('different curricula sort by leading alpha', () {
      expect(
        compareNaturalString('Mishnah Berakhot 1:1', 'Talmud Berakhot 1:1'),
        lessThan(0),
      );
    });

    test('multi-digit ranges sort correctly across boundaries', () {
      final input = ['Daf 99a', 'Daf 100a', 'Daf 9a', 'Daf 10a']
        ..sort(compareNaturalString);
      expect(input, ['Daf 9a', 'Daf 10a', 'Daf 99a', 'Daf 100a']);
    });
  });
}
