// Extra coverage for GoalEntity — covers DeadlineTarget/PacePeriodTarget
// hashCode/toString, GoalEntity.firestoreId, and GoalEntity.fromFirestore
// with paceGranularity fields.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';

void main() {
  // =========================================================================
  // DeadlineTarget
  // =========================================================================

  group('DeadlineTarget', () {
    final d = DateTime.utc(2026, 6, 1);
    final target = DeadlineTarget(d);

    test('hashCode is consistent', () {
      expect(DeadlineTarget(d).hashCode, DeadlineTarget(d).hashCode);
    });

    test('hashCode differs for different dates', () {
      final other = DeadlineTarget(DateTime.utc(2026, 6, 2));
      expect(target.hashCode, isNot(other.hashCode));
    });

    test('toString includes dueDate', () {
      expect(target.toString(), contains('2026'));
    });

    test('not equal to a non-DeadlineTarget', () {
      expect(target, isNot(equals(42)));
    });
  });

  // =========================================================================
  // PacePeriodTarget
  // =========================================================================

  group('PacePeriodTarget', () {
    const t1 = PacePeriodTarget(rate: 3, period: 'per_week');
    const t2 = PacePeriodTarget(rate: 3, period: 'per_week');
    const t3 = PacePeriodTarget(rate: 5, period: 'per_day');

    test('hashCode is consistent for equal instances', () {
      expect(t1.hashCode, t2.hashCode);
    });

    test('hashCode differs for different values', () {
      expect(t1.hashCode, isNot(t3.hashCode));
    });

    test('toString includes rate and period', () {
      expect(t1.toString(), contains('3'));
      expect(t1.toString(), contains('per_week'));
    });

    test('not equal to a non-PacePeriodTarget', () {
      expect(t1, isNot(equals('per_week')));
    });

    test('not equal when only rate differs', () {
      const different = PacePeriodTarget(rate: 4, period: 'per_week');
      expect(t1, isNot(equals(different)));
    });

    test('not equal when only period differs', () {
      const different = PacePeriodTarget(rate: 3, period: 'per_day');
      expect(t1, isNot(equals(different)));
    });
  });

  // =========================================================================
  // GoalEntity.firestoreId
  // =========================================================================

  group('GoalEntity.firestoreId', () {
    test('firestoreId contains curriculum storageKey', () {
      final entity = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(entity.firestoreId, contains('mishnayos'));
    });

    test('firestoreId contains targetPercent', () {
      final entity = GoalEntity(
        curriculumId: CurriculumId.bavli,
        targetPercent: 75.0,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      expect(entity.firestoreId, contains('75.0'));
    });

    test('firestoreId contains createdAt timestamp', () {
      final created = DateTime.utc(2026, 3, 15, 12, 0, 0);
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
      final e1 = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final e2 = GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      expect(e1.firestoreId, isNot(e2.firestoreId));
    });
  });

  // =========================================================================
  // GoalEntity.fromFirestore — paceGranularity
  // =========================================================================

  group('GoalEntity.fromFirestore — paceGranularity', () {
    test('maps paceGranularity perek to enum', () {
      final entity = GoalEntity.fromFirestore({
        'curriculumId': 'mishnayos',
        'paceGranularity': 'perek',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(entity.paceGranularity, PaceGranularity.perek);
      expect(entity.rawLearningUnit, isNull);
    });

    test('maps unknown paceGranularity to rawLearningUnit', () {
      final entity = GoalEntity.fromFirestore({
        'curriculumId': 'bavli',
        'paceGranularity': 'amud',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(entity.paceGranularity, isNull);
      expect(entity.rawLearningUnit, 'amud');
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

    test('fromFirestore throws for unknown curriculumId', () {
      expect(
        () => GoalEntity.fromFirestore({
          'curriculumId': 'unknown_curriculum_xyz',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        }),
        throwsArgumentError,
      );
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
  });

  // =========================================================================
  // GoalEntity.paceTarget edge cases
  // =========================================================================

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
