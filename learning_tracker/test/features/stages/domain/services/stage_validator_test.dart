// Tests for StageValidator — covers all three ScheduleType branches.
//
// AUD-tracks-12: this file used to be
// test/features/stages/domain/exceptions/stage_exceptions_test.dart and also
// covered StageLimitExceededException/ProtectedStageException. Those two
// leaf exceptions were deleted as dead code (their only callers were the
// repository's addStage/updateStage/deleteStage/reorderStages methods,
// which were themselves deleted as unreachable from any UI — see
// StageDefinitionRepositoryImpl). StageValidator is kept and moved here
// because — unlike the exceptions — it has independent acceptance coverage
// decoupled from the repository (test/story_acceptance/epic_15_multi_profile_test.dart,
// group "AC: Stage validation -- each type requires its specific fields").
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/services/stage_validator.dart';

void main() {
  // =========================================================================
  // StageValidator — uncovered lines: invalid daysOfWeek value (line 20)
  // =========================================================================

  group('StageValidator', () {
    test('returns null for delay schedule', () {
      const stage = StageDefinition(
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
