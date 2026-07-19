// Tests for story 26.26 (DNI-369) — updated for W4.10 ScheduleSpec API.
//
// AUD-tracks-12: the addStage/reorderStages/deleteStage/updateStage groups
// that used to live here were removed along with the (dead, zero-UI-caller)
// StageDefinitionRepository mutation methods they exercised — see the
// removal note on StageDefinitionRepositoryImpl. What remains is:
// - ScheduleSpec.fromParts reconstruction from raw DB columns
// - resetToDefaults cross-profile / cross-track isolation (R6-12 regression)
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';

import '../../../../helpers/test_database.dart'
    show seedProfile, seedProfileWithIds;

void main() {
  // =========================================================================
  // Group 6: ScheduleSpec.fromParts — reconstruction from raw DB columns
  // =========================================================================

  group('ScheduleSpec.fromParts — reconstruction', () {
    test('fromParts with delay key returns DelaySchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'delay',
        delayDays: 7,
        daysOfWeek: null,
        rollingWindowSize: null,
      );
      expect(spec, const DelaySchedule(7));
    });

    test('fromParts with weekly key returns WeeklySchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'weekly',
        delayDays: 0,
        daysOfWeek: [1, 5],
        rollingWindowSize: null,
      );
      expect(spec, WeeklySchedule([1, 5]));
    });

    test('fromParts with rolling key returns RollingSchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'rolling',
        delayDays: 0,
        daysOfWeek: null,
        rollingWindowSize: 14,
      );
      expect(spec, RollingSchedule(14));
    });

    test('fromParts with unknown key falls back to DelaySchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'unknown_legacy',
        delayDays: 3,
        daysOfWeek: null,
        rollingWindowSize: null,
      );
      expect(spec, const DelaySchedule(3));
    });
  });

  // =========================================================================
  // Group 7: R6-12 regression — cross-profile stage isolation on resetToDefaults
  //
  // Scenario: two profiles each have a track for the same curriculum (mishnayos).
  // Resetting profile 1's track must NOT delete profile 2's stage definitions.
  // =========================================================================

  group('resetToDefaults — cross-profile isolation (R6-12)', () {
    /// Helper: creates one in-memory DB, seeds two profiles, creates a
    /// curriculum track for each, initialises defaults on both, then returns
    /// everything needed to exercise resetToDefaults on one profile and verify
    /// the other profile's stages are intact.
    Future<
      ({
        db.UserDatabase database,
        int trackId1,
        int trackId2,
        StageDefinitionRepositoryImpl repo1,
        StageDefinitionRepositoryImpl repo2,
      })
    >
    makeTwoProfileSetup() async {
      final database = db.UserDatabase(NativeDatabase.memory());

      // Seed two profiles with explicit ids using separate accounts.
      // profile 1 = accountId 1, profile 2 = accountId 2.
      await seedProfileWithIds(database, accountId: 1, profileId: 1);
      await seedProfileWithIds(database, accountId: 2, profileId: 2);

      // Create one mishnayos track per profile.
      final trackId1 = await database
          .into(database.curriculumTracks)
          .insert(
            db.CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      final trackId2 = await database
          .into(database.curriculumTracks)
          .insert(
            db.CurriculumTracksCompanion.insert(
              profileId: 2,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      // Both repositories share the same underlying DB (same DAOs) — this is
      // the realistic runtime topology where a single UserDatabase is injected.
      StageDefinitionRepositoryImpl makeRepo() => StageDefinitionRepositoryImpl(
        stageDao: database.stageDao,
        completionDao: database.completionDao,
        pushStageDefinitions: null,
      );

      final repo1 = makeRepo();
      final repo2 = makeRepo();

      return (
        database: database,
        trackId1: trackId1,
        trackId2: trackId2,
        repo1: repo1,
        repo2: repo2,
      );
    }

    test(
      'resetting profile 1 track does not delete profile 2 stages for same curriculum',
      () async {
        final ctx = await makeTwoProfileSetup();
        addTearDown(() => ctx.database.close());

        const curriculum = CurriculumId.mishnayos;

        // Both profiles initialise 3 default stages for the same curriculum.
        await ctx.repo1.initializeDefaults(
          curriculum,
          profileId: 1,
          trackId: ctx.trackId1,
        );
        await ctx.repo2.initializeDefaults(
          curriculum,
          profileId: 2,
          trackId: ctx.trackId2,
        );

        // Verify both profiles start with 3 stages each.
        final before1 = await ctx.database.stageDao.getStagesByTrack(
          ctx.trackId1,
        );
        final before2 = await ctx.database.stageDao.getStagesByTrack(
          ctx.trackId2,
        );
        expect(
          before1,
          hasLength(3),
          reason: 'profile 1 should have 3 stages before reset',
        );
        expect(
          before2,
          hasLength(3),
          reason: 'profile 2 should have 3 stages before reset',
        );

        // Reset ONLY profile 1's track.
        await ctx.repo1.resetToDefaults(
          curriculum,
          profileId: 1,
          trackId: ctx.trackId1,
        );

        // Profile 1 still has 3 stages (new defaults).
        final after1 = await ctx.database.stageDao.getStagesByTrack(
          ctx.trackId1,
        );
        expect(
          after1,
          hasLength(3),
          reason: 'profile 1 should have 3 defaults after reset',
        );

        // Profile 2's stages must be completely untouched — R6-12 regression.
        final after2 = await ctx.database.stageDao.getStagesByTrack(
          ctx.trackId2,
        );
        expect(
          after2,
          hasLength(3),
          reason: 'R6-12: profile 2 stages must survive a reset on profile 1',
        );
        expect(
          after2.map((s) => s.profileId).toSet(),
          equals({2}),
          reason: 'profile 2 stages should all still belong to profile 2',
        );
      },
    );

    test(
      'resetting one trackId leaves stages for a different trackId in the same curriculum intact',
      () async {
        // Two distinct track rows for the same profile+curriculum (mishnayos) —
        // exercises that deleteStagesForTrack is keyed on trackId, not curriculumId.
        //
        // trackA and trackB are both real rows in curriculum_tracks (satisfying FK).
        // trackB uses a different curriculum ('chumash') to bypass the
        // unique(profileId, curriculumId) constraint on curriculum_tracks, but
        // its stage_definitions rows still record curriculumId='mishnayos' — the
        // relevant isolation is trackId, not curriculumId.
        final database = db.UserDatabase(NativeDatabase.memory());
        addTearDown(() => database.close());

        await seedProfile(database); // account id=1, profile id=1

        final trackA = await database
            .into(database.curriculumTracks)
            .insert(
              db.CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'mishnayos',
                stateChangedAt: DateTime.utc(2026, 1, 1),
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );

        // trackB must be a real FK-valid row; use a different curriculum to
        // avoid the unique(profileId, curriculumId) constraint.
        final trackB = await database
            .into(database.curriculumTracks)
            .insert(
              db.CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'chumash',
                stateChangedAt: DateTime.utc(2026, 1, 1),
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );

        final stageDao = database.stageDao;

        // Insert 3 stages for trackA (mishnayos curriculum).
        for (var i = 1; i <= 3; i++) {
          await stageDao.insertStageDefinition(
            db.StageDefinitionsCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              trackId: trackA,
              stageOrder: i,
              stageName: 'Stage $i A',
              schedule: const Value('{"type":"delay","delay_days":0}'),
            ),
          );
        }

        // Insert 3 stages for trackB — same curriculumId as trackA so the
        // old (broken) deleteAllForCurriculum call would have wiped these.
        for (var i = 1; i <= 3; i++) {
          await stageDao.insertStageDefinition(
            db.StageDefinitionsCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              trackId: trackB,
              stageOrder: i,
              stageName: 'Stage $i B',
              schedule: const Value('{"type":"delay","delay_days":0}'),
            ),
          );
        }

        expect(await stageDao.getStagesByTrack(trackA), hasLength(3));
        expect(await stageDao.getStagesByTrack(trackB), hasLength(3));

        // Reset only trackA via the repository.
        final repo = StageDefinitionRepositoryImpl(
          stageDao: stageDao,
          completionDao: database.completionDao,
          pushStageDefinitions: null,
        );
        await repo.resetToDefaults(
          CurriculumId.mishnayos,
          profileId: 1,
          trackId: trackA,
        );

        // trackA gets 3 fresh defaults.
        expect(await stageDao.getStagesByTrack(trackA), hasLength(3));

        // trackB's 3 stages are untouched — R6-12 regression assertion.
        // Before the fix, deleteAllForCurriculum('mishnayos') would have
        // deleted trackB's stages too.
        final trackBAfter = await stageDao.getStagesByTrack(trackB);
        expect(
          trackBAfter,
          hasLength(3),
          reason:
              'R6-12: trackB stages must not be deleted when trackA is reset',
        );
        expect(
          trackBAfter.map((s) => s.stageName).toList(),
          contains('Stage 1 B'),
        );
      },
    );
  });
}
