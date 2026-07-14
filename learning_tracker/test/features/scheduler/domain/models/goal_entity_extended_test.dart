/// Extended tests for GoalEntity covering branches not exercised by
/// goal_entity_test.dart:
/// - DeadlineTarget.hashCode and toString
/// - PacePeriodTarget.hashCode, toString and equality
/// - GoalEntity.firestoreId
/// - GoalEntity.fromFirestore error path (unknown curriculumId) and
///   paceGranularity mapping (including the null and round-trip cases)
/// - GoalEntity.paceTarget edge cases
///
/// AUD-t-scheduler-01: this file absorbs the union of distinct assertions
/// formerly split across this file and the now-deleted
/// goal_entity_extra_test.dart, which duplicated most of the
/// DeadlineTarget/PacePeriodTarget/firestoreId/fromFirestore coverage below
/// under the same group names.
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:test/test.dart';

void main() {
  // ── DeadlineTarget ─────────────────────────────────────────────────────────

  group('DeadlineTarget', () {
    test('hashCode is stable for the same dueDate', () {
      final d = DateTime.utc(2026, 6, 1);
      final a = DeadlineTarget(d);
      final b = DeadlineTarget(d);
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode differs for different dueDates', () {
      final a = DeadlineTarget(DateTime.utc(2026, 6, 1));
      final b = DeadlineTarget(DateTime.utc(2026, 7, 1));
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('toString contains dueDate', () {
      final d = DateTime.utc(2026, 6, 1);
      final target = DeadlineTarget(d);
      expect(target.toString(), contains('DeadlineTarget'));
      expect(target.toString(), contains('dueDate'));
    });

    test('equality returns false for non-DeadlineTarget', () {
      final d = DateTime.utc(2026, 6, 1);
      final target = DeadlineTarget(d);
      // ignore: unrelated_type_equality_checks
      expect(target == 'not a target', isFalse);
    });

    test('identical objects are equal', () {
      final d = DateTime.utc(2026, 6, 1);
      final target = DeadlineTarget(d);
      // ignore: unrelated_type_equality_checks
      expect(target == target, isTrue);
    });
  });

  // ── PacePeriodTarget ───────────────────────────────────────────────────────

  group('PacePeriodTarget', () {
    test('hashCode is stable for the same rate and period', () {
      const a = PacePeriodTarget(rate: 2, period: 'per_week');
      const b = PacePeriodTarget(rate: 2, period: 'per_week');
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode differs for different rates', () {
      const a = PacePeriodTarget(rate: 1, period: 'per_day');
      const b = PacePeriodTarget(rate: 2, period: 'per_day');
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('hashCode differs for different periods', () {
      const a = PacePeriodTarget(rate: 1, period: 'per_day');
      const b = PacePeriodTarget(rate: 1, period: 'per_week');
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('toString contains rate and period', () {
      const target = PacePeriodTarget(rate: 3, period: 'per_week');
      expect(target.toString(), contains('PacePeriodTarget'));
      expect(target.toString(), contains('rate'));
      expect(target.toString(), contains('period'));
    });

    test('equality returns false for non-PacePeriodTarget', () {
      const target = PacePeriodTarget(rate: 1, period: 'per_day');
      // ignore: unrelated_type_equality_checks
      expect(target == 'other', isFalse);
    });

    test('identical objects are equal', () {
      const target = PacePeriodTarget(rate: 1, period: 'per_day');
      // ignore: unrelated_type_equality_checks
      expect(target == target, isTrue);
    });

    test('not equal when only rate differs', () {
      const a = PacePeriodTarget(rate: 3, period: 'per_week');
      const b = PacePeriodTarget(rate: 4, period: 'per_week');
      expect(a, isNot(equals(b)));
    });

    test('not equal when only period differs', () {
      const a = PacePeriodTarget(rate: 3, period: 'per_week');
      const b = PacePeriodTarget(rate: 3, period: 'per_day');
      expect(a, isNot(equals(b)));
    });
  });

  // ── GoalEntity.firestoreId ─────────────────────────────────────────────────

  group('GoalEntity.firestoreId', () {
    test('firestoreId contains curriculumId storageKey', () {
      final entity = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100.0,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(entity.firestoreId, contains(CurriculumId.mishnayos.storageKey));
    });

    test('firestoreId contains targetPercent formatted to 1 decimal', () {
      final entity = GoalEntity(
        curriculumId: CurriculumId.bavli,
        targetPercent: 75.5,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(entity.firestoreId, contains('75.5'));
    });

    test('firestoreId contains createdAt millisecondsSinceEpoch', () {
      final created = DateTime.utc(2026, 3, 15, 10, 30);
      final entity = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        createdAt: created,
        updatedAt: created,
      );
      expect(
        entity.firestoreId,
        contains(created.millisecondsSinceEpoch.toString()),
      );
    });

    test('two goals with different createdAt have different firestoreIds', () {
      final a = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final b = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        createdAt: DateTime.utc(2026, 2, 1),
        updatedAt: DateTime.utc(2026, 2, 1),
      );
      expect(a.firestoreId, isNot(b.firestoreId));
    });

    test('firestoreId format is curriculum_percent_epoch', () {
      final created = DateTime.utc(2026, 1, 1);
      final entity = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        targetPercent: 100.0,
        createdAt: created,
        updatedAt: created,
      );
      final id = entity.firestoreId;
      final parts = id.split('_');
      // curriculum | percent | epoch (epoch may have underscores too in long numbers)
      expect(parts.length, greaterThanOrEqualTo(3));
      expect(parts.first, CurriculumId.mishnayos.storageKey);
    });
  });

  // ── GoalEntity.fromFirestore error path ────────────────────────────────────

  group('GoalEntity.fromFirestore', () {
    test('throws ArgumentError for unknown curriculumId', () {
      expect(
        () => GoalEntity.fromFirestore({
          'curriculumId': 'unknown_curriculum_xyz',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        }),
        throwsArgumentError,
      );
    });

    test('preserves rawLearningUnit for unknown granularity keys', () {
      final entity = GoalEntity.fromFirestore({
        'curriculumId': 'mishnayos',
        'paceGranularity': 'amud', // not in PaceGranularity enum
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(entity.paceGranularity, isNull);
      expect(entity.rawLearningUnit, 'amud');
    });

    test('sets paceGranularity for known granularity keys', () {
      final entity = GoalEntity.fromFirestore({
        'curriculumId': 'mishnayos',
        'paceGranularity': 'perek',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(entity.paceGranularity, PaceGranularity.perek);
      expect(entity.rawLearningUnit, isNull);
    });

    test('null paceGranularity produces null enum and rawLearningUnit', () {
      final entity = GoalEntity.fromFirestore({
        'curriculumId': 'mishnayos',
        'paceGranularity': null,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(entity.paceGranularity, isNull);
      expect(entity.rawLearningUnit, isNull);
    });

    test('round-trip preserves paceGranularity daf', () {
      final original = GoalEntity(
        curriculumId: CurriculumId.bavli,
        goalType: 'pace',
        paceValue: 2,
        pacePeriod: 'per_day',
        paceGranularity: PaceGranularity.daf,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final map = original.toFirestore();
      final restored = GoalEntity.fromFirestore(map);
      expect(restored.paceGranularity, PaceGranularity.daf);
      expect(restored.paceGranularityKey, 'daf');
    });

    test('defaults targetPercent to 100.0 when missing', () {
      final entity = GoalEntity.fromFirestore({
        'curriculumId': 'mishnayos',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(entity.targetPercent, 100.0);
    });

    test('parses targetDate when present', () {
      final entity = GoalEntity.fromFirestore({
        'curriculumId': 'mishnayos',
        'targetDate': '2026-12-31T00:00:00.000Z',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(entity.targetDate, isNotNull);
      expect(entity.targetDate!.year, 2026);
      expect(entity.targetDate!.month, 12);
    });

    test('targetDate is null when not present in map', () {
      final entity = GoalEntity.fromFirestore({
        'curriculumId': 'mishnayos',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(entity.targetDate, isNull);
    });
  });

  // ── GoalEntity.paceTarget edge cases ───────────────────────────────────────

  group('GoalEntity.paceTarget edge cases', () {
    test('returns null for deadline type without targetDate', () {
      final entity = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        goalType: 'deadline',
        // targetDate intentionally absent
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(entity.paceTarget, isNull);
    });

    test('returns null for pace type without paceValue', () {
      final entity = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        goalType: 'pace',
        pacePeriod: 'per_day',
        // paceValue intentionally absent
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(entity.paceTarget, isNull);
    });

    test('returns null for pace type without pacePeriod', () {
      final entity = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        goalType: 'pace',
        paceValue: 5,
        // pacePeriod intentionally absent
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(entity.paceTarget, isNull);
    });
  });
}
