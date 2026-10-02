// AUD-tracks-19: creation and editing delegate their study-day/scope writes
// to the Firestore-era repository seams exactly once.

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/study_day_write_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_edit_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/recording_add_track_actions.dart';

class _Stages extends Mock implements StageDefinitionRepository {}

class _Goals extends Mock implements GoalRepository {}

class _Programs extends Mock implements ProfileProgramRepository {}

class _Bookmarks extends Mock implements BookmarkRepository {}

class _StudyDays implements StudyDayWriteRepository {
  Map<int, DayType>? last;

  @override
  Future<void> replaceAllForCurriculum({
    required CurriculumId curriculumId,
    required Map<int, DayType> studyDays,
  }) async {
    last = studyDays;
  }
}

TrackCreationService _creationService(RecordingAddTrackActions actions) =>
    TrackCreationService(
      actionRepository: actions,
      wizardService: LearningProcessWizardService(
        stageRepository: _Stages(),
        learningProgramRepo: LearningProgramRepository.instance,
        profileProgramRepository: _Programs(),
      ),
      bookmarkRepository: _Bookmarks(),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.bavli);
    registerFallbackValue(<int, DayType>{});
    registerFallbackValue(<StageDefinition>[]);
  });

  test('creation carries every supplied study day in its action', () async {
    final actions = RecordingAddTrackActions();
    await _creationService(actions).createTrack(
      result: const AddTrackResult(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        studyDays: {1: 'study', 2: 'rest', 5: 'study'},
      ),
    );

    expect(actions.plans.single.studyDays, {
      1: DayType.study,
      2: DayType.review,
      5: DayType.study,
    });
  });

  test('creation forwards mixed-level scope selections once', () async {
    final actions = RecordingAddTrackActions();
    await _creationService(actions).createTrack(
      result: const AddTrackResult(
        curriculumId: CurriculumId.mishnayos,
        label: 'Mishnayos',
        studyDays: {1: 'study'},
        scopeSelections: [
          ScopeEntry(level: 1, value: 'Seder Zeraim'),
          ScopeEntry(level: 2, value: 'Berachos'),
        ],
      ),
    );

    expect(actions.plans.single.scopes, [
      (level: 1, value: 'Seder Zeraim'),
      (level: 2, value: 'Berachos'),
    ]);
  });

  test(
    'creation selects the whole curriculum when selections are omitted',
    () async {
      final actions = RecordingAddTrackActions();
      await _creationService(actions).createTrack(
        result: const AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          studyDays: {1: 'study'},
        ),
      );
      expect(actions.plans.single.scopes, isEmpty);
    },
  );

  test('editing replaces the study-day set through the writer', () async {
    final studyDays = _StudyDays();
    final stageRepository = _Stages();
    final programs = _Programs();
    final service = TrackEditService(
      wizardService: LearningProcessWizardService(
        stageRepository: stageRepository,
        learningProgramRepo: LearningProgramRepository.instance,
        profileProgramRepository: programs,
      ),
      goalRepository: _Goals(),
      studyDayRepository: studyDays,
    );

    await service.editTrack(
      goal: GoalEntity(
        curriculumId: CurriculumId.bavli,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      curriculum: CurriculumId.bavli,
      studyDays: const {3: 'rest'},
    );

    expect(studyDays.last, {3: DayType.review});
  });
}
