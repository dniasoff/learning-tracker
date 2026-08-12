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
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/curriculum_scope_write_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/study_day_write_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_edit_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

class _Activation extends Mock implements CurriculumActivationService {}

class _Tracks extends Mock
    implements FirestoreCurriculumTrackRepositoryAdapter {}

class _Stages extends Mock implements StageDefinitionRepository {}

class _Goals extends Mock implements GoalRepository {}

class _Programs implements ProfileProgramRepository {
  @override
  Future<ProfileProgramEntity?> getProgram(CurriculumId curriculumId) async =>
      null;

  @override
  Future<void> setProgram({
    required CurriculumId curriculumId,
    required int programId,
    DateTime? trackingStartDate,
    String? trackingStartRef,
  }) async {}

  @override
  Future<void> removeProgram(CurriculumId curriculumId) async {}
}

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

class _Scopes implements CurriculumScopeWriteRepository {
  List<({int level, String value})> last = const [];

  @override
  Future<void> clearScopes(CurriculumId curriculumId) async {}

  @override
  Future<void> insertScopes({
    required CurriculumId curriculumId,
    required List<({int level, String value})> scopes,
  }) async {
    last = scopes;
  }
}

TrackCreationService _creationService({
  required _StudyDays studyDays,
  required _Scopes scopes,
}) {
  final activation = _Activation();
  when(
    () => activation.activateForProfile(any(), any()),
  ).thenAnswer((_) async {});
  final tracks = _Tracks();
  when(() => tracks.activateTrack(any())).thenAnswer(
    (_) async => CurriculumTrackEntity(
      curriculumId: CurriculumId.mishnayos,
      state: 'active',
      stateChangedAt: DateTime.utc(2026, 1, 1),
      activatedAt: DateTime.utc(2026, 1, 1),
    ),
  );
  final stageRepository = _Stages();
  when(
    () => stageRepository.replaceStagesForCurriculum(any(), any()),
  ).thenAnswer((_) async {});
  final goals = _Goals();
  when(() => goals.getGoals(any())).thenAnswer((_) async => const []);
  final programs = _Programs();
  return TrackCreationService(
    activationService: activation,
    wizardService: LearningProcessWizardService(
      stageRepository: stageRepository,
      learningProgramRepo: LearningProgramRepository.instance,
      profileProgramRepository: programs,
    ),
    goalRepository: goals,
    trackRepository: tracks,
    studyDayRepository: studyDays,
    scopeRepository: scopes,
    profileProgramRepository: programs,
    bookmarkRepository: _Bookmarks(),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.bavli);
    registerFallbackValue(<int, DayType>{});
    registerFallbackValue(<StageDefinition>[]);
  });

  test(
    'creation persists every supplied study day through the writer',
    () async {
      final studyDays = _StudyDays();
      final scopes = _Scopes();
      await _creationService(studyDays: studyDays, scopes: scopes).createTrack(
        result: const AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          studyDays: {1: 'study', 2: 'rest', 5: 'study'},
        ),
      );

      expect(studyDays.last, {
        1: DayType.study,
        2: DayType.review,
        5: DayType.study,
      });
    },
  );

  test('creation forwards mixed-level scope selections once', () async {
    final studyDays = _StudyDays();
    final scopes = _Scopes();
    await _creationService(studyDays: studyDays, scopes: scopes).createTrack(
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

    expect(scopes.last, [
      (level: 1, value: 'Seder Zeraim'),
      (level: 2, value: 'Berachos'),
    ]);
  });

  test('creation writes no scopes when selections are omitted', () async {
    final scopes = _Scopes();
    await _creationService(studyDays: _StudyDays(), scopes: scopes).createTrack(
      result: const AddTrackResult(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        studyDays: {1: 'study'},
      ),
    );
    expect(scopes.last, isEmpty);
  });

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
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
      curriculum: CurriculumId.bavli,
      studyDays: const {3: 'rest'},
    );

    expect(studyDays.last, {3: DayType.review});
  });
}
