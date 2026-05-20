import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/scope.dart';

void main() {
  group('ScopeLevel', () {
    group('construction', () {
      test('accepts 1', () {
        expect(ScopeLevel(1).value, 1);
      });

      test('accepts 4', () {
        expect(ScopeLevel(4).value, 4);
      });

      test('throws for 0', () {
        expect(() => ScopeLevel(0), throwsArgumentError);
      });

      test('throws for 5', () {
        expect(() => ScopeLevel(5), throwsArgumentError);
      });
    });

    group('equality', () {
      test('equal for same value', () {
        expect(ScopeLevel(2), equals(ScopeLevel(2)));
      });

      test('not equal for different values', () {
        expect(ScopeLevel(1), isNot(equals(ScopeLevel(2))));
      });

      test('hashCode consistent with equality', () {
        expect(ScopeLevel(3).hashCode, equals(ScopeLevel(3).hashCode));
      });
    });
  });

  group('ScopeValue', () {
    group('construction', () {
      test('accepts non-empty string', () {
        expect(ScopeValue('Berakhot').value, 'Berakhot');
      });

      test('trims surrounding whitespace', () {
        expect(ScopeValue('  Chullin  ').value, 'Chullin');
      });

      test('throws for empty string', () {
        expect(() => ScopeValue(''), throwsArgumentError);
      });

      test('throws for whitespace-only string', () {
        expect(() => ScopeValue('   '), throwsArgumentError);
      });
    });

    group('equality', () {
      test('equal for same value', () {
        expect(ScopeValue('Berakhot'), equals(ScopeValue('Berakhot')));
      });

      test('not equal for different values', () {
        expect(ScopeValue('Berakhot'), isNot(equals(ScopeValue('Shabbat'))));
      });
    });
  });

  group('CurriculumScope', () {
    group('construction', () {
      test('constructs from typed arguments', () {
        final scope = CurriculumScope(
          level: ScopeLevel(2),
          scopeValue: ScopeValue('Berakhot'),
        );
        expect(scope.level.value, 2);
        expect(scope.scopeValue.value, 'Berakhot');
      });

      test('fromRaw convenience constructor', () {
        final scope = CurriculumScope.fromRaw(rawLevel: 1, rawValue: 'Moed');
        expect(scope.level.value, 1);
        expect(scope.scopeValue.value, 'Moed');
      });

      test('fromRaw throws for invalid level', () {
        expect(
          () => CurriculumScope.fromRaw(rawLevel: 0, rawValue: 'Moed'),
          throwsArgumentError,
        );
      });

      test('fromRaw throws for empty value', () {
        expect(
          () => CurriculumScope.fromRaw(rawLevel: 1, rawValue: ''),
          throwsArgumentError,
        );
      });
    });

    group('equality', () {
      test('equal when level and value match', () {
        final a = CurriculumScope.fromRaw(rawLevel: 2, rawValue: 'Berakhot');
        final b = CurriculumScope.fromRaw(rawLevel: 2, rawValue: 'Berakhot');
        expect(a, equals(b));
      });

      test('not equal when value differs', () {
        final a = CurriculumScope.fromRaw(rawLevel: 2, rawValue: 'Berakhot');
        final b = CurriculumScope.fromRaw(rawLevel: 2, rawValue: 'Shabbat');
        expect(a, isNot(equals(b)));
      });

      test('not equal when level differs', () {
        final a = CurriculumScope.fromRaw(rawLevel: 1, rawValue: 'Berakhot');
        final b = CurriculumScope.fromRaw(rawLevel: 2, rawValue: 'Berakhot');
        expect(a, isNot(equals(b)));
      });

      test('hashCode consistent with equality', () {
        final a = CurriculumScope.fromRaw(rawLevel: 3, rawValue: 'Perek 1');
        final b = CurriculumScope.fromRaw(rawLevel: 3, rawValue: 'Perek 1');
        expect(a.hashCode, equals(b.hashCode));
      });

      test('usable in Set', () {
        final set = {
          CurriculumScope.fromRaw(rawLevel: 1, rawValue: 'Zeraim'),
          CurriculumScope.fromRaw(rawLevel: 1, rawValue: 'Zeraim'),
          CurriculumScope.fromRaw(rawLevel: 1, rawValue: 'Moed'),
        };
        expect(set.length, 2);
      });
    });

    test('toString is descriptive', () {
      final scope = CurriculumScope.fromRaw(rawLevel: 2, rawValue: 'Berakhot');
      expect(scope.toString(), contains('2'));
      expect(scope.toString(), contains('Berakhot'));
    });
  });
}
