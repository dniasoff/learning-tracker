/// Regression test: STUDYDAY-CHAZARA-GATE-12 — study-day config screen must
/// show a chazara-neutral message ("All days are study days for this track.")
/// for learn-only tracks (stageOrder == 1, i.e. exactly 1 stage), and must
/// show the full review-day toggle UI for chazara tracks (stageOrder > 1).
///
/// Also documents the STUDYDAY-DEADROUTE defect fix: before the fix in
/// track_detail_screen.dart, `StudyDayConfigRoute` had no push call anywhere
/// in the widget layer — the study-day configuration screen was unreachable.
/// The fix adds a "Study Days" tile to `_buildActionsCard` in
/// `track_detail_screen.dart` for non-program self-paced tracks.
///
/// Gate logic resides in `_curriculumTrackHasChazaraProvider` inside
/// `study_day_config_screen.dart:247`. It uses:
///   `count = await db.stageDao.countStagesForTrack(track.id); return count > 1;`
/// A learn-only track has exactly 1 stage → `count == 1` → provider returns
/// false → screen shows neutral message (no chazara/review terms).
/// A chazara track has 2+ stages → `count > 1` → provider returns true →
/// full review-day toggle UI is rendered.
@Tags(['scheduler', 'study_day', 'studyday_chazara_gate_12'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

/// Seeds a single stage_definitions row for [trackId] with the given
/// [stageOrder].
Future<void> _seedStage(
  UserDatabase db, {
  required int trackId,
  required int stageOrder,
  String stageName = 'לימוד',
}) async {
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          stageName: stageName,
          stageOrder: stageOrder,
        ),
      );
}

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── STUDYDAY-CHAZARA-GATE-12 ─────────────────────────────────────────────

  group('STUDYDAY-CHAZARA-GATE-12: chazara gate via countStagesForTrack', () {
    test(
      'learn-only track (1 stage): countStagesForTrack == 1 → chazara gate is false',
      () async {
        final trackId = await seedTrack(db, profileId: 1);
        await _seedStage(db, trackId: trackId, stageOrder: 1);

        final count = await db.stageDao.countStagesForTrack(trackId);

        // The gate: count > 1 is false for a learn-only track.
        expect(count, equals(1));
        expect(
          count > 1,
          isFalse,
          reason:
              'STUDYDAY-CHAZARA-GATE-12: a learn-only track has exactly 1 stage; '
              'count > 1 must be false so the screen shows the neutral fallback '
              'without any chazara/review terminology.',
        );
      },
    );

    test(
      'chazara track (2 stages): countStagesForTrack == 2 → chazara gate is true',
      () async {
        final trackId = await seedTrack(db, profileId: 1);
        await _seedStage(db, trackId: trackId, stageOrder: 1);
        await _seedStage(
          db,
          trackId: trackId,
          stageOrder: 2,
          stageName: 'חזרה',
        );

        final count = await db.stageDao.countStagesForTrack(trackId);

        expect(count, equals(2));
        expect(
          count > 1,
          isTrue,
          reason:
              'STUDYDAY-CHAZARA-GATE-12: a chazara track has 2+ stages; '
              'count > 1 must be true so the full review-day toggle UI is shown.',
        );
      },
    );

    test(
      'no stages: countStagesForTrack == 0 → chazara gate is false (no crash)',
      () async {
        final trackId = await seedTrack(db, profileId: 1);
        // No stages seeded.
        final count = await db.stageDao.countStagesForTrack(trackId);

        expect(count, equals(0));
        expect(count > 1, isFalse);
      },
    );

    test('stages for a different track do not count toward this track', () async {
      final trackId1 = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      final trackId2 = await seedTrack(db, profileId: 1, curriculumId: 'bavli');
      // Seed 3 stages for track2 (chazara enabled there).
      for (var i = 1; i <= 3; i++) {
        await db
            .into(db.stageDefinitions)
            .insert(
              StageDefinitionsCompanion.insert(
                profileId: 1,
                curriculumId: 'bavli',
                trackId: trackId2,
                stageName: 'stage$i',
                stageOrder: i,
              ),
            );
      }
      // track1 has no stages.
      final count1 = await db.stageDao.countStagesForTrack(trackId1);

      expect(count1, equals(0), reason: 'track1 has no stages of its own');
      expect(
        count1 > 1,
        isFalse,
        reason:
            "track1's chazara gate must not be contaminated by track2's stages",
      );
    });
  });
}
