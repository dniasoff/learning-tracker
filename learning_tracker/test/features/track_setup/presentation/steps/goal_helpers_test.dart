/// Tests for pure-logic utilities in goal_helpers.dart.
///
/// Covers:
///  - [countStudyDaysInInclusiveMapRange]
///  - [localDateOnlyFromDt]
///  - [paceUnitOptionsFor] — all 9 curricula
///  - [PaceUnitOptions] — dual / single / hasChoice / levelFor
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/goal_helpers.dart';

void main() {
  // ─── countStudyDaysInInclusiveMapRange ────────────────────────────────────

  group('countStudyDaysInInclusiveMapRange', () {
    // Monday=1 … Sunday=7 in Dart.
    // A week Mon–Sun from 2026-03-09 to 2026-03-15.
    final mon = DateTime(2026, 3, 9);
    final sun = DateTime(2026, 3, 15);

    test('counts every day when all 7 days are marked study', () {
      final studyDays = {
        1: 'study',
        2: 'study',
        3: 'study',
        4: 'study',
        5: 'study',
        6: 'study',
        7: 'study',
      };
      expect(countStudyDaysInInclusiveMapRange(studyDays, mon, sun), 7);
    });

    test('counts only weekdays when Shabbat is off (6=Saturday off)', () {
      final studyDays = {
        1: 'study',
        2: 'study',
        3: 'study',
        4: 'study',
        5: 'study',
        6: 'off',
        7: 'study',
      };
      // Mon–Fri + Sun = 6 days
      expect(countStudyDaysInInclusiveMapRange(studyDays, mon, sun), 6);
    });

    test('returns 0 when start is after end', () {
      final studyDays = {1: 'study'};
      expect(countStudyDaysInInclusiveMapRange(studyDays, sun, mon), 0);
    });

    test('returns 1 for same-day range on a study day', () {
      final wednesday = DateTime(2026, 3, 11); // weekday = 3
      final studyDays = {3: 'study'};
      expect(
        countStudyDaysInInclusiveMapRange(studyDays, wednesday, wednesday),
        1,
      );
    });

    test(
      'returns 1 for same-day range on non-study day when only off entry present',
      () {
        // studyDays = {3: 'off'} means no 'study' entries; studyWeekdays is empty
        // so the code falls back to all 7 days and the Wednesday IS counted.
        final wednesday = DateTime(2026, 3, 11); // weekday = 3
        final studyDays = {3: 'off'};
        expect(
          countStudyDaysInInclusiveMapRange(studyDays, wednesday, wednesday),
          1,
        );
      },
    );

    test('falls back to all 7 days when no study entries exist', () {
      // Both empty map and all-off map result in "all days" fallback.
      expect(countStudyDaysInInclusiveMapRange({}, mon, sun), 7);
    });

    test('counts correctly across a month boundary', () {
      // Jan 30 (Fri) to Feb 2 (Mon): 4 days, all study.
      final start = DateTime(2026, 1, 30); // Friday
      final end = DateTime(2026, 2, 2); // Monday
      final allStudy = {
        1: 'study',
        2: 'study',
        3: 'study',
        4: 'study',
        5: 'study',
        6: 'study',
        7: 'study',
      };
      expect(countStudyDaysInInclusiveMapRange(allStudy, start, end), 4);
    });

    test(
      'all-off map falls back to all 7 study days (no study entries means fallback)',
      () {
        // When all entries are 'off', studyWeekdays set is empty, so fallback to all 7.
        final allOff = {
          1: 'off',
          2: 'off',
          3: 'off',
          4: 'off',
          5: 'off',
          6: 'off',
          7: 'off',
        };
        expect(countStudyDaysInInclusiveMapRange(allOff, mon, sun), 7);
      },
    );
  });

  // ─── localDateOnlyFromDt ──────────────────────────────────────────────────

  group('localDateOnlyFromDt', () {
    test('strips time component leaving date only', () {
      // Use a local DateTime to avoid timezone issues in this pure logic test.
      final dt = DateTime(2026, 5, 14, 15, 30, 45);
      final result = localDateOnlyFromDt(dt);
      expect(result.year, 2026);
      expect(result.month, 5);
      expect(result.day, 14);
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
    });

    test('returns DateTime with no time part', () {
      final dt = DateTime(2026, 1, 1, 23, 59, 59);
      final result = localDateOnlyFromDt(dt);
      expect(result, DateTime(2026, 1, 1));
    });
  });

  // ─── paceUnitOptionsFor ───────────────────────────────────────────────────

  group('paceUnitOptionsFor', () {
    test('all CurriculumId values return non-null PaceUnitOptions', () {
      for (final id in CurriculumId.values) {
        expect(() => paceUnitOptionsFor(id), returnsNormally);
      }
    });

    test('mishnayos returns dual with perek/mishna', () {
      final opts = paceUnitOptionsFor(CurriculumId.mishnayos);
      expect(opts.coarseKey, 'perek');
      expect(opts.fineKey, 'mishna');
      expect(opts.defaultKey, 'mishna');
      expect(opts.hasChoice, isTrue);
    });

    test('bavli returns dual with daf/amud', () {
      final opts = paceUnitOptionsFor(CurriculumId.bavli);
      expect(opts.coarseKey, 'daf');
      expect(opts.fineKey, 'amud');
      expect(opts.defaultKey, 'daf');
      expect(opts.hasChoice, isTrue);
    });

    test('yerushalmi returns single with daf (no fine choice)', () {
      final opts = paceUnitOptionsFor(CurriculumId.yerushalmi);
      expect(opts.coarseKey, 'daf');
      expect(opts.fineKey, isNull);
      expect(opts.hasChoice, isFalse);
    });

    test('chumash returns dual with perek/pasuk', () {
      final opts = paceUnitOptionsFor(CurriculumId.chumash);
      expect(opts.coarseKey, 'perek');
      expect(opts.fineKey, 'pasuk');
    });

    test('mishnaBerurah returns dual with siman/seif', () {
      final opts = paceUnitOptionsFor(CurriculumId.mishnaBerurah);
      expect(opts.coarseKey, 'siman');
      expect(opts.fineKey, 'seif');
    });

    test('mishnehTorah returns dual with perek/halacha', () {
      final opts = paceUnitOptionsFor(CurriculumId.mishnehTorah);
      expect(opts.coarseKey, 'perek');
      expect(opts.fineKey, 'halacha');
    });

    test('nach returns dual with perek/pasuk', () {
      final opts = paceUnitOptionsFor(CurriculumId.nach);
      expect(opts.coarseKey, 'perek');
      expect(opts.fineKey, 'pasuk');
    });

    test('mussar returns dual with perek/pasuk', () {
      final opts = paceUnitOptionsFor(CurriculumId.mussar);
      expect(opts.coarseKey, 'perek');
      expect(opts.fineKey, 'pasuk');
    });

    test('tanach returns dual with perek/pasuk', () {
      final opts = paceUnitOptionsFor(CurriculumId.tanach);
      expect(opts.coarseKey, 'perek');
      expect(opts.fineKey, 'pasuk');
    });
  });

  // ─── PaceUnitOptions.levelFor ─────────────────────────────────────────────

  group('PaceUnitOptions.levelFor', () {
    test('levelFor coarseKey returns coarse labels', () {
      final opts = paceUnitOptionsFor(CurriculumId.mishnayos);
      final labels = opts.levelFor('perek');
      expect(labels, same(opts.coarse));
    });

    test('levelFor fineKey returns fine labels', () {
      final opts = paceUnitOptionsFor(CurriculumId.mishnayos);
      final labels = opts.levelFor('mishna');
      expect(labels, same(opts.fine));
    });

    test('levelFor unknown key falls back to coarse', () {
      final opts = paceUnitOptionsFor(CurriculumId.mishnayos);
      final labels = opts.levelFor('unknown_key');
      expect(labels, same(opts.coarse));
    });

    test('levelFor on single-mode option always returns coarse', () {
      final opts = paceUnitOptionsFor(CurriculumId.yerushalmi);
      final labels = opts.levelFor('daf');
      expect(labels, same(opts.coarse));
    });
  });
}
