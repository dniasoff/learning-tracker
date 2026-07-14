// Extra coverage for CompletionDao — seeding via the test-only
// seedCompletionsBatch helper (test/helpers/drift_memory.dart; CompletionDao
// itself has no insertCompletionsBatch method, see completion_dao.dart's
// class doc comment), getCompletionsByTrackAndProfile, getAggregateCountByTrack,
// completionExistsByTrack, and getCompletionsByDateRangeAndTrack were not
// exercised by the baseline test.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    // Seed a second account + profile (id = 2) for cross-profile isolation tests.
    final account2 = await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            email: 'test2@example.com',
            tier: 'localBorn',
            displayName: 'Test User 2',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    await db
        .into(db.learnerProfiles)
        .insert(
          LearnerProfilesCompanion.insert(
            id: const Value(2),
            accountId: account2,
            displayName: 'Test User 2',
            mode: 'adult',
            createdAt: DateTime.utc(2026, 1, 1),
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    trackId = await seedTrack(
      db,
      profileId: 1,
      curriculumId: 'bavli',
      activatedAt: DateTime.utc(2026, 1, 1),
    );
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  CompletionEventsCompanion makeCompletion({
    int profileId = 1,
    String curriculumId = 'bavli',
    String sefariaRef = 'Berakhot.2a',
    int stageId = 1,
    String trackType = 'personal',
    DateTime? completedAt,
    DateTime? eventTimestamp,
    int? overrideTrackId,
  }) {
    return CompletionEventsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: trackType,
      trackId: Value(overrideTrackId ?? trackId),
      eventTimestamp: eventTimestamp ?? completedAt ?? DateTime.utc(2026, 1, 1),
    );
  }

  // ---------------------------------------------------------------------------
  // seeding + getCompletionsByTrack (via the test-only seedCompletionsBatch
  // helper — CompletionDao itself has no insertCompletionsBatch method)
  // ---------------------------------------------------------------------------

  group('seeding + getCompletionsByTrack', () {
    test('inserts multiple completions in a single batch', () async {
      await seedCompletionsBatch(db, [
        makeCompletion(
          sefariaRef: 'Berakhot.2a',
          eventTimestamp: DateTime.utc(2026, 1, 1),
        ),
        makeCompletion(
          sefariaRef: 'Berakhot.2b',
          eventTimestamp: DateTime.utc(2026, 1, 2),
        ),
        makeCompletion(
          sefariaRef: 'Berakhot.3a',
          eventTimestamp: DateTime.utc(2026, 1, 3),
        ),
      ]);

      final rows = await db.completionDao.getCompletionsByTrack(trackId);
      expect(rows, hasLength(3));
    });

    test('is a no-op when the list is empty', () async {
      await expectLater(seedCompletionsBatch(db, []), completes);

      final rows = await db.completionDao.getCompletionsByTrack(trackId);
      expect(rows, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getCompletionsByTrackAndProfile
  // ---------------------------------------------------------------------------

  group('CompletionDao.getCompletionsByTrackAndProfile', () {
    test('returns completions for the given track and profile', () async {
      await seedCompletion(db, makeCompletion());
      await seedCompletion(
        db,
        makeCompletion(
          sefariaRef: 'Shabbat.2a',
          completedAt: DateTime.utc(2026, 2, 1),
        ),
      );

      final rows = await db.completionDao.getCompletionsByTrackAndProfile(
        trackId,
        1,
      );
      expect(rows, hasLength(2));
    });

    test('is scoped to the given profile', () async {
      // Insert for profile 1 on trackId.
      await seedCompletion(db, makeCompletion(profileId: 1));

      // Insert a second track for profile 2.
      final track2 = await seedTrack(
        db,
        profileId: 2,
        curriculumId: 'bavli',
        activatedAt: DateTime.utc(2026, 1, 1),
      );
      await seedCompletion(
        db,
        makeCompletion(profileId: 2, overrideTrackId: track2),
      );

      final rows = await db.completionDao.getCompletionsByTrackAndProfile(
        trackId,
        1,
      );
      expect(rows, hasLength(1));
      expect(rows.first.profileId, 1);
    });

    test('returns empty list when no completions exist', () async {
      final rows = await db.completionDao.getCompletionsByTrackAndProfile(
        trackId,
        1,
      );
      expect(rows, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getAggregateCountByTrack
  // ---------------------------------------------------------------------------

  group('CompletionDao.getAggregateCountByTrack', () {
    test('returns 0 when no completions exist', () async {
      final count = await db.completionDao.getAggregateCountByTrack(trackId, 1);
      expect(count, 0);
    });

    test('counts all completions for the given track and profile', () async {
      await seedCompletion(
        db,
        makeCompletion(
          sefariaRef: 'Berakhot.2a',
          completedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await seedCompletion(
        db,
        makeCompletion(
          sefariaRef: 'Berakhot.2b',
          completedAt: DateTime.utc(2026, 1, 2),
        ),
      );

      final count = await db.completionDao.getAggregateCountByTrack(trackId, 1);
      expect(count, 2);
    });

    test('is scoped to the given profile', () async {
      final track2 = await seedTrack(
        db,
        profileId: 2,
        curriculumId: 'bavli',
        activatedAt: DateTime.utc(2026, 1, 1),
      );
      await seedCompletion(db, makeCompletion(profileId: 1));
      await seedCompletion(
        db,
        makeCompletion(profileId: 2, overrideTrackId: track2),
      );

      expect(await db.completionDao.getAggregateCountByTrack(trackId, 1), 1);
    });
  });

  // ---------------------------------------------------------------------------
  // completionExistsByTrack
  // ---------------------------------------------------------------------------

  group('CompletionDao.completionExistsByTrack', () {
    test('returns true when a matching completion exists', () async {
      final completedAt = DateTime.utc(2026, 3, 10);
      await seedCompletion(
        db,
        makeCompletion(stageId: 2, completedAt: completedAt),
      );

      final exists = await db.completionDao.completionExistsByTrack(
        trackId: trackId,
        curriculumId: 'bavli',
        sefariaRef: 'Berakhot.2a',
        stageId: 2,
        completedAt: completedAt,
      );
      expect(exists, isTrue);
    });

    test('returns false when no matching completion exists', () async {
      final exists = await db.completionDao.completionExistsByTrack(
        trackId: trackId,
        curriculumId: 'bavli',
        sefariaRef: 'Berakhot.2a',
        stageId: 1,
        completedAt: DateTime.utc(2026, 1, 1),
      );
      expect(exists, isFalse);
    });

    test('returns false when stageId does not match', () async {
      final completedAt = DateTime.utc(2026, 3, 10);
      await seedCompletion(
        db,
        makeCompletion(stageId: 1, completedAt: completedAt),
      );

      final exists = await db.completionDao.completionExistsByTrack(
        trackId: trackId,
        curriculumId: 'bavli',
        sefariaRef: 'Berakhot.2a',
        stageId: 99, // different stage
        completedAt: completedAt,
      );
      expect(exists, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // getCompletionsByDateRangeAndTrack
  // ---------------------------------------------------------------------------

  group('CompletionDao.getCompletionsByDateRangeAndTrack', () {
    test('returns completions within the date range', () async {
      await seedCompletion(
        db,
        makeCompletion(
          sefariaRef: 'Berakhot.2a',
          completedAt: DateTime.utc(2026, 3, 5),
        ),
      );
      await seedCompletion(
        db,
        makeCompletion(
          sefariaRef: 'Berakhot.2b',
          completedAt: DateTime.utc(2026, 3, 15),
        ),
      );
      await seedCompletion(
        db,
        makeCompletion(
          sefariaRef: 'Berakhot.3a',
          completedAt: DateTime.utc(2026, 4, 1),
        ),
      );

      final rows = await db.completionDao.getCompletionsByDateRangeAndTrack(
        DateTime.utc(2026, 3, 1),
        DateTime.utc(2026, 3, 31),
        trackId,
        1,
      );
      expect(rows, hasLength(2));
      expect(
        rows.map((r) => r.sefariaRef),
        containsAll(['Berakhot.2a', 'Berakhot.2b']),
      );
    });

    test('returns empty list when no completions fall in range', () async {
      await seedCompletion(
        db,
        makeCompletion(completedAt: DateTime.utc(2025, 12, 31)),
      );

      final rows = await db.completionDao.getCompletionsByDateRangeAndTrack(
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 12, 31),
        trackId,
        1,
      );
      expect(rows, isEmpty);
    });

    test('is scoped to the given track', () async {
      // Use a different curriculumId to avoid the (profileId, curriculumId)
      // unique constraint — the setUp already created (1, 'bavli').
      final other = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
        activatedAt: DateTime.utc(2026, 1, 1),
      );

      await seedCompletion(
        db,
        makeCompletion(
          completedAt: DateTime.utc(2026, 3, 10),
          overrideTrackId: other,
        ),
      );

      final rows = await db.completionDao.getCompletionsByDateRangeAndTrack(
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 12, 31),
        trackId, // different track
        1,
      );
      expect(rows, isEmpty);
    });
  });
}
