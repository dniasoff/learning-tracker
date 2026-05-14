// Extra coverage for CompletionDao — insertCompletionsBatch,
// getCompletionsByTrackAndProfile, getAggregateCountByTrack,
// completionExistsByTrack, and getCompletionsByDateRangeAndTrack were not
// exercised by the baseline test.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            trackType: 'personal',
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  CompletionsCompanion makeCompletion({
    int profileId = 1,
    String curriculumId = 'bavli',
    String sefariaRef = 'Berakhot.2a',
    int stageId = 1,
    String trackType = 'personal',
    DateTime? completedAt,
    int? overrideTrackId,
  }) {
    return CompletionsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: trackType,
      trackId: overrideTrackId ?? trackId,
      completedAt: completedAt ?? DateTime.utc(2026, 1, 1),
    );
  }

  // ---------------------------------------------------------------------------
  // insertCompletionsBatch
  // ---------------------------------------------------------------------------

  group('CompletionDao.insertCompletionsBatch', () {
    test('inserts multiple completions in a single batch', () async {
      await db.completionDao.insertCompletionsBatch([
        makeCompletion(
          sefariaRef: 'Berakhot.2a',
          completedAt: DateTime.utc(2026, 1, 1),
        ),
        makeCompletion(
          sefariaRef: 'Berakhot.2b',
          completedAt: DateTime.utc(2026, 1, 2),
        ),
        makeCompletion(
          sefariaRef: 'Berakhot.3a',
          completedAt: DateTime.utc(2026, 1, 3),
        ),
      ]);

      final rows = await db.completionDao.getCompletionsByTrack(trackId);
      expect(rows, hasLength(3));
    });

    test('is a no-op when the list is empty', () async {
      await expectLater(db.completionDao.insertCompletionsBatch([]), completes);

      final rows = await db.completionDao.getCompletionsByTrack(trackId);
      expect(rows, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getCompletionsByTrackAndProfile
  // ---------------------------------------------------------------------------

  group('CompletionDao.getCompletionsByTrackAndProfile', () {
    test('returns completions for the given track and profile', () async {
      await db.completionDao.insertCompletion(makeCompletion());
      await db.completionDao.insertCompletion(
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
      await db.completionDao.insertCompletion(makeCompletion(profileId: 1));

      // Insert a second track for profile 2.
      final track2 = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 2,
              curriculumId: 'bavli',
              trackType: 'personal',
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await db.completionDao.insertCompletion(
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
      await db.completionDao.insertCompletion(
        makeCompletion(
          sefariaRef: 'Berakhot.2a',
          completedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await db.completionDao.insertCompletion(
        makeCompletion(
          sefariaRef: 'Berakhot.2b',
          completedAt: DateTime.utc(2026, 1, 2),
        ),
      );

      final count = await db.completionDao.getAggregateCountByTrack(trackId, 1);
      expect(count, 2);
    });

    test('is scoped to the given profile', () async {
      final track2 = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 2,
              curriculumId: 'bavli',
              trackType: 'personal',
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await db.completionDao.insertCompletion(makeCompletion(profileId: 1));
      await db.completionDao.insertCompletion(
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
      await db.completionDao.insertCompletion(
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
      await db.completionDao.insertCompletion(
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
      await db.completionDao.insertCompletion(
        makeCompletion(
          sefariaRef: 'Berakhot.2a',
          completedAt: DateTime.utc(2026, 3, 5),
        ),
      );
      await db.completionDao.insertCompletion(
        makeCompletion(
          sefariaRef: 'Berakhot.2b',
          completedAt: DateTime.utc(2026, 3, 15),
        ),
      );
      await db.completionDao.insertCompletion(
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
      await db.completionDao.insertCompletion(
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
      final other = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              trackType: 'amud',
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await db.completionDao.insertCompletion(
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
