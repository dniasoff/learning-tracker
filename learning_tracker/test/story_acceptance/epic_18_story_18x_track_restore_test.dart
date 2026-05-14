/// Acceptance tests for Issue 2 (track restoreOrCreate prevents UNIQUE
/// violation on delete + recreate) and Issue 3 (purgeHistory hard-deletes
/// completions before the track is re-added).
@Tags(['epic_18'])
library;

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:test/test.dart';

void main() {
  group(
    'Story 18.x — restoreOrCreate prevents UNIQUE violation on track recreate',
    tags: ['story_18_x'],
    () {
      late UserDatabase db;

      setUp(() => db = UserDatabase(NativeDatabase.memory()));
      tearDown(() => db.close());

      test('create → soft-delete → recreate returns same trackId', () async {
        const profileId = 1;
        const curriculum = CurriculumId.mishnayos;
        const trackType = TrackType.personal;

        // Create
        final id1 = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: curriculum,
          trackType: trackType,
        );

        // Soft-delete
        await db.trackDao.deleteTrackAndData(id1);
        final deleted = await db.trackDao.getTrackById(id1);
        expect(deleted?.deletedAt, isNotNull);

        // Recreate — must return same id, no UNIQUE violation
        final id2 = await db.trackDao.restoreOrCreate(
          profileId: profileId,
          curriculumId: curriculum,
          trackType: trackType,
        );
        expect(id2, equals(id1));

        // Track must be active again
        final restored = await db.trackDao.getTrackById(id2);
        expect(restored?.isActive, isTrue);
        expect(restored?.deletedAt, isNull);
      });

      test(
        'restoreOrCreate is idempotent on an already-active track',
        () async {
          const profileId = 1;
          const curriculum = CurriculumId.mishnayos;
          const trackType = TrackType.personal;

          final id1 = await db.trackDao.restoreOrCreate(
            profileId: profileId,
            curriculumId: curriculum,
            trackType: trackType,
          );

          // Call again without deleting — must return same id
          final id2 = await db.trackDao.restoreOrCreate(
            profileId: profileId,
            curriculumId: curriculum,
            trackType: trackType,
          );

          expect(id2, equals(id1));
          final track = await db.trackDao.getTrackById(id2);
          expect(track?.isActive, isTrue);
        },
      );

      test(
        'purgeHistory: recreate after wipe shows zero completions',
        () async {
          const profileId = 1;
          const curriculum = CurriculumId.mishnayos;
          const trackType = TrackType.personal;

          // Create track and add a completion
          final trackId = await db.trackDao.restoreOrCreate(
            profileId: profileId,
            curriculumId: curriculum,
            trackType: trackType,
          );
          await db
              .into(db.completions)
              .insert(
                CompletionsCompanion.insert(
                  profileId: profileId,
                  curriculumId: curriculum.storageKey,
                  sefariaRef: 'Mishnah Berakhot 1',
                  stageId: 1,
                  trackType: trackType.storageKey,
                  trackId: trackId,
                  completedAt: DateTime.utc(2026, 5, 1),
                ),
              );

          // Verify completion exists
          final before = await (db.select(
            db.completions,
          )..where((t) => t.trackId.equals(trackId))).get();
          expect(before, hasLength(1));

          // Purge history
          await db.trackDao.purgeHistory(trackId);

          // Completions must be gone
          final after = await (db.select(
            db.completions,
          )..where((t) => t.trackId.equals(trackId))).get();
          expect(after, isEmpty);

          // Track row still exists (soft-deleted tombstone)
          final trackRow = await db.trackDao.getTrackById(trackId);
          expect(trackRow?.deletedAt, isNotNull);
        },
      );
    },
  );
}
