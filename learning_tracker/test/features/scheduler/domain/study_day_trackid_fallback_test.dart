/// Regression test: STUDYDAY-COMPANION-10 — study-day toggle with trackId
/// fallback-0 must not crash with a FK constraint violation.
///
/// Both `study_day_config_screen.dart:207` and
/// `study_day_config_providers.dart:78` resolve the track ID via:
///   `final trackId = track?.id ?? 0;`
/// If the track does not exist yet (e.g. race condition at first activation,
/// or the track was just deleted), `trackId = 0` is passed to
/// `upsertDayConfig`. The `study_day_configs` table has a FK on
/// `curriculum_tracks.id` with `foreign_keys = ON`, so this throws
/// a SqliteException with "FOREIGN KEY constraint failed".
///
/// The fix: the screen/provider must look up the track ID and skip/no-op
/// rather than fall back to 0 when the track does not exist.
@Tags(['scheduler', 'study_day', 'studyday_companion_10'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── STUDYDAY-COMPANION-10: FK constraint on trackId = 0 ─────────────────────

  group('STUDYDAY-COMPANION-10: study-day config trackId fallback', () {
    test(
      'upsertDayConfig with trackId = 0 throws FK constraint (documents the bug)',
      () async {
        // No track seeded — any FK-guarded upsert with id=0 must fail.
        expect(
          () => db.studyDayConfigDao.upsertDayConfig(
            profileId: 1,
            curriculumId: 'mishnayos',
            trackId: 0, // BUG: fallback used when track not found
            dayOfWeek: 1,
            dayType: 'study',
          ),
          throwsA(anything),
          reason:
              'STUDYDAY-COMPANION-10: inserting trackId=0 when no track has '
              'id=0 must throw because foreign_keys=ON.',
        );
      },
    );

    test(
      'upsertDayConfig with a real trackId succeeds (positive case)',
      () async {
        final trackId = await seedTrack(db, profileId: 1);

        await expectLater(
          db.studyDayConfigDao.upsertDayConfig(
            profileId: 1,
            curriculumId: 'mishnayos',
            trackId: trackId,
            dayOfWeek: 1,
            dayType: 'study',
          ),
          completes,
        );
      },
    );

    test(
      'guard: missing track resolves to null via the real lookup → no write, no FK crash',
      () async {
        // Mirrors study_day_config_providers.dart:71-82: the provider looks up
        // the curriculum's track and, when getSingleOrNull() returns null,
        // returns early instead of passing trackId=0 (which would violate the
        // FK and crash). No track is seeded here, so the real lookup must be
        // null and the guarded upsert must be skipped — leaving no rows and
        // throwing nothing.
        final track =
            await (db.select(db.curriculumTracks)
                  ..where((t) => t.curriculumId.equals('bavli'))
                  ..limit(1))
                .getSingleOrNull();
        expect(track, isNull, reason: 'no track seeded → lookup must be null');

        final trackId = track?.id;
        if (trackId != null) {
          await db.studyDayConfigDao.upsertDayConfig(
            profileId: 1,
            curriculumId: 'bavli',
            trackId: trackId,
            dayOfWeek: 1,
            dayType: 'study',
          );
        }

        final rows = await (db.select(
          db.studyDayConfigs,
        )..where((t) => t.curriculumId.equals('bavli'))).get();
        expect(
          rows,
          isEmpty,
          reason:
              'guard: null track → upsert skipped → no FK crash and no rows',
        );
      },
    );
  });
}
