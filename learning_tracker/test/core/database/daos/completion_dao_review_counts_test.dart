// Tests for CompletionDao methods not covered by the baseline tests:
//   - getReviewCountsByItemAndTrack
//   - getStageBreakdownByItemAndTrack
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int trackId;
  late int stageId;

  const profileId = 1;
  const curriculumId = 'mishnayos';

  setUp(() async {
    db = inMemoryDb();

    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            trackType: 'personal',
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );

    stageId = await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'Learn',
        delayDays: 0,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertCompletion({
    required String sefariaRef,
    int? stageIdOverride,
    DateTime? completedAt,
  }) async {
    await db.completionDao.insertCompletion(
      CompletionsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: stageIdOverride ?? stageId,
        trackType: 'personal',
        trackId: trackId,
        completedAt: completedAt ?? DateTime.utc(2026, 3, 15),
        points: const Value(10),
      ),
    );
  }

  // =========================================================================
  // getReviewCountsByItemAndTrack
  // =========================================================================

  group('CompletionDao.getReviewCountsByItemAndTrack', () {
    test('returns empty map when no completions exist', () async {
      final counts = await db.completionDao.getReviewCountsByItemAndTrack(
        trackId,
        curriculumId,
        profileId,
      );
      expect(counts, isEmpty);
    });

    test('counts completions per sefariaRef', () async {
      await insertCompletion(sefariaRef: 'Berakhot 1:1');
      await insertCompletion(sefariaRef: 'Berakhot 1:1'); // second review
      await insertCompletion(sefariaRef: 'Berakhot 1:2');

      final counts = await db.completionDao.getReviewCountsByItemAndTrack(
        trackId,
        curriculumId,
        profileId,
      );

      expect(counts['Berakhot 1:1'], 2);
      expect(counts['Berakhot 1:2'], 1);
    });

    test('filters to correct trackId', () async {
      // Create a second track.
      final otherTrackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: 'bavli',
              trackType: 'personal',
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      final otherStageId = await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: 'bavli',
          trackId: otherTrackId,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
      );

      // Insert into our track.
      await insertCompletion(sefariaRef: 'ref_A');

      // Insert into the other track.
      await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          profileId: profileId,
          curriculumId: 'bavli',
          sefariaRef: 'ref_B',
          stageId: otherStageId,
          trackType: 'personal',
          trackId: otherTrackId,
          completedAt: DateTime.utc(2026, 3, 15),
          points: const Value(10),
        ),
      );

      final counts = await db.completionDao.getReviewCountsByItemAndTrack(
        trackId,
        curriculumId,
        profileId,
      );

      expect(counts.containsKey('ref_A'), isTrue);
      expect(counts.containsKey('ref_B'), isFalse);
    });

    test('filters to correct profileId', () async {
      await insertCompletion(sefariaRef: 'ref_A');

      // Query for a different profile — should return empty.
      final counts = await db.completionDao.getReviewCountsByItemAndTrack(
        trackId,
        curriculumId,
        999, // wrong profile
      );

      expect(counts, isEmpty);
    });
  });

  // =========================================================================
  // getStageBreakdownByItemAndTrack
  // =========================================================================

  group('CompletionDao.getStageBreakdownByItemAndTrack', () {
    test('returns empty map when no completions exist', () async {
      final breakdown = await db.completionDao.getStageBreakdownByItemAndTrack(
        trackId,
        curriculumId,
        'Berakhot 1:1',
        profileId,
      );
      expect(breakdown, isEmpty);
    });

    test('counts completions per stage for a given ref', () async {
      // Add a second stage.
      final stage2Id = await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
        ),
      );

      await insertCompletion(sefariaRef: 'Berakhot 1:1'); // stage 1
      await insertCompletion(sefariaRef: 'Berakhot 1:1'); // stage 1 again
      await insertCompletion(
        sefariaRef: 'Berakhot 1:1',
        stageIdOverride: stage2Id,
      ); // stage 2

      final breakdown = await db.completionDao.getStageBreakdownByItemAndTrack(
        trackId,
        curriculumId,
        'Berakhot 1:1',
        profileId,
      );

      expect(breakdown[stageId], 2); // 2 completions at stage 1
      expect(breakdown[stage2Id], 1); // 1 completion at stage 2
    });

    test('only includes completions for the specified sefariaRef', () async {
      await insertCompletion(sefariaRef: 'Berakhot 1:1');
      await insertCompletion(sefariaRef: 'Berakhot 1:2'); // different ref

      final breakdown = await db.completionDao.getStageBreakdownByItemAndTrack(
        trackId,
        curriculumId,
        'Berakhot 1:1',
        profileId,
      );

      expect(breakdown[stageId], 1);
      expect(breakdown.length, 1);
    });
  });
}
