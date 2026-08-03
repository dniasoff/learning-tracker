// AUD-tracks-19: TrackCreationService and TrackEditService previously each
// carried a byte-for-byte-identical private "delete then loop-await-upsert"
// study-day method, and TrackCreationService additionally hand-rolled an
// awaited per-row scope insert loop directly against the table. Both now
// delegate to shared, batched DAO helpers
// (StudyDayConfigDao.replaceAllForTrack / CurriculumScopeDao
// .insertScopesForTrack). These tests pin the observable behavior — the
// persisted rows — so the extraction cannot silently change what gets
// written.

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_edit_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/drift_memory.dart';

class _MockActivation extends Mock implements CurriculumActivationService {}

class _MockWizard extends Mock implements LearningProcessWizardService {}

class _MockGoalRepo extends Mock implements GoalRepository {}

class _MockStageRepo extends Mock implements StageDefinitionRepository {}

class _MockBookmarkRepo extends Mock implements BookmarkRepository {}

void main() {
  late UserDatabase db;

  setUpAll(() {
    registerFallbackValue(CurriculumId.bavli);
    registerFallbackValue(
      const WizardResult(
        curriculumId: CurriculumId.bavli,
        choice: WizardChoice.noReview,
      ),
    );
  });

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db); // learner_profiles(id = 1)
  });

  tearDown(() async {
    await db.close();
  });

  group('TrackCreationService — study days & scopes (AUD-tracks-19)', () {
    Future<TrackCreationService> buildService() async {
      final stageRepo = _MockStageRepo();
      when(
        () => stageRepo.deleteStagesForTrack(any()),
      ).thenAnswer((_) async {});
      when(
        () => stageRepo.pushStagesForTrack(
          trackId: any(named: 'trackId'),
          curriculumId: any(named: 'curriculumId'),
        ),
      ).thenAnswer((_) async {});

      final activation = _MockActivation();
      when(
        () => activation.activateForProfile(any(), any()),
      ).thenAnswer((_) async {});

      final wizard = _MockWizard();
      when(
        () => wizard.applyWizardResult(
          any(),
          profileId: any(named: 'profileId'),
          trackId: any(named: 'trackId'),
        ),
      ).thenAnswer((_) async {});

      return TrackCreationService(
        database: db,
        activationService: activation,
        wizardService: wizard,
        goalRepository: _MockGoalRepo(),
        stageRepository: stageRepo,
        // None of these tests set a programId, so setBookmark is never
        // reached — no stubbing needed.
        bookmarkRepository: _MockBookmarkRepo(),
      );
    }

    test(
      'persists every study day passed in AddTrackResult.studyDays',
      () async {
        final service = await buildService();
        const result = AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: 'Bavli',
          studyDays: {1: 'study', 2: 'rest', 5: 'study'},
        );

        await service.createTrack(result: result, profileId: 1);

        final rows = await db.studyDayConfigDao
            .getConfigsByCurriculumAndProfile(CurriculumId.bavli.storageKey, 1);
        expect(
          {for (final r in rows) r.dayOfWeek: r.dayType},
          {1: 'study', 2: 'rest', 5: 'study'},
        );
      },
    );

    test(
      'persists mixed-level scope selections (breadcrumb drill-down)',
      () async {
        final service = await buildService();
        const result = AddTrackResult(
          curriculumId: CurriculumId.mishnayos,
          label: 'Mishnayos',
          studyDays: {1: 'study'},
          scopeSelections: [
            ScopeEntry(level: 1, value: 'Seder Zeraim'),
            ScopeEntry(level: 2, value: 'Berachos'),
          ],
        );

        await service.createTrack(result: result, profileId: 1);

        final trackId = (await db.select(db.curriculumTracks).getSingle()).id;
        final scopes = await db.curriculumScopeDao.getScopesByTrack(trackId);
        expect(
          {for (final s in scopes) s.scopeLevel: s.scopeValue},
          {1: 'Seder Zeraim', 2: 'Berachos'},
        );
      },
    );

    test('writes no scope rows when scopeSelections is omitted', () async {
      final service = await buildService();
      const result = AddTrackResult(
        curriculumId: CurriculumId.bavli,
        label: 'Bavli',
        studyDays: {1: 'study'},
      );

      await service.createTrack(result: result, profileId: 1);

      final trackId = (await db.select(db.curriculumTracks).getSingle()).id;
      final scopes = await db.curriculumScopeDao.getScopesByTrack(trackId);
      expect(scopes, isEmpty);
    });
  });

  group('TrackEditService — study days (AUD-tracks-19)', () {
    test(
      'replaceAllForTrack fully replaces a prior study-day set on edit',
      () async {
        final trackId = await seedTrack(
          db,
          profileId: 1,
          curriculumId: 'bavli',
        );
        await db.studyDayConfigDao.seedDefaultsForTrack(trackId: trackId);

        final service = TrackEditService(
          database: db,
          wizardService: _MockWizard(),
          goalRepository: _MockGoalRepo(),
        );

        await service.editTrack(
          trackId: trackId,
          // No goal-changing field is passed below, so this value is never
          // read (hasGoalChange stays false) — a minimal stand-in is enough.
          goal: GoalEntity(
            id: 1,
            curriculumId: CurriculumId.bavli,
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
          profileId: 1,
          curriculum: CurriculumId.bavli,
          studyDays: const {3: 'rest'},
        );

        final rows = await db.studyDayConfigDao
            .getConfigsByCurriculumAndProfile(CurriculumId.bavli.storageKey, 1);
        expect(rows, hasLength(1));
        expect(rows.single.dayOfWeek, 3);
        expect(rows.single.dayType, 'rest');
      },
    );
  });
}
