/// Extended tests for [CompletionDao] covering batch operations and track-scoped
/// query methods not exercised by completion_dao_test.dart:
///  - insertCompletionsBatch: empty list (no-op), single item, multiple items
///  - getExistingSefariaRefsForBulkStage: empty refs, existing refs, non-existent
///  - getCompletionsForRefsBulkStage
///  - getCompletionsByTrack / getCompletionsByTrackAndProfile
///  - getAggregateCountByTrack
///  - completionExistsByTrack
///  - getCompletionsByDateRangeAndTrack
///  - getReviewCountsByItemAndTrack
///  - getStageBreakdownByItemAndTrack
///  - hasCompletionsForStage
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

// Helper to build a minimal CompletionEventsCompanion (F1 style).
CompletionEventsCompanion _completion({
  int profileId = 1,
  String curriculumId = 'bavli',
  String sefariaRef = 'Berakhot.2a',
  int stageId = 1,
  String trackType = 'personal',
  int trackId = 10,
  DateTime? completedAt,
}) => CompletionEventsCompanion.insert(
  profileId: profileId,
  curriculumId: curriculumId,
  sefariaRef: sefariaRef,
  stageId: stageId,
  trackType: trackType,
  trackId: Value(trackId),
  eventTimestamp: completedAt ?? DateTime.utc(2026, 5, 14),
);

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    // Seed a second learner profile (profileId = 2) for cross-profile tests.
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion(
            id: const Value(2),
            email: const Value('test2@example.com'),
            tier: const Value('localBorn'),
            displayName: const Value('Test User 2'),
            createdAt: Value(DateTime.utc(2026, 1, 1)),
            updatedAt: Value(DateTime.utc(2026, 1, 1)),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await db
        .into(db.learnerProfiles)
        .insert(
          LearnerProfilesCompanion(
            id: const Value(2),
            accountId: const Value(2),
            displayName: const Value('Test User 2'),
            mode: const Value('adult'),
            createdAt: Value(DateTime.utc(2026, 1, 1)),
            updatedAt: Value(DateTime.utc(2026, 1, 1)),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    // Seed curriculum_tracks with the explicit IDs used across all tests.
    // Each must have a distinct (profileId, curriculumId, trackType) tuple
    // due to the unique constraint on curriculum_tracks.
    final trackSeeds = [
      (id: 1, curriculum: 'mishnayos'),
      (id: 5, curriculum: 'bavli_5'),
      (id: 7, curriculum: 'bavli_7'),
      (id: 10, curriculum: 'bavli'),
      (id: 20, curriculum: 'bavli_20'),
    ];
    for (final seed in trackSeeds) {
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion(
              id: Value(seed.id),
              profileId: const Value(1),
              curriculumId: Value(seed.curriculum),
              stateChangedAt: Value(DateTime.utc(2026, 1, 1)),
              activatedAt: Value(DateTime.utc(2026, 1, 1)),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  // ─── Helper ───────────────────────────────────────────────────────────────

  CompletionEventsCompanion makeCompletion({
    required String ref,
    int profileId = 1,
    String curriculumId = 'mishnayos',
    int stageId = 1,
    String trackType = 'personal',
    int trackId = 1,
    DateTime? completedAt,
  }) => CompletionEventsCompanion.insert(
    profileId: profileId,
    curriculumId: curriculumId,
    sefariaRef: ref,
    stageId: stageId,
    trackType: trackType,
    trackId: Value(trackId),
    eventTimestamp: completedAt ?? DateTime.utc(2026, 3, 15),
    points: const Value(10),
  );

  // ─── insertCompletionsBatch ───────────────────────────────────────────────

  group('insertCompletionsBatch', () {
    test('does nothing for empty list (no-op)', () async {
      await seedCompletionsBatch(db, []);
      final all = await db.completionDao.getCompletionsByProfile(1);
      expect(all, isEmpty);
    });

    test('inserts a single completion via batch', () async {
      await seedCompletionsBatch(db, [makeCompletion(ref: 'Berakhot.1.1')]);
      final all = await db.completionDao.getCompletionsByProfile(1);
      expect(all, hasLength(1));
      expect(all.first.sefariaRef, 'Berakhot.1.1');
    });

    test('inserts multiple completions in a single batch', () async {
      await seedCompletionsBatch(db, [
        makeCompletion(ref: 'Berakhot.1.1'),
        makeCompletion(ref: 'Berakhot.1.2'),
        makeCompletion(ref: 'Berakhot.1.3'),
      ]);
      final all = await db.completionDao.getCompletionsByProfile(1);
      expect(all, hasLength(3));
      final refs = all.map((c) => c.sefariaRef).toSet();
      expect(
        refs,
        containsAll(['Berakhot.1.1', 'Berakhot.1.2', 'Berakhot.1.3']),
      );
    });
  });

  group('CompletionDao.insertCompletionsBatch', () {
    test('inserts multiple completions in one call', () async {
      await seedCompletionsBatch(db, [
        _completion(sefariaRef: 'Berakhot.2a'),
        _completion(sefariaRef: 'Berakhot.2b'),
        _completion(sefariaRef: 'Berakhot.3a'),
      ]);

      final all = await db.completionDao.getCompletionsByTrack(10);
      expect(all, hasLength(3));
    });

    test('is a no-op for empty list', () async {
      await seedCompletionsBatch(db, []);
      final all = await db.completionDao.getCompletionsByTrack(10);
      expect(all, isEmpty);
    });
  });

  // ─── getExistingSefariaRefsForBulkStage ───────────────────────────────────

  group('getExistingSefariaRefsForBulkStage', () {
    test('returns empty set for empty input list', () async {
      final result = await db.completionDao.getExistingSefariaRefsForBulkStage(
        profileId: 1,
        curriculumId: 'mishnayos',
        stageId: 1,
        trackType: 'personal',
        sefariaRefs: [],
      );
      expect(result, isEmpty);
    });

    test('returns empty set when no completions exist', () async {
      final result = await db.completionDao.getExistingSefariaRefsForBulkStage(
        profileId: 1,
        curriculumId: 'mishnayos',
        stageId: 1,
        trackType: 'personal',
        sefariaRefs: ['Berakhot.1.1', 'Berakhot.1.2'],
      );
      expect(result, isEmpty);
    });

    test('returns only the refs that have existing completions', () async {
      await seedCompletion(db, makeCompletion(ref: 'Berakhot.1.1'));

      final result = await db.completionDao.getExistingSefariaRefsForBulkStage(
        profileId: 1,
        curriculumId: 'mishnayos',
        stageId: 1,
        trackType: 'personal',
        sefariaRefs: ['Berakhot.1.1', 'Berakhot.1.2', 'Berakhot.1.3'],
      );
      expect(result, {'Berakhot.1.1'});
    });

    test('returns all refs when all have completions', () async {
      await seedCompletionsBatch(db, [
        makeCompletion(ref: 'Berakhot.1.1'),
        makeCompletion(ref: 'Berakhot.1.2'),
      ]);

      final result = await db.completionDao.getExistingSefariaRefsForBulkStage(
        profileId: 1,
        curriculumId: 'mishnayos',
        stageId: 1,
        trackType: 'personal',
        sefariaRefs: ['Berakhot.1.1', 'Berakhot.1.2'],
      );
      expect(result, {'Berakhot.1.1', 'Berakhot.1.2'});
    });

    test(
      'filters by profileId — does not return other profiles completions',
      () async {
        await seedCompletion(
          db,
          makeCompletion(ref: 'Berakhot.1.1', profileId: 2),
        );

        final result = await db.completionDao
            .getExistingSefariaRefsForBulkStage(
              profileId: 1, // querying profile 1
              curriculumId: 'mishnayos',
              stageId: 1,
              trackType: 'personal',
              sefariaRefs: ['Berakhot.1.1'],
            );
        expect(result, isEmpty);
      },
    );

    test('filters by curriculumId', () async {
      await seedCompletion(
        db,
        makeCompletion(ref: 'Berakhot.2a', curriculumId: 'bavli'),
      );

      final result = await db.completionDao.getExistingSefariaRefsForBulkStage(
        profileId: 1,
        curriculumId: 'mishnayos', // different curriculum
        stageId: 1,
        trackType: 'personal',
        sefariaRefs: ['Berakhot.2a'],
      );
      expect(result, isEmpty);
    });
  });

  // ─── getCompletionsForRefsBulkStage ──────────────────────────────────────

  group('getCompletionsForRefsBulkStage', () {
    test('returns empty list for empty refs', () async {
      final result = await db.completionDao.getCompletionsForRefsBulkStage(
        profileId: 1,
        curriculumId: 'mishnayos',
        stageId: 1,
        trackType: 'personal',
        sefariaRefs: [],
      );
      expect(result, isEmpty);
    });

    test('returns matching completions', () async {
      await seedCompletion(db, makeCompletion(ref: 'Berakhot.1.1'));
      await seedCompletion(db, makeCompletion(ref: 'Berakhot.1.2'));
      // This ref is not in the query list.
      await seedCompletion(db, makeCompletion(ref: 'Berakhot.1.3'));

      final result = await db.completionDao.getCompletionsForRefsBulkStage(
        profileId: 1,
        curriculumId: 'mishnayos',
        stageId: 1,
        trackType: 'personal',
        sefariaRefs: ['Berakhot.1.1', 'Berakhot.1.2'],
      );
      expect(result, hasLength(2));
      final refs = result.map((c) => c.sefariaRef).toSet();
      expect(refs, {'Berakhot.1.1', 'Berakhot.1.2'});
    });
  });

  // ─── getCompletionsByTrack ────────────────────────────────────────────────

  group('CompletionDao.getCompletionsByTrack', () {
    test('returns only completions for the specified track', () async {
      await seedCompletion(db, _completion(trackId: 10, sefariaRef: 'A.1'));
      await seedCompletion(db, _completion(trackId: 20, sefariaRef: 'B.1'));

      final forTrack10 = await db.completionDao.getCompletionsByTrack(10);
      expect(forTrack10, hasLength(1));
      expect(forTrack10.first.sefariaRef, 'A.1');
    });

    test('returns empty list when no completions for track', () async {
      final result = await db.completionDao.getCompletionsByTrack(999);
      expect(result, isEmpty);
    });
  });

  group('CompletionDao.getCompletionsByTrackAndProfile', () {
    test('scopes by both trackId and profileId', () async {
      await seedCompletion(
        db,
        _completion(trackId: 10, profileId: 1, sefariaRef: 'A.1'),
      );
      await seedCompletion(
        db,
        _completion(trackId: 10, profileId: 2, sefariaRef: 'B.1'),
      );

      final profile1 = await db.completionDao.getCompletionsByTrackAndProfile(
        10,
        1,
      );
      expect(profile1, hasLength(1));
      expect(profile1.first.sefariaRef, 'A.1');
    });
  });

  group('CompletionDao.getAggregateCountByTrack', () {
    test('returns count of completions for track+profile', () async {
      await seedCompletion(
        db,
        _completion(trackId: 5, profileId: 1, sefariaRef: 'A.1'),
      );
      await seedCompletion(
        db,
        _completion(trackId: 5, profileId: 1, sefariaRef: 'A.2'),
      );
      await seedCompletion(
        db,
        _completion(trackId: 5, profileId: 2, sefariaRef: 'A.3'),
      );

      expect(await db.completionDao.getAggregateCountByTrack(5, 1), 2);
      expect(await db.completionDao.getAggregateCountByTrack(5, 2), 1);
    });

    test('returns 0 when no completions for track', () async {
      expect(await db.completionDao.getAggregateCountByTrack(999, 1), 0);
    });
  });

  group('CompletionDao.completionExistsByTrack', () {
    test('returns true when matching completion exists', () async {
      final at = DateTime.utc(2026, 5, 14);
      await seedCompletion(
        db,
        _completion(
          trackId: 7,
          curriculumId: 'bavli',
          sefariaRef: 'X.1',
          stageId: 1,
          completedAt: at,
        ),
      );

      final exists = await db.completionDao.completionExistsByTrack(
        trackId: 7,
        curriculumId: 'bavli',
        sefariaRef: 'X.1',
        stageId: 1,
        completedAt: at,
      );
      expect(exists, isTrue);
    });

    test('returns false when no matching completion', () async {
      final exists = await db.completionDao.completionExistsByTrack(
        trackId: 7,
        curriculumId: 'bavli',
        sefariaRef: 'Z.1',
        stageId: 1,
        completedAt: DateTime.utc(2026, 5, 14),
      );
      expect(exists, isFalse);
    });
  });

  group('CompletionDao.getCompletionsByDateRangeAndTrack', () {
    test('returns completions within the date range', () async {
      final early = DateTime.utc(2026, 1, 1);
      final mid = DateTime.utc(2026, 5, 14);
      final late = DateTime.utc(2026, 12, 31);

      await seedCompletion(
        db,
        _completion(
          trackId: 10,
          profileId: 1,
          sefariaRef: 'A.1',
          completedAt: early,
        ),
      );
      await seedCompletion(
        db,
        _completion(
          trackId: 10,
          profileId: 1,
          sefariaRef: 'A.2',
          completedAt: mid,
        ),
      );
      await seedCompletion(
        db,
        _completion(
          trackId: 10,
          profileId: 1,
          sefariaRef: 'A.3',
          completedAt: late,
        ),
      );

      final inRange = await db.completionDao.getCompletionsByDateRangeAndTrack(
        early,
        mid,
        10,
        1,
      );
      expect(inRange, hasLength(2));
    });

    test('returns empty list when no completions in range', () async {
      final result = await db.completionDao.getCompletionsByDateRangeAndTrack(
        DateTime.utc(2020, 1, 1),
        DateTime.utc(2020, 12, 31),
        10,
        1,
      );
      expect(result, isEmpty);
    });
  });

  group('CompletionDao.getReviewCountsByItemAndTrack', () {
    test('returns count per sefariaRef for the track', () async {
      // 2 completions for A.1, 1 for A.2
      await seedCompletion(
        db,
        _completion(trackId: 10, profileId: 1, sefariaRef: 'A.1', stageId: 1),
      );
      await seedCompletion(
        db,
        _completion(trackId: 10, profileId: 1, sefariaRef: 'A.1', stageId: 2),
      );
      await seedCompletion(
        db,
        _completion(trackId: 10, profileId: 1, sefariaRef: 'A.2', stageId: 1),
      );

      final counts = await db.completionDao.getReviewCountsByItemAndTrack(
        10,
        'bavli',
        1,
      );
      expect(counts['A.1'], 2);
      expect(counts['A.2'], 1);
    });

    test('returns empty map when no completions', () async {
      final counts = await db.completionDao.getReviewCountsByItemAndTrack(
        999,
        'bavli',
        1,
      );
      expect(counts, isEmpty);
    });
  });

  group('CompletionDao.getStageBreakdownByItemAndTrack', () {
    test('returns count per stageId for the specific item', () async {
      await seedCompletion(
        db,
        _completion(trackId: 10, profileId: 1, sefariaRef: 'B.1', stageId: 1),
      );
      await seedCompletion(
        db,
        _completion(trackId: 10, profileId: 1, sefariaRef: 'B.1', stageId: 2),
      );
      await seedCompletion(
        db,
        _completion(trackId: 10, profileId: 1, sefariaRef: 'B.1', stageId: 2),
      );

      final breakdown = await db.completionDao.getStageBreakdownByItemAndTrack(
        10,
        'bavli',
        'B.1',
        1,
      );
      expect(breakdown[1], 1);
      // UNIQUE constraint on completion_events deduplicates the two stageId=2 inserts
      expect(breakdown[2], 1);
    });

    test('returns empty map when no completions for item', () async {
      final breakdown = await db.completionDao.getStageBreakdownByItemAndTrack(
        10,
        'bavli',
        'NONEXISTENT',
        1,
      );
      expect(breakdown, isEmpty);
    });
  });

  group('CompletionDao.hasCompletionsForStage', () {
    test('returns true when completions exist for the stage', () async {
      await seedCompletion(db, _completion(stageId: 42));
      expect(await db.completionDao.hasCompletionsForStage(42), isTrue);
    });

    test('returns false when no completions for the stage', () async {
      expect(await db.completionDao.hasCompletionsForStage(999), isFalse);
    });
  });
}
