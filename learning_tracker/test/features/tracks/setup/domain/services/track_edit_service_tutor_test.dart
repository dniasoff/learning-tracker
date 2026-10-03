// Story 1.24 (DNI-486): a tutor's track edit never half-applies a chazara
// change. The stage set has no governed tutor callable yet, so the edit is
// refused BEFORE the study days, stages or goal are written.

@Tags(['tutor_mode'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/study_day_write_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_edit_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

class _Stages extends Mock implements StageDefinitionRepository {}

class _Goals extends Mock implements GoalRepository {}

class _Programs implements ProfileProgramRepository {
  int writes = 0;

  @override
  Future<ProfileProgramEntity?> getProgram(CurriculumId curriculumId) async =>
      null;

  @override
  Future<void> setProgram({
    required CurriculumId curriculumId,
    required int programId,
    DateTime? trackingStartDate,
    String? trackingStartRef,
  }) async => writes++;

  @override
  Future<void> removeProgram(CurriculumId curriculumId) async => writes++;
}

class _StudyDays implements StudyDayWriteRepository {
  int writes = 0;

  @override
  Future<void> replaceAllForCurriculum({
    required CurriculumId curriculumId,
    required Map<int, DayType> studyDays,
  }) async => writes++;
}

void main() {
  late _Stages stages;
  late _Goals goals;
  late _Programs programs;
  late _StudyDays studyDays;

  TrackEditService service({required bool tutored}) => TrackEditService(
    wizardService: LearningProcessWizardService(
      stageRepository: stages,
      learningProgramRepo: LearningProgramRepository.instance,
      profileProgramRepository: programs,
    ),
    goalRepository: goals,
    studyDayRepository: studyDays,
    isTutoredSession: () => tutored,
  );

  final goal = GoalEntity(
    curriculumId: CurriculumId.mishnayos,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
  const chazara = WizardResult(
    curriculumId: CurriculumId.mishnayos,
    choice: WizardChoice.noReview,
  );

  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(<StageDefinition>[]);
  });

  setUp(() {
    stages = _Stages();
    goals = _Goals();
    programs = _Programs();
    studyDays = _StudyDays();
  });

  test('a tutor edit carrying a chazara change is refused before ANY '
      'write: study days, stages, program and goal stay untouched', () async {
    await expectLater(
      service(tutored: true).editTrack(
        goal: goal,
        curriculum: CurriculumId.mishnayos,
        label: 'Renamed',
        studyDays: const {1: 'study'},
        chazarahWizard: chazara,
      ),
      throwsA(isA<TutorChazaraEditUnsupportedException>()),
    );

    expect(studyDays.writes, 0);
    expect(programs.writes, 0);
    verifyZeroInteractions(stages);
    verifyZeroInteractions(goals);
  });

  test('a tutor edit without a chazara change goes through', () async {
    await service(tutored: true).editTrack(
      goal: goal,
      curriculum: CurriculumId.mishnayos,
      studyDays: const {1: 'study'},
    );
    expect(studyDays.writes, 1);
  });

  test('the owner still changes chazara', () async {
    when(
      () => stages.replaceStagesForCurriculum(any(), any()),
    ).thenAnswer((_) async {});
    await service(tutored: false).editTrack(
      goal: goal,
      curriculum: CurriculumId.mishnayos,
      chazarahWizard: chazara,
    );
    verify(() => stages.replaceStagesForCurriculum(any(), any())).called(1);
  });
}
