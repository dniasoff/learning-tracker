// Story 1.24 (DNI-486) AC-1: adding a track has no governed tutor path yet
// (the add-track action is an owner batch into the talmid's tree, which the
// rules deny), so a tutor's add-track is refused BEFORE any write — never
// half-applied, never a pending offline write (follow-up
// learning-tracker-fyh.212).

@Tags(['tutor_mode'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/add_track_action_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

class _Actions extends Mock implements AddTrackActionRepository {}

class _Stages extends Mock implements StageDefinitionRepository {}

class _Programs extends Mock implements ProfileProgramRepository {}

class _Bookmarks extends Mock implements BookmarkRepository {}

void main() {
  test('a tutor add-track is refused before ANY write: the governed add-track '
      'action, stages, program and bookmark stay untouched', () async {
    final actions = _Actions();
    final stages = _Stages();
    final programs = _Programs();
    final bookmarks = _Bookmarks();
    final service = TrackCreationService(
      actionRepository: actions,
      wizardService: LearningProcessWizardService(
        stageRepository: stages,
        learningProgramRepo: LearningProgramRepository.instance,
        profileProgramRepository: programs,
      ),
      bookmarkRepository: bookmarks,
      isTutoredSession: () => true,
    );

    await expectLater(
      service.createTrack(
        result: const AddTrackResult(
          curriculumId: CurriculumId.mishnayos,
          label: 'Mishnayos',
          studyDays: {1: 'study'},
        ),
      ),
      throwsA(isA<TutorTrackCreationUnsupportedException>()),
    );

    for (final mock in [actions, stages, programs, bookmarks]) {
      verifyZeroInteractions(mock);
    }
  });
}
