/// Integration test for Story 26.27 (DNI-370):
/// Bulk-mark-prior must suppress streak ticks for ALL stages (not just stage 1).
///
/// Acceptance criteria:
///   Given a fresh install,
///   When 50 prior completions are written across stages 1, 2, and 3,
///   Then StreakStateService returns currentStreak == 0.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_service.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';

/// Sets up a profile and curriculum track in the DB.
/// Returns the profile id.
Future<int> _seedProfileAndTrack(UserDatabase db) async {
  final now = DateTime.utc(2026, 5, 13, 12, 0, 0);

  // Insert an account row first — learner_profiles.accountId is a FK.
  final accountId = await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@example.com',
          tier: 'localBorn',
          displayName: 'Test User',
          createdAt: now,
          updatedAt: now,
        ),
      );

  final profileRow = await db
      .into(db.learnerProfiles)
      .insertReturning(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Test User',
          mode: 'adult',
          createdAt: now,
          updatedAt: now,
        ),
      );

  await db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileRow.id,
          curriculumId: 'mishnayos',
          stateChangedAt: now,
          activatedAt: now,
        ),
      );

  return profileRow.id;
}

void main() {
  late UserDatabase db;
  late int profileId;
  late CompletionRepositoryImpl repository;

  setUp(() async {
    db = UserDatabase(NativeDatabase.memory());
    profileId = await _seedProfileAndTrack(db);
    repository = CompletionRepositoryImpl(
      database: db,
      activeProfileId: profileId,
    );
  });

  tearDown(() async {
    await db.close();
    resetLocalDayClock();
  });

  group(
    'Story 26.27 (DNI-370) — bulk-mark-prior streak suppression for all stages',
    () {
      /// AC1 + AC2: 50 prior completions across stages 1, 2, and 3 must not
      /// credit a streak (currentStreak == 0).
      ///
      /// Before the DNI-370 fix the `stageId == 1` guard in `bulkMarkComplete`
      /// meant stages 2 and 3 fell through to the slow path which called
      /// `_appendStreakEvent`, incorrectly writing a today-dated streak event.
      test(
        'AC1+AC2: 50 prior completions across stages 1, 2, 3 → currentStreak == 0',
        () async {
          const curriculumId = 'mishnayos';
          const trackType = 'personal';

          // 50 refs spread across 3 stages (17 + 17 + 16).
          final allRefs = List.generate(50, (i) => 'Mishnah Berachot $i:1');
          final stage1Refs = allRefs.sublist(0, 17);
          final stage2Refs = allRefs.sublist(17, 34);
          final stage3Refs = allRefs.sublist(34, 50);

          // Write completions for each stage with awardGamificationPoints=false
          // (the onboarding bulk-mark-prior flag).
          for (final entry in [
            (stageId: 1, refs: stage1Refs),
            (stageId: 2, refs: stage2Refs),
            (stageId: 3, refs: stage3Refs),
          ]) {
            await repository.bulkMarkComplete(
              BulkCompletionRequest(
                curriculumId: curriculumId,
                sefariaRefs: entry.refs,
                stageId: entry.stageId,
                trackType: trackType,
                profileId: profileId,
                awardGamificationPoints: false,
              ),
            );
          }

          // Verify 50 completion rows exist (one per ref, since each ref
          // only appears in one stage in this test).
          final allCompletions = await db.completionDao
              .getCompletionsByCurriculumAndProfile(curriculumId, profileId);
          expect(allCompletions, hasLength(50));

          // Use a far-future clock so all completions (written today) are in
          // the distant past: gapToToday >> 1 → currentStreak == 0.
          // The StreakRestorer reconstitutes events from completions, but the
          // StreakReducer discards runs that are not alive relative to "today".
          final farFutureClock = FakeLocalDayClock(DateTime.utc(2099, 1, 1));
          final state = await StreakStateService(
            db: db,
            clock: farFutureClock,
          ).read(profileId: profileId);

          expect(
            state.currentStreak,
            0,
            reason:
                'Prior completions across all stages must not credit a streak '
                '(streak events must not be inserted for bulk-mark-prior writes)',
          );
        },
      );

      /// Regression: stage-1 path (original optimised path) still yields 0.
      test(
        'regression: stage-1-only bulk-mark-prior still yields currentStreak == 0',
        () async {
          const curriculumId = 'mishnayos';
          const trackType = 'personal';
          final refs = List.generate(20, (i) => 'Mishnah Berachot $i:1');

          await repository.bulkMarkComplete(
            BulkCompletionRequest(
              curriculumId: curriculumId,
              sefariaRefs: refs,
              stageId: 1,
              trackType: trackType,
              profileId: profileId,
              awardGamificationPoints: false,
            ),
          );

          final farFutureClock = FakeLocalDayClock(DateTime.utc(2099, 1, 1));
          final state = await StreakStateService(
            db: db,
            clock: farFutureClock,
          ).read(profileId: profileId);

          expect(state.currentStreak, 0);
        },
      );

      /// Regression: stage-2 path (previously broken) now yields 0.
      test('regression: stage-2 bulk-mark-prior now yields currentStreak == 0 '
          '(was broken before DNI-370)', () async {
        const curriculumId = 'mishnayos';
        const trackType = 'personal';
        final refs = List.generate(5, (i) => 'Mishnah Berachot $i:1');

        // Stage 1 first so stage-2 refs share the same ref pool.
        await repository.bulkMarkComplete(
          BulkCompletionRequest(
            curriculumId: curriculumId,
            sefariaRefs: refs,
            stageId: 1,
            trackType: trackType,
            profileId: profileId,
            awardGamificationPoints: false,
          ),
        );
        await repository.bulkMarkComplete(
          BulkCompletionRequest(
            curriculumId: curriculumId,
            sefariaRefs: refs,
            stageId: 2,
            trackType: trackType,
            profileId: profileId,
            awardGamificationPoints: false,
          ),
        );

        final farFutureClock = FakeLocalDayClock(DateTime.utc(2099, 1, 1));
        final state = await StreakStateService(
          db: db,
          clock: farFutureClock,
        ).read(profileId: profileId);

        expect(
          state.currentStreak,
          0,
          reason: 'Stage-2 bulk-mark-prior must suppress streak (DNI-370)',
        );
      });
    },
  );
}
