/// AUD-core-sync-07: GoalMerger FK-race regression coverage.
///
/// Mirrors the "skip: track not yet synced" coverage already present for
/// bookmark/stage_definition/settings in drift_merge_store_test.dart. A goal
/// row referencing a curriculum_tracks row that has not synced locally yet
/// must be skipped, not thrown — `goals.trackId` FKs `curriculum_tracks(id)`,
/// and an uncaught FK violation would abort merging the whole page.
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/goal_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

const _profileId = 1;

Map<String, dynamic> _row({
  required String curriculumId,
  required int trackId,
  DateTime? updatedAt,
}) => {
  'curriculum_id': curriculumId,
  'track_id': trackId,
  'description': 'Daily 1 mishnah',
  'target_percent': 100.0,
  'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
  'updated_at': (updatedAt ?? DateTime.utc(2026, 5, 10)).toIso8601String(),
};

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('GoalMerger — FK-race guard (AUD-core-sync-07)', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late GoalMerger merger;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      merger = GoalMerger(db, store: store);
      await seedProfile(db);
    });

    tearDown(() async => db.close());

    test(
      'skip: track not yet synced (no FK throw) — no goal inserted',
      () async {
        // No curriculum_tracks row exists for 'tehillim'.
        await merger.merge(
          profileId: _profileId,
          rows: [_row(curriculumId: 'tehillim', trackId: 999999)],
        );

        final goal = await db.goalDao.getGoalByTrack(999999);
        expect(goal, isNull);
        expect(await db.goalDao.getAllGoals(), isEmpty);
      },
    );

    test('idempotent recovery: a goal skipped for a missing track applies once '
        'the track is seeded and the identical row is re-merged', () async {
      final row = _row(curriculumId: 'tehillim', trackId: 999999);

      // First merge: no local track for 'tehillim' yet — skipped.
      await merger.merge(profileId: _profileId, rows: [row]);
      expect(await db.goalDao.getAllGoals(), isEmpty);

      // Seed the track, then re-merge the identical row.
      final localTrackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: _profileId,
              curriculumId: 'tehillim',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await merger.merge(profileId: _profileId, rows: [row]);

      final goal = await db.goalDao.getGoalByTrack(localTrackId);
      expect(
        goal,
        isNotNull,
        reason: 'the row must apply once its track exists locally',
      );
      expect(goal!.curriculumId, 'tehillim');
    });

    test(
      'a valid row still merges when batched with a missing-track row',
      () async {
        // Seed a track for 'mishnayos' only.
        final validTrackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: _profileId,
                curriculumId: 'mishnayos',
                stateChangedAt: DateTime.utc(2026, 1, 1),
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );

        await merger.merge(
          profileId: _profileId,
          rows: [
            _row(curriculumId: 'tehillim', trackId: 999999), // missing track
            _row(curriculumId: 'mishnayos', trackId: validTrackId), // valid
          ],
        );

        final valid = await db.goalDao.getGoalByTrack(validTrackId);
        expect(
          valid,
          isNotNull,
          reason: 'one bad row must not block the rest of the batch',
        );
        expect(await db.goalDao.getGoalByTrack(999999), isNull);
      },
    );
  });
}
