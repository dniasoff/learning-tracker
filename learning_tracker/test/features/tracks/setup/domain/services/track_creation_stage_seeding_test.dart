// A track created without a learning-process wizard result still carries
// the primary לימוד stage (the scheduler skips a stage-less track), inside
// the one Add track action (DNI-476 AC-5).

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/recording_add_track_actions.dart';

class _Stages extends Mock implements StageDefinitionRepository {}

class _Programs extends Mock implements ProfileProgramRepository {}

void main() {
  test('no wizard result seeds exactly the לימוד stage', () async {
    final actions = RecordingAddTrackActions();
    await TrackCreationService(
      actionRepository: actions,
      wizardService: LearningProcessWizardService(
        stageRepository: _Stages(),
        learningProgramRepo: LearningProgramRepository.instance,
        profileProgramRepository: _Programs(),
      ),
    ).createTrack(
      result: const AddTrackResult(
        curriculumId: CurriculumId.mishnayos,
        label: 'Mishnayos',
        studyDays: {1: 'study', 2: 'study'},
      ),
    );

    final stages = actions.plans.single.stages;
    expect(stages, hasLength(1));
    expect(stages.single.stageName, 'לימוד');
    expect(stages.single.curriculumId, CurriculumId.mishnayos);
  });
}
