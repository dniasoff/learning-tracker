/// Unit tests for the shared strict-codec helpers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

import '../../helpers/learner_state_fixtures.dart';

void main() {
  group('isUlid', () {
    test('accepts 26-char Crockford, case-insensitive', () {
      expect(isUlid(ulidA), isTrue);
      expect(isUlid(ulidA.toLowerCase()), isTrue);
    });
    test('rejects wrong length and excluded letters (I, L, O, U)', () {
      expect(isUlid(''), isFalse);
      expect(isUlid(ulidA.substring(1)), isFalse);
      expect(isUlid('01ARZ3NDEKTSV4RRFFQ69G5FAI'), isFalse);
      expect(isUlid('01ARZ3NDEKTSV4RRFFQ69G5FAU'), isFalse);
    });
  });

  group('isCivilDate', () {
    test('valid dates', () {
      expect(isCivilDate('2026-09-01'), isTrue);
      expect(isCivilDate('2024-02-29'), isTrue);
      expect(isCivilDate('2026-12-31'), isTrue);
    });
    test('pattern or calendar violations', () {
      for (final bad in [
        '2026-9-01',
        '2026-09-1',
        '2026-02-29',
        '2026-04-31',
        '2026-00-01',
        '2026-01-00',
        ' 2026-01-01',
      ]) {
        expect(isCivilDate(bad), isFalse, reason: bad);
      }
    });
  });

  group('StorageReader', () {
    test('required: missing key vs wrong type vs ok', () {
      final r = StorageReader('T', {'a': 1, 'b': null});
      expect(r.required<int>('a'), 1);
      expect(
        () => r.required<int>('missing'),
        throwsA(isA<StorageFormatException>()),
      );
      expect(
        () => r.required<int>('b'),
        throwsA(isA<StorageFormatException>()),
      );
      expect(
        () => r.required<String>('a'),
        throwsA(isA<StorageFormatException>()),
      );
    });

    test('optional: absent and explicit null both read as null', () {
      final r = StorageReader('T', {'b': null});
      expect(r.optional<int>('a'), isNull);
      expect(r.optional<int>('b'), isNull);
    });

    test('requiredNullable: key must exist, value may be null', () {
      final r = StorageReader('T', {'b': null});
      expect(r.requiredNullable<String>('b'), isNull);
      expect(
        () => r.requiredNullable<String>('a'),
        throwsA(isA<StorageFormatException>()),
      );
    });

    test('requireOnly names the unknown key', () {
      final r = StorageReader('T', {'a': 1, 'zz': 2});
      expect(
        () => r.requireOnly({'a'}),
        throwsA(
          isA<StorageFormatException>().having((e) => e.field, 'field', 'zz'),
        ),
      );
    });

    test('requiredNumber widens int to double; instants come back UTC', () {
      final r = StorageReader('T', {'n': 3, 't': t0.toLocal()});
      expect(r.requiredNumber('n'), 3.0);
      expect(r.requiredInstant('t').isUtc, isTrue);
      expect(r.requiredInstant('t'), t0);
    });

    test('enum and ULID readers reject invalid values', () {
      final r = StorageReader('T', {'e': 'x', 'u': 'nope'});
      expect(
        () => r.requiredEnum('e', const {'y': 1}),
        throwsA(isA<StorageFormatException>()),
      );
      expect(() => r.requiredUlid('u'), throwsA(isA<StorageFormatException>()));
      expect(() => r.optionalUlid('u'), throwsA(isA<StorageFormatException>()));
    });

    test('requiredMap rejects non-string keys', () {
      final r = StorageReader('T', {
        'm': {1: 'x'},
      });
      expect(() => r.requiredMap('m'), throwsA(isA<StorageFormatException>()));
    });
  });

  test('storageValueEquals / storageValueHash are deep and order-free', () {
    final a = {
      'x': [
        1,
        {'y': t0},
      ],
      'z': null,
    };
    final b = {
      'z': null,
      'x': [
        1,
        {'y': t0},
      ],
    };
    expect(storageValueEquals(a, b), isTrue);
    expect(storageValueHash(a), storageValueHash(b));
    expect(
      storageValueEquals(a, {
        'x': [1],
        'z': null,
      }),
      isFalse,
    );
  });

  group('freezeStorageValue', () {
    test('deep-copies maps and lists into unmodifiable snapshots', () {
      final instant = DateTime.utc(2026, 3, 1);
      final nested = <String, Object?>{'id': 's1', 'at': instant};
      final list = <Object?>[nested, 1];
      final raw = <Object?, Object?>{'k': 'v'};
      final source = <String, Object?>{'list': list, 'raw': raw, 'n': 2};

      final frozen = freezeStorageMap(source);
      nested['id'] = 'tampered';
      list.add('extra');
      raw['k'] = 'changed';
      source['n'] = 3;

      expect(frozen, {
        'list': [
          {'id': 's1', 'at': instant},
          1,
        ],
        'raw': {'k': 'v'},
        'n': 2,
      });
      expect(() => frozen['n'] = 4, throwsUnsupportedError);
      final frozenList = frozen['list']! as List<Object?>;
      expect(() => frozenList.add(0), throwsUnsupportedError);
      expect(
        () => (frozenList.first! as Map<String, Object?>)['id'] = 'x',
        throwsUnsupportedError,
      );
      expect(
        () => (frozen['raw']! as Map<Object?, Object?>)['k'] = 'x',
        throwsUnsupportedError,
      );
    });

    test('keeps primitives and instants as is', () {
      final instant = DateTime.utc(2026);
      expect(freezeStorageValue(null), isNull);
      expect(freezeStorageValue('s'), 's');
      expect(identical(freezeStorageValue(instant), instant), isTrue);
    });
  });

  test('StorageFormatException carries type/field/reason, no data', () {
    const e = StorageFormatException('T', 'f', 'why');
    expect(e.toString(), 'StorageFormatException(T.f): why');
  });
}
