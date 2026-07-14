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
/// AUD-t-scheduler-02: this file drives the real gate provider —
/// `curriculumTrackHasChazaraProvider` in `study_day_config_screen.dart` —
/// through a `ProviderContainer`, rather than re-deriving `count > 1` inline.
/// The provider was made package-visible (dropped its leading underscore)
/// specifically so this file can import and exercise it directly. If a
/// future edit changes the private threshold (e.g. `count > 1` to
/// `count >= 1`) or reintroduces `track?.id ?? 0`, these tests fail.
@Tags(['scheduler', 'study_day', 'studyday_chazara_gate_12'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/study_day_config_screen.dart';

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

/// Overrides [ActiveProfileId] to always resolve to profile 1, matching
/// [seedProfile]'s seeded profile.
class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 1;
}

/// Builds a [ProviderContainer] wired to [db] with the active profile
/// pinned to 1, so `curriculumTrackHasChazaraProvider` reads real DB state.
ProviderContainer _buildContainer(UserDatabase db) => ProviderContainer.test(
  overrides: [
    userDatabaseProvider.overrideWithValue(db),
    activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
  ],
);

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

  group('STUDYDAY-CHAZARA-GATE-12: chazara gate via the real gate provider', () {
    test(
      'learn-only track (1 stage): curriculumTrackHasChazaraProvider resolves false',
      () async {
        final trackId = await seedTrack(db, profileId: 1);
        await _seedStage(db, trackId: trackId, stageOrder: 1);

        final container = _buildContainer(db);
        final hasChazara = await container.read(
          curriculumTrackHasChazaraProvider(CurriculumId.mishnayos).future,
        );

        expect(
          hasChazara,
          isFalse,
          reason:
              'STUDYDAY-CHAZARA-GATE-12: a learn-only track has exactly 1 '
              'stage; the real gate provider must resolve false so the '
              'screen shows the neutral fallback without any chazara/review '
              'terminology.',
        );
      },
    );

    test(
      'chazara track (2 stages): curriculumTrackHasChazaraProvider resolves true',
      () async {
        final trackId = await seedTrack(db, profileId: 1);
        await _seedStage(db, trackId: trackId, stageOrder: 1);
        await _seedStage(
          db,
          trackId: trackId,
          stageOrder: 2,
          stageName: 'חזרה',
        );

        final container = _buildContainer(db);
        final hasChazara = await container.read(
          curriculumTrackHasChazaraProvider(CurriculumId.mishnayos).future,
        );

        expect(
          hasChazara,
          isTrue,
          reason:
              'STUDYDAY-CHAZARA-GATE-12: a chazara track has 2+ stages; the '
              'real gate provider must resolve true so the full review-day '
              'toggle UI is shown.',
        );
      },
    );

    test(
      'no stages: curriculumTrackHasChazaraProvider resolves false (no crash)',
      () async {
        await seedTrack(db, profileId: 1);
        // No stages seeded.

        final container = _buildContainer(db);
        final hasChazara = await container.read(
          curriculumTrackHasChazaraProvider(CurriculumId.mishnayos).future,
        );

        expect(hasChazara, isFalse);
      },
    );

    test(
      'no track for the curriculum: curriculumTrackHasChazaraProvider resolves '
      'false (no crash) — mirrors the trackId-null branch inside the gate',
      () async {
        // No track seeded at all for 'bavli'.
        final container = _buildContainer(db);
        final hasChazara = await container.read(
          curriculumTrackHasChazaraProvider(CurriculumId.bavli).future,
        );

        expect(hasChazara, isFalse);
      },
    );

    test(
      'stages for a different curriculum do not count toward this one',
      () async {
        final trackId1 = await seedTrack(
          db,
          profileId: 1,
          curriculumId: 'mishnayos',
        );
        await _seedStage(db, trackId: trackId1, stageOrder: 1);

        final trackId2 = await seedTrack(
          db,
          profileId: 1,
          curriculumId: 'bavli',
        );
        // Seed 3 stages for the bavli track (chazara enabled there).
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

        final container = _buildContainer(db);

        final mishnayosGate = await container.read(
          curriculumTrackHasChazaraProvider(CurriculumId.mishnayos).future,
        );
        final bavliGate = await container.read(
          curriculumTrackHasChazaraProvider(CurriculumId.bavli).future,
        );

        expect(
          mishnayosGate,
          isFalse,
          reason:
              "mishnayos's chazara gate must not be contaminated by "
              "bavli's stages",
        );
        expect(
          bavliGate,
          isTrue,
          reason: 'bavli has 3 stages, so its own gate must be true',
        );
      },
    );
  });
}
