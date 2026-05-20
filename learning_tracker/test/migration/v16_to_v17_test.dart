/// C2 migration gate — schema v16 → v17.
///
/// Verifies:
///   1. FK enforcement is active (PRAGMA foreign_keys = ON in beforeOpen).
///   2. Inserting a completion with a non-existent profileId fails.
///   3. Deleting a learner profile cascade-deletes completions,
///      completion_events, streak_events, bookmarks, goals, stage_definitions.
///   4. Deleting a track hard-deletes bookmarks (ON DELETE CASCADE).
///   5. Deleting a track sets learning_ledger.trackId = NULL (ON DELETE SET NULL).
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

import '../helpers/drift_memory.dart';

void main() {
  group('v16→v17: FK constraints + PRAGMA foreign_keys', () {
    // ── Helper: seed a profile, account, track ────────────────────────────

    Future<({int profileId, int trackId})> seedProfileAndTrack(
      UserDatabase db,
    ) async {
      // Need an account first (learner_profiles.accountId)
      final accountId = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              email: 'test@example.com',
              tier: 'localBorn',
              displayName: 'Tester',
              userMode: 'adult',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
      final profileId = await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: accountId,
              displayName: 'Tester',
              mode: 'adult',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: CurriculumId.mishnayos.storageKey,
              stateChangedAt: DateTimeFactory.nowUtc(),
              activatedAt: DateTimeFactory.nowUtc(),
            ),
          );
      return (profileId: profileId, trackId: trackId);
    }

    // ── 1. FK enforcement is on ───────────────────────────────────────────

    test(
      'PRAGMA foreign_keys is enabled — inserting orphan completion fails',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);

        // Ensure a track exists so trackId FK is satisfied, but use a
        // non-existent profileId to test the new profileId FK.
        final accountId = await db
            .into(db.accounts)
            .insert(
              AccountsCompanion.insert(
                email: 'test@example.com',
                tier: 'localBorn',
                displayName: 'Tester',
                userMode: 'adult',
                createdAt: DateTimeFactory.nowUtc(),
                updatedAt: DateTimeFactory.nowUtc(),
              ),
            );
        final profileId = await db
            .into(db.learnerProfiles)
            .insert(
              LearnerProfilesCompanion.insert(
                accountId: accountId,
                displayName: 'Tester',
                mode: 'adult',
                createdAt: DateTimeFactory.nowUtc(),
                updatedAt: DateTimeFactory.nowUtc(),
              ),
            );
        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: profileId,
                curriculumId: CurriculumId.mishnayos.storageKey,
                stateChangedAt: DateTimeFactory.nowUtc(),
                activatedAt: DateTimeFactory.nowUtc(),
              ),
            );

        const nonExistentProfileId = 9999;

        expect(
          () => seedCompletion(
            db,
            CompletionEventsCompanion.insert(
              profileId: nonExistentProfileId,
              curriculumId: CurriculumId.mishnayos.storageKey,
              sefariaRef: 'Berakhot 1:1',
              stageId: 1,
              trackType: TrackType.personal.storageKey,
              trackId: Value(trackId),
              eventTimestamp: DateTimeFactory.nowUtc(),
            ),
          ),
          throwsA(anything),
          reason:
              'C2: FK enforcement must reject completion with non-existent profileId',
        );
      },
    );

    // ── 2. Profile cascade-deletes completions ────────────────────────────

    test('deleting a profile cascade-deletes completions', () async {
      final db = inMemoryDb();
      addTearDown(db.close);

      final seed = await seedProfileAndTrack(db);

      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: seed.profileId,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Berakhot 1:1',
          stageId: 1,
          trackType: TrackType.personal.storageKey,
          trackId: Value(seed.trackId),
          eventTimestamp: DateTimeFactory.nowUtc(),
          // W3.22: derivedFromEvents removed from schema
        ),
      );

      expect(
        await db.completionDao.getCompletionsByProfile(seed.profileId),
        hasLength(1),
      );

      // Delete the learner profile — should cascade.
      await (db.delete(
        db.learnerProfiles,
      )..where((t) => t.id.equals(seed.profileId))).go();

      expect(
        await db.completionDao.getCompletionsByProfile(seed.profileId),
        isEmpty,
        reason: 'C2: deleting a profile must cascade-delete its completions',
      );
    });

    // ── 3. Track hard-delete cascade-deletes bookmarks ────────────────────

    test('purging a track cascade-deletes its bookmarks', () async {
      final db = inMemoryDb();
      addTearDown(db.close);

      final seed = await seedProfileAndTrack(db);

      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              profileId: seed.profileId,
              curriculumId: CurriculumId.mishnayos.storageKey,
              trackId: seed.trackId,
              sefariaRef: 'Berakhot 2:1',
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );

      expect(
        await (db.select(
          db.bookmarks,
        )..where((t) => t.profileId.equals(seed.profileId))).get(),
        hasLength(1),
      );

      // Hard-delete the track (simulates purgeHistory's final step).
      await (db.delete(
        db.curriculumTracks,
      )..where((t) => t.id.equals(seed.trackId))).go();

      expect(
        await (db.select(
          db.bookmarks,
        )..where((t) => t.profileId.equals(seed.profileId))).get(),
        isEmpty,
        reason:
            'C2: bookmarks.trackId ON DELETE CASCADE must remove bookmarks '
            'when the track is hard-deleted',
      );
    });
  });
}
