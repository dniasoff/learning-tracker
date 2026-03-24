import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:test/test.dart';

void main() {
  group('GoalEntity', () {
    group('toFirestore', () {
      test('includes pace fields for pace goal', () {
        final entity = GoalEntity(
          curriculumId: CurriculumId.bavli,
          goalType: 'pace',
          paceValue: 1,
          paceUnit: 'per_day',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        final map = entity.toFirestore();
        expect(map['goalType'], 'pace');
        expect(map['paceValue'], 1);
        expect(map['paceUnit'], 'per_day');
        expect(map['targetDate'], isNull);
      });

      test('includes deadline defaults for deadline goal', () {
        final entity = GoalEntity(
          curriculumId: CurriculumId.mishnayos,
          targetDate: DateTime.utc(2026, 6, 1),
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        final map = entity.toFirestore();
        expect(map['goalType'], 'deadline');
        expect(map['paceValue'], isNull);
        expect(map['paceUnit'], isNull);
        expect(map['targetDate'], isNotNull);
      });

      test('per_week pace unit is preserved', () {
        final entity = GoalEntity(
          curriculumId: CurriculumId.bavli,
          goalType: 'pace',
          paceValue: 5,
          paceUnit: 'per_week',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        final map = entity.toFirestore();
        expect(map['paceUnit'], 'per_week');
        expect(map['paceValue'], 5);
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
        expect(entity.paceUnit, isNull);
      });

      test('parses pace fields correctly', () {
        final entity = GoalEntity.fromFirestore({
          'curriculumId': 'bavli',
          'goalType': 'pace',
          'paceValue': 1,
          'paceUnit': 'per_day',
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        });
        expect(entity.goalType, 'pace');
        expect(entity.paceValue, 1);
        expect(entity.paceUnit, 'per_day');
      });

      test('round-trip preserves all fields', () {
        final original = GoalEntity(
          curriculumId: CurriculumId.bavli,
          goalType: 'pace',
          paceValue: 3,
          paceUnit: 'per_week',
          targetPercent: 80.0,
          description: 'test goal',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        final map = original.toFirestore();
        final restored = GoalEntity.fromFirestore(map);
        expect(restored.goalType, original.goalType);
        expect(restored.paceValue, original.paceValue);
        expect(restored.paceUnit, original.paceUnit);
        expect(restored.targetPercent, original.targetPercent);
        expect(restored.description, original.description);
      });
    });
  });
}
