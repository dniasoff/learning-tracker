import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:test/test.dart';

void main() {
  group('PaceGranularity', () {
    test('fromStorageKey returns correct enum for known keys', () {
      expect(PaceGranularity.fromStorageKey('perek'), PaceGranularity.perek);
      expect(PaceGranularity.fromStorageKey('daf'), PaceGranularity.daf);
      expect(PaceGranularity.fromStorageKey('seif'), PaceGranularity.seif);
    });

    test('fromStorageKey returns null for unknown keys', () {
      expect(PaceGranularity.fromStorageKey('amud'), isNull);
      expect(PaceGranularity.fromStorageKey('pasuk'), isNull);
      expect(PaceGranularity.fromStorageKey(null), isNull);
    });

    test('storageKey round-trips correctly', () {
      for (final v in PaceGranularity.values) {
        expect(PaceGranularity.fromStorageKey(v.storageKey), v);
      }
    });
  });

  group('PaceTarget', () {
    test('DeadlineTarget holds dueDate', () {
      final date = DateTime.utc(2026, 12, 31);
      final target = DeadlineTarget(date);
      expect(target.dueDate, date);
    });

    test('PacePeriodTarget holds rate and period', () {
      const target = PacePeriodTarget(rate: 3, period: 'per_week');
      expect(target.rate, 3);
      expect(target.period, 'per_week');
    });

    test('DeadlineTarget equality', () {
      final d = DateTime.utc(2026, 6, 1);
      expect(DeadlineTarget(d), DeadlineTarget(d));
    });

    test('PacePeriodTarget equality', () {
      expect(
        const PacePeriodTarget(rate: 1, period: 'per_day'),
        const PacePeriodTarget(rate: 1, period: 'per_day'),
      );
    });
  });

  group('GoalEntity', () {
    group('paceTarget computed getter', () {
      test('returns DeadlineTarget for deadline goal with date', () {
        final date = DateTime.utc(2026, 12, 31);
        final entity = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          goalType: 'deadline',
          targetDate: date,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        expect(entity.paceTarget, isA<DeadlineTarget>());
        expect((entity.paceTarget! as DeadlineTarget).dueDate, date);
      });

      test('returns PacePeriodTarget for pace goal', () {
        final entity = GoalEntity(
          curriculumId: CurriculumId.bavli,
          goalType: 'pace',
          paceValue: 2,
          pacePeriod: 'per_week',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        expect(entity.paceTarget, isA<PacePeriodTarget>());
        final pt = entity.paceTarget! as PacePeriodTarget;
        expect(pt.rate, 2);
        expect(pt.period, 'per_week');
      });

      test('returns null for none goal type', () {
        final entity = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          goalType: 'none',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        expect(entity.paceTarget, isNull);
      });
    });

    group('paceGranularity getter', () {
      test('returns paceGranularity storageKey when set', () {
        final entity = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          paceGranularity: PaceGranularity.perek,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        expect(entity.paceGranularityKey, 'perek');
      });

      test('falls back to rawLearningUnit for non-enum keys', () {
        final entity = GoalEntity(
          curriculumId: CurriculumId.bavli,
          rawLearningUnit: 'amud',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        expect(entity.paceGranularityKey, 'amud');
      });

      test('returns null when neither field is set', () {
        final entity = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        expect(entity.paceGranularityKey, isNull);
      });
    });
  });

  group('GoalEntity (existing tests)', () {
    group('toFirestore', () {
      test('includes pace fields for pace goal', () {
        final entity = GoalEntity(
          curriculumId: CurriculumId.bavli,
          goalType: 'pace',
          paceValue: 1,
          pacePeriod: 'per_day',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        final map = entity.toFirestore();
        expect(map['goal_type'], 'pace');
        expect(map['pace_value'], 1);
        expect(map['pace_unit'], 'per_day');
        expect(map['target_date'], isNull);
      });

      test('includes deadline defaults for deadline goal', () {
        final entity = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          targetDate: DateTime.utc(2026, 6, 1),
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        final map = entity.toFirestore();
        expect(map['goal_type'], 'deadline');
        expect(map['pace_value'], isNull);
        expect(map['pace_unit'], isNull);
        expect(map['target_date'], isNotNull);
      });

      test('per_week pace unit is preserved', () {
        final entity = GoalEntity(
          curriculumId: CurriculumId.bavli,
          goalType: 'pace',
          paceValue: 5,
          pacePeriod: 'per_week',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        final map = entity.toFirestore();
        expect(map['pace_unit'], 'per_week');
        expect(map['pace_value'], 5);
      });
    });

    group('fromFirestore', () {
      test('defaults goalType to deadline when missing', () {
        final entity = GoalEntity.fromFirestore({
          'curriculumId': 'mishnayos',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        });
        expect(entity.goalType, 'deadline');
        expect(entity.paceValue, isNull);
        expect(entity.pacePeriod, isNull);
      });

      test('parses pace fields correctly', () {
        final entity = GoalEntity.fromFirestore({
          'curriculumId': 'bavli',
          'goalType': 'pace',
          'paceValue': 1,
          'pacePeriod': 'per_day',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        });
        expect(entity.goalType, 'pace');
        expect(entity.paceValue, 1);
        expect(entity.pacePeriod, 'per_day');
      });

      test('round-trip preserves all fields', () {
        final original = GoalEntity(
          curriculumId: CurriculumId.bavli,
          goalType: 'pace',
          paceValue: 3,
          pacePeriod: 'per_week',
          targetPercent: 80.0,
          description: 'test goal',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        final map = original.toFirestore();
        final restored = GoalEntity.fromFirestore(map);
        expect(restored.goalType, original.goalType);
        expect(restored.paceValue, original.paceValue);
        expect(restored.pacePeriod, original.pacePeriod);
        expect(restored.targetPercent, original.targetPercent);
        expect(restored.description, original.description);
      });
    });
  });
}
