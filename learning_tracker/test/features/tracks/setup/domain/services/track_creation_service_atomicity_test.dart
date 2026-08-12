// TrackCreationService regressions for the Firestore migration.

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
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
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/fake_clock.dart';

class _MockActivation extends Mock implements CurriculumActivationService {}

class _MockTrackRepository extends Mock
    implements FirestoreCurriculumTrackRepositoryAdapter {}

class _MockStageRepository extends Mock implements StageDefinitionRepository {}

class _MockGoalRepository extends Mock implements GoalRepository {}

class _MockStudyDays extends Mock implements StudyDayWriteRepository {}

class _MockScopes extends Mock implements CurriculumScopeWriteRepository {}

class _MockBookmarkRepository extends Mock implements BookmarkRepository {}

class _RecordingProfilePrograms implements ProfileProgramRepository {
  ({CurriculumId curriculum, int programId, DateTime? date, String? ref})?
  lastSet;

  @override
  Future<ProfileProgramEntity?> getProgram(CurriculumId curriculumId) async =>
      null;

  @override
  Future<void> setProgram({
    required CurriculumId curriculumId,
    required int programId,
    DateTime? trackingStartDate,
    String? trackingStartRef,
  }) async {
    lastSet = (
      curriculum: curriculumId,
      programId: programId,
      date: trackingStartDate,
      ref: trackingStartRef,
    );
  }

  @override
  Future<void> removeProgram(CurriculumId curriculumId) async {}
}

class _MemoryBookmarks implements BookmarkRepository {
  BookmarkEntity? value;

  @override
  Future<BookmarkEntity?> getBookmark({
    required CurriculumId curriculumId,
  }) async => value;

  @override
  Future<BookmarkEntity> setBookmark({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    return value = BookmarkEntity(
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      updatedAt: DateTimeFactory.nowUtc(),
    );
  }

  @override
  Future<void> advanceBookmark({
    required CurriculumId curriculumId,
    required String completedSefariaRef,
  }) async => throw UnimplementedError();

  @override
  Future<BookmarkEntity> initializeBookmark({
    required CurriculumId curriculumId,
  }) async => throw UnimplementedError();
}

TrackCreationService _buildService({
  required _MockStageRepository stageRepository,
  required _RecordingProfilePrograms profilePrograms,
  required BookmarkRepository bookmarkRepository,
}) {
  final activation = _MockActivation();
  when(
    () => activation.activateForProfile(any(), any()),
  ).thenAnswer((_) async {});
  final trackRepository = _MockTrackRepository();
  when(() => trackRepository.activateTrack(any())).thenAnswer(
    (_) async => CurriculumTrackEntity(
      curriculumId: CurriculumId.mishnayos,
      state: 'active',
      stateChangedAt: DateTime.utc(2026, 1, 1),
      activatedAt: DateTime.utc(2026, 1, 1),
    ),
  );
  final studyDays = _MockStudyDays();
  when(
    () => studyDays.replaceAllForCurriculum(
      curriculumId: any(named: 'curriculumId'),
      studyDays: any(named: 'studyDays'),
    ),
  ).thenAnswer((_) async {});
  final scopes = _MockScopes();
  when(() => scopes.clearScopes(any())).thenAnswer((_) async {});
  final goals = _MockGoalRepository();
  when(() => goals.getGoals(any())).thenAnswer((_) async => const []);
  final wizard = LearningProcessWizardService(
    stageRepository: stageRepository,
    learningProgramRepo: LearningProgramRepository.instance,
    profileProgramRepository: profilePrograms,
  );
  return TrackCreationService(
    activationService: activation,
    wizardService: wizard,
    goalRepository: goals,
    trackRepository: trackRepository,
    studyDayRepository: studyDays,
    scopeRepository: scopes,
    profileProgramRepository: profilePrograms,
    bookmarkRepository: bookmarkRepository,
  );
}

BookmarkRepository _stubbedBookmarks() {
  final bookmarks = _MockBookmarkRepository();
  when(
    () => bookmarks.setBookmark(
      curriculumId: any(named: 'curriculumId'),
      sefariaRef: any(named: 'sefariaRef'),
    ),
  ).thenAnswer(
    (invocation) async => BookmarkEntity(
      curriculumId: invocation.namedArguments[#curriculumId] as CurriculumId,
      sefariaRef: invocation.namedArguments[#sefariaRef] as String,
      updatedAt: DateTimeFactory.nowUtc(),
    ),
  );
  return bookmarks;
}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.bavli);
    registerFallbackValue(<int, DayType>{});
    registerFallbackValue(
      const WizardResult(
        curriculumId: CurriculumId.bavli,
        choice: WizardChoice.noReview,
      ),
    );
  });

  test(
    'D7: cross-collection rollback is not portable through repository calls',
    skip:
        'Firestore repositories used by TrackCreationService do not expose a cross-collection transaction; the production service documents this migration gap explicitly.',
    () async {},
  );

  for (final (label, startingRef) in [
    ('positive', 'offset:5'),
    ('negative', 'offset:-5'),
  ]) {
    test('B3: $label back-date offset resolves to the past', () async {
      final stages = _MockStageRepository();
      when(
        () => stages.replaceStagesForCurriculum(any(), any()),
      ).thenAnswer((_) async {});
      final programs = _RecordingProfilePrograms();
      final service = _buildService(
        stageRepository: stages,
        profilePrograms: programs,
        bookmarkRepository: _stubbedBookmarks(),
      );

      final fixedNow = DateTime.utc(2026, 6, 15, 12);
      installFakeClock(fixedNow);
      final before = DateTimeFactory.nowUtc();

      await service.createTrack(
        result: AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          programId: 99,
          studyDays: const {1: 'study'},
          startingRef: startingRef,
        ),
      );

      final date = programs.lastSet?.date;
      expect(date, isNotNull);
      expect(date!.isBefore(before), isTrue);
      expect(before.difference(date).inDays, 5);
    });
  }

  test(
    'F1: program creation writes the starting bookmark through the repository',
    () async {
      final stages = _MockStageRepository();
      when(
        () => stages.replaceStagesForCurriculum(any(), any()),
      ).thenAnswer((_) async {});
      final programs = _RecordingProfilePrograms();
      final bookmarks = _MemoryBookmarks();
      final service = _buildService(
        stageRepository: stages,
        profilePrograms: programs,
        bookmarkRepository: bookmarks,
      );

      await service.createTrack(
        result: const AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          programId: 99,
          studyDays: {1: 'study'},
          startingRef: 'Mishnah Berakhot 2:1',
        ),
      );

      expect(
        (await bookmarks.getBookmark(
          curriculumId: CurriculumId.bavli,
        ))?.sefariaRef,
        'Mishnah Berakhot 2:1',
      );
    },
  );
}
