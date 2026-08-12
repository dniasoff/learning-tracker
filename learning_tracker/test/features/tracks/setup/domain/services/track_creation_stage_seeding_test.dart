// Regression: a track created without running the chazara wizard still gets
// the primary לימוד stage. The test uses the Firestore-era repository seam;
// no Drift row or integer track identity is involved.

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/curriculum_track_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/curriculum_scope_write_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/study_day_write_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

class _Activation extends Mock implements CurriculumActivationService {}

class _TrackRepository extends Mock
    implements FirestoreCurriculumTrackRepositoryAdapter {}

class _Stages extends Mock implements StageDefinitionRepository {
  List<StageDefinition> written = const [];
}

class _Goals extends Mock implements GoalRepository {}

class _StudyDays extends Mock implements StudyDayWriteRepository {}

class _Scopes extends Mock implements CurriculumScopeWriteRepository {}

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

TrackCreationService _service(_Stages stages) {
  final activation = _Activation();
  when(
    () => activation.activateForProfile(any(), any()),
  ).thenAnswer((_) async {});
  final tracks = _TrackRepository();
  when(() => tracks.activateTrack(any())).thenAnswer(
    (_) async => CurriculumTrackEntity(
      curriculumId: CurriculumId.mishnayos,
      state: 'active',
      stateChangedAt: DateTime.utc(2026, 1, 1),
      activatedAt: DateTime.utc(2026, 1, 1),
    ),
  );
  final studyDays = _StudyDays();
  when(
    () => studyDays.replaceAllForCurriculum(
      curriculumId: any(named: 'curriculumId'),
      studyDays: any(named: 'studyDays'),
    ),
  ).thenAnswer((_) async {});
  final scopes = _Scopes();
  when(() => scopes.clearScopes(any())).thenAnswer((_) async {});
  final goals = _Goals();
  when(() => goals.getGoals(any())).thenAnswer((_) async => const []);
  when(() => stages.replaceStagesForCurriculum(any(), any())).thenAnswer((
    invocation,
  ) async {
    stages.written = invocation.positionalArguments[1] as List<StageDefinition>;
  });

  final programs = _Programs();
  return TrackCreationService(
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
    bookmarkRepository: _Bookmarks(),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(<int, DayType>{});
    registerFallbackValue(<StageDefinition>[]);
  });

  test('no wizard result seeds exactly the לימוד stage', () async {
    final stages = _Stages();
    await _service(stages).createTrack(
      result: const AddTrackResult(
        curriculumId: CurriculumId.mishnayos,
        label: 'Mishnayos',
        studyDays: {1: 'study', 2: 'study'},
      ),
    );

    expect(stages.written, hasLength(1));
    expect(stages.written.single.stageName, 'לימוד');
    expect(stages.written.single.curriculumId, CurriculumId.mishnayos);
  });

  test(
    'stage push is not a separate Firestore operation after direct writes',
    skip:
        'The old pushStagesForTrack seam was Drift outbox plumbing; Firestore stage writes are direct and the production adapter has no push method to observe.',
    () async {},
  );
}
