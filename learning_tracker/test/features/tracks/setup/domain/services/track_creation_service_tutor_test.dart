// Story 1.24 (DNI-486) AC-1: adding a track has no governed tutor path yet
// (the track doc, stage set, scopes, program and activation are client
// writes into the talmid's tree, which the rules deny), so a tutor's
// add-track is refused BEFORE any write — never half-applied, never a
// pending offline write (follow-up learning-tracker-fyh.212).

@Tags(['tutor_mode'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/curriculum_scope_write_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/study_day_write_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

class _Activation extends Mock implements CurriculumActivationService {}

class _Tracks extends Mock
    implements FirestoreCurriculumTrackRepositoryAdapter {}

class _Stages extends Mock implements StageDefinitionRepository {}

class _Goals extends Mock implements GoalRepository {}

class _StudyDays extends Mock implements StudyDayWriteRepository {}

class _Scopes extends Mock implements CurriculumScopeWriteRepository {}

class _Programs extends Mock implements ProfileProgramRepository {}

class _Bookmarks extends Mock implements BookmarkRepository {}

void main() {
  test(
    'a tutor add-track is refused before ANY write: track, stages, study '
    'days, scopes, goal, program, bookmark and activation stay untouched',
    () async {
      final activation = _Activation();
      final tracks = _Tracks();
      final stages = _Stages();
      final goals = _Goals();
      final studyDays = _StudyDays();
      final scopes = _Scopes();
      final programs = _Programs();
      final bookmarks = _Bookmarks();
      final service = TrackCreationService(
        activationService: activation,
        wizardService: LearningProcessWizardService(
          stageRepository: stages,
          learningProgramRepo: LearningProgramRepository.instance,
          profileProgramRepository: programs,
        ),
        goalRepository: goals,
        trackRepository: tracks,
        studyDayRepository: studyDays,
        scopeRepository: scopes,
        profileProgramRepository: programs,
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

      for (final mock in [
        activation,
        tracks,
        stages,
        goals,
        studyDays,
        scopes,
        programs,
        bookmarks,
      ]) {
        verifyZeroInteractions(mock);
      }
    },
  );
}
