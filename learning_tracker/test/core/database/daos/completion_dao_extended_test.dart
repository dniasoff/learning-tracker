/// Extended tests for [CompletionDao] covering batch operations.
///
/// Covers:
///  - insertCompletionsBatch: empty list (no-op), single item, multiple items
///  - getExistingSefariaRefsForBulkStage: empty refs, existing refs, non-existent
///  - getCompletionsForRefsBulkStage
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ─── Helper ───────────────────────────────────────────────────────────────

  CompletionsCompanion makeCompletion({
    required String ref,
    int profileId = 1,
    String curriculumId = 'mishnayos',
    int stageId = 1,
    String trackType = 'personal',
    int trackId = 1,
    DateTime? completedAt,
  }) => CompletionsCompanion.insert(
    profileId: profileId,
    curriculumId: curriculumId,
    sefariaRef: ref,
    stageId: stageId,
    trackType: trackType,
    trackId: trackId,
    completedAt: completedAt ?? DateTime.utc(2026, 3, 15),
    points: const Value(10),
  );

  // ─── insertCompletionsBatch ───────────────────────────────────────────────

  group('insertCompletionsBatch', () {
    test('does nothing for empty list (no-op)', () async {
      await db.completionDao.insertCompletionsBatch([]);
      final all = await db.completionDao.getCompletionsByProfile(1);
      expect(all, isEmpty);
    });

    test('inserts a single completion via batch', () async {
      await db.completionDao.insertCompletionsBatch([makeCompletion(ref: 'Berakhot.1.1')]);
      final all = await db.completionDao.getCompletionsByProfile(1);
      expect(all, hasLength(1));
      expect(all.first.sefariaRef, 'Berakhot.1.1');
    });

    test('inserts multiple completions in a single batch', () async {
      await db.completionDao.insertCompletionsBatch([
        makeCompletion(ref: 'Berakhot.1.1'),
        makeCompletion(ref: 'Berakhot.1.2'),
        makeCompletion(ref: 'Berakhot.1.3'),
      ]);
      final all = await db.completionDao.getCompletionsByProfile(1);
      expect(all, hasLength(3));
      final refs = all.map((c) => c.sefariaRef).toSet();
      expect(refs, containsAll(['Berakhot.1.1', 'Berakhot.1.2', 'Berakhot.1.3']));
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
      // Insert one completion.
      await db.completionDao.insertCompletion(makeCompletion(ref: 'Berakhot.1.1'));

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
      await db.completionDao.insertCompletionsBatch([
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

    test('filters by profileId — does not return other profiles completions', () async {
      // Profile 2's completion
      await db.completionDao.insertCompletion(makeCompletion(ref: 'Berakhot.1.1', profileId: 2));

      final result = await db.completionDao.getExistingSefariaRefsForBulkStage(
        profileId: 1, // querying profile 1
        curriculumId: 'mishnayos',
        stageId: 1,
        trackType: 'personal',
        sefariaRefs: ['Berakhot.1.1'],
      );
      expect(result, isEmpty);
    });

    test('filters by curriculumId', () async {
      await db.completionDao.insertCompletion(
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
      await db.completionDao.insertCompletion(makeCompletion(ref: 'Berakhot.1.1'));
      await db.completionDao.insertCompletion(makeCompletion(ref: 'Berakhot.1.2'));
      // This ref is not in the query list.
      await db.completionDao.insertCompletion(makeCompletion(ref: 'Berakhot.1.3'));

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
}
