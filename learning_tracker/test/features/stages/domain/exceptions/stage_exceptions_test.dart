// Tests for StageLimitExceededException and ProtectedStageException —
// covers userMessage and toString (lines 7-11 and 5-8).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/protected_stage_exception.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/stage_limit_exceeded_exception.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/stages/domain/services/stage_validator.dart';

void main() {
  // =========================================================================
  // StageLimitExceededException
  // =========================================================================

  group('StageLimitExceededException', () {
    test('userMessage includes maxStages', () {
      const ex = StageLimitExceededException(maxStages: 10);
      expect(ex.userMessage, contains('10'));
    });

    test('toString includes StageLimitExceededException prefix', () {
      const ex = StageLimitExceededException(maxStages: 5);
      expect(ex.toString(), contains('StageLimitExceededException'));
      expect(ex.toString(), contains('5'));
    });
  });

  // =========================================================================
  // ProtectedStageException
  // =========================================================================

  group('ProtectedStageException', () {
    test('userMessage mentions Learn stage', () {
      const ex = ProtectedStageException();
      expect(ex.userMessage, contains('Learn'));
    });

    test('toString includes ProtectedStageException prefix', () {
      const ex = ProtectedStageException();
      expect(ex.toString(), contains('ProtectedStageException'));
    });
  });

  // =========================================================================
  // StageValidator — uncovered lines: invalid daysOfWeek value (line 20)
  // =========================================================================

  group('StageValidator', () {
    test('returns null for delay schedule', () {
      const stage = StageDefinition(
        id: 1,
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 1,
        stageName: 'Learn',
        delayDays: 0,
        isDefault: true,
        scheduleType: ScheduleType.delay,
      );
      expect(StageValidator.validate(stage), isNull);
    });

    test('returns error for weekly stage with out-of-range day', () {
      const stage = StageDefinition(
        id: 2,
        curriculumId: CurriculumId.mishnayos,
        stageOrder: 2,
        stageName: 'Weekly',
        delayDays: 7,
        isDefault: false,
        scheduleType: ScheduleType.weekly,
        daysOfWeek: [8], // invalid — must be 1-7
      );
      final result = StageValidator.validate(stage);
      expect(result, isNotNull);
      expect(result, contains('8'));
    });
  });
}
