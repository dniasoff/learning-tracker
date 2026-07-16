/// Acceptance tests for Issue 2 (track restoreOrCreate prevents UNIQUE
/// violation on delete + recreate) and Issue 3 (purgeHistory hard-deletes
/// completions before the track is re-added).
@Tags(['epic_18'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart' show seedProfile;

void main() {
  group(
    'Story 18.x — restoreOrCreate prevents UNIQUE violation on track recreate',
    tags: ['story_18_x'],
    () {
      late UserDatabase db;

      setUp(() async {
        db = UserDatabase(NativeDatabase.memory());
        await seedProfile(db);
      });
      tearDown(() => db.close());

      test('create → soft-delete → recreate returns same trackId', () async {
        const profileId = 1;
        const curriculum = CurriculumId.mishnayos;

        // Create
        final id1 = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: curriculum,
        );

        // Soft-delete
        await db.trackDao.deleteTrackAndData(id1);
        final deleted = await db.trackDao.getTrackById(id1);
        expect(deleted?.state, isNot('active'));

        // Recreate — must return same id, no UNIQUE violation
        final id2 = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: curriculum,
        );
        expect(id2, equals(id1));

        // Track must be active again
        final restored = await db.trackDao.getTrackById(id2);
        expect(restored?.state, 'active');
      });

      test(
        'restoreOrCreate is idempotent on an already-active track',
        () async {
          const profileId = 1;
          const curriculum = CurriculumId.mishnayos;

          final id1 = await db.trackDao.restoreOrCreate(
            profileId: profileId,
            curriculumId: curriculum,
          );

          // Call again without deleting — must return same id
          final id2 = await db.trackDao.restoreOrCreate(
            profileId: profileId,
            curriculumId: curriculum,
          );

          expect(id2, equals(id1));
          final track = await db.trackDao.getTrackById(id2);
          expect(track?.state, 'active');
        },
      );

      test(
        'purgeHistory: recreate after wipe shows zero completions',
        () async {
          const profileId = 1;
          const curriculum = CurriculumId.mishnayos;

          // Create track and add a completion
          final trackId = await db.trackDao.restoreOrCreate(
            profileId: profileId,
            curriculumId: curriculum,
          );
          await db
              .into(db.completionEvents)
              .insert(
                CompletionEventsCompanion.insert(
                  profileId: profileId,
                  curriculumId: curriculum.storageKey,
                  sefariaRef: 'Mishnah Berakhot 1',
                  stageId: 1,
                  trackType: 'personal',
                  trackId: Value(trackId),
                  eventTimestamp: DateTime.utc(2026, 5, 1),
                ),
              );

          // Verify completion exists
          final before = await (db.select(
            db.completionEvents,
          )..where((t) => t.trackId.equals(trackId))).get();
          expect(before, hasLength(1));

          // Purge history
          await db.trackDao.purgeHistory(trackId);

          // Completions are tombstoned (purgedAt set), not deleted.
          // The completions_view (purgedAt IS NULL filter) must be empty.
          final after = await db.completionDao.getCompletionsByTrack(trackId);
          expect(after, isEmpty);

          // AUD-t-story-acceptance-26: the assertion above only proves the
          // *view* is empty — completionsView filters `purgedAt IS NULL`,
          // so a regression that hard-deletes the row instead of tombstoning
          // it would produce this exact same empty result. Go around the
          // view with a raw select on completion_events directly to prove
          // the row count is unchanged (append-only, C3/N8) and purgedAt is
          // actually set on every row for this track.
          final rawAfter = await (db.select(
            db.completionEvents,
          )..where((t) => t.trackId.equals(trackId))).get();
          expect(
            rawAfter,
            hasLength(before.length),
            reason:
                'completion_events row count must be unchanged by '
                'purgeHistory — rows are tombstoned, never deleted '
                '(C3/N8 append-only invariant)',
          );
          expect(
            rawAfter.every((c) => c.purgedAt != null),
            isTrue,
            reason:
                'every completion_events row for the purged track must '
                'carry a non-null purgedAt',
          );

          // Track row is physically deleted — no tombstone left behind.
          final trackRow = await db.trackDao.getTrackById(trackId);
          expect(trackRow, isNull);
        },
      );
    },
  );
}
