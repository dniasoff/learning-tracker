/// Regression tests for the Track Detail screen (W5-B / Task #16).
///
/// Asserts the W5-B copy + styling contract:
///
/// 1. Dual progress labels — the header surfaces two explicit numbers:
///    "Track progress: X%" (current cycle since track activation) and
///    "Lifetime: Y%" (lifetime tier) — both sourced from
///    [trackDualProgressMetricsProvider]. This replaces the legacy single
///    "Progress: X%" label so users distinguish engagement from accumulated
///    knowledge.
///
/// 2. Differentiated bulk-mark tile — the bulk-prior action (which opens
///    [BulkMarkScreen]) renders with secondary / outlined styling and the
///    new "Mark as previously learned" copy, so users cannot confuse the
///    historical-learning path with a live "Mark complete" action.
///
/// See `docs/planning/progress-ia-redesign.md` §9 / Task #16.
@Tags(['tracks', 'track_detail'])
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart'
    show FakeLocalDayClock, localDayClockProvider;
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_detail_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../../helpers/test_database.dart';

const _profileId = 0;
const _trackId = 1;

/// Pin the Hebrew Terms toggle off so assertions can target English copy
/// deterministically — the default value depends on the underlying
/// preference store which is unavailable in widget tests.
class _UseHebrewTermsOverride extends UseHebrewTerms {
  _UseHebrewTermsOverride({required this.useHebrew});
  final bool useHebrew;
  @override
  bool build() => useHebrew;
}

// ── Fixture helpers ────────────────────────────────────────────────────────

CurriculumTrack _track({
  int id = _trackId,
  int profileId = _profileId,
  CurriculumId curriculum = CurriculumId.mishnayos,
}) => CurriculumTrack(
  id: id,
  profileId: profileId,
  curriculumId: curriculum.storageKey,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

TrackDualProgressMetric _dualMetric({
  int trackId = _trackId,
  CurriculumId curriculum = CurriculumId.mishnayos,
  double currentCycle = 0.0,
  double lifetime = 0.0,
}) => TrackDualProgressMetric(
  trackId: trackId,
  trackLabel: curriculum.storageKey,
  curriculumId: curriculum,
  currentCyclePercentage: currentCycle,
  lifetimePercentage: lifetime,
  isProgramTrack: false,
);

/// Overrides every external dependency [TrackDetailScreen] reads so the
/// screen renders synchronously off in-memory data — no real Drift DB
/// queries beyond the user DB (used for the goal lookup).
///
/// [dashboardCompletion] and [currentCycle] are deliberately independent
/// parameters (AUD-tracks-01): [dashboardCompletion] feeds
/// [dashboardTrackCompletionPercentageProvider] (the all-time, multi-stage
/// completion gate) while [currentCycle] feeds
/// [trackDualProgressMetricsProvider]'s `currentCyclePercentage` (the
/// time-gated, since-reactivation metric). The two providers are
/// documented as computing genuinely different numbers — a fixture that
/// derives both from one shared value can never catch them disagreeing on
/// screen.
List<Override> _overridesFor({
  required UserDatabase db,
  required CurriculumTrack track,
  required CurriculumId curriculum,
  required double dashboardCompletion,
  required double currentCycle,
  required double lifetime,
}) {
  return [
    userDatabaseProvider.overrideWith((ref) => db),
    // Pin the wall clock so TrackInfoCard's pace-derived text (via
    // _trackPaceCalcProvider, which reads localDayClockProvider) is
    // deterministic instead of depending on the live system clock — matches
    // the fixed-date pattern used by every sibling file that mounts this
    // screen (edit_track_and_detail_l1_test.dart, track_detail_goal_stale_test.dart).
    localDayClockProvider.overrideWithValue(
      FakeLocalDayClock(DateTime.utc(2026, 5, 30)),
    ),
    // Goal writes go through goalRepositoryProvider, which watches
    // syncWriteFacadeProvider → authStateProvider → Firebase. Stub the sync
    // facade to null (the local-born no-op path) so the repo persists to the
    // in-memory Drift DB without touching Firebase.
    syncWriteFacadeProvider.overrideWith((ref) => null),
    useHebrewTermsProvider.overrideWith(
      () => _UseHebrewTermsOverride(useHebrew: false),
    ),
    dashboardTrackCompletionPercentageProvider(
      track.id,
    ).overrideWith((ref) async => dashboardCompletion),
    dashboardHasProgramEnrollmentProvider(
      curriculum,
    ).overrideWith((ref) async => false),
    scopedItemCountProvider(curriculum).overrideWith((ref) async => 100),
    trackDualProgressMetricsProvider(track.profileId).overrideWith(
      (ref) async => [
        _dualMetric(
          trackId: track.id,
          curriculum: curriculum,
          currentCycle: currentCycle,
          lifetime: lifetime,
        ),
      ],
    ),
  ];
}

Widget _wrap({
  required List<Override> overrides,
  required CurriculumTrack track,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: TrackDetailScreen(track: track),
    ),
  );
}

void main() {
  late UserDatabase db;

  setUp(() async {
    db = createTestUserDatabase();
    await seedProfileZero(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Track Detail — dual progress labels (Task #16)', () {
    testWidgets('header shows both "Track progress: X%" and "Lifetime: Y%"', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(
        _wrap(
          track: track,
          overrides: _overridesFor(
            db: db,
            track: track,
            curriculum: CurriculumId.mishnayos,
            // 0.35 → 35%, 0.74 → 74% (adaptive precision: whole numbers, no dp)
            dashboardCompletion: 0.35,
            currentCycle: 0.35,
            lifetime: 0.74,
          ),
        ),
      );
      // Let the FutureProviders + goal lookup settle without
      // pumpAndSettle (which would spin on auto-disposing providers).
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Track progress: 35%'),
        findsOneWidget,
        reason:
            'Dual progress label must surface the current-cycle pct from '
            'trackDualProgressMetricsProvider as "Track progress: X%".',
      );
      expect(
        find.text('Lifetime: 74%'),
        findsOneWidget,
        reason:
            'Dual progress label must surface the lifetime tier pct from '
            'trackDualProgressMetricsProvider as "Lifetime: Y%".',
      );
    });

    testWidgets(
      'AUD-tracks-01: divergent dashboard-completion and current-cycle '
      'values never render two different percentages under the same '
      '"Track progress" label',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(
          _wrap(
            track: track,
            overrides: _overridesFor(
              db: db,
              track: track,
              curriculum: CurriculumId.mishnayos,
              // Deliberately different from currentCycle so a fixture that
              // (pre-fix) reused one shared value could never reproduce the
              // divergence — dashboardTrackCompletionPercentageProvider
              // (all-time, multi-stage) vs trackDualProgressMetricsProvider's
              // currentCyclePercentage (time-gated, since-reactivation).
              dashboardCompletion: 0.62,
              currentCycle: 0.20,
              lifetime: 0.74,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // The dual-metrics row (top) must show the current-cycle number
        // under "Track progress".
        expect(
          find.text('Track progress: 20%'),
          findsOneWidget,
          reason:
              'The header row must surface currentCyclePercentage (20%) '
              'under the "Track progress" label.',
        );

        // The bare "Track progress" label (no colon/value suffix) must
        // never appear standalone — that was the second, differently-sourced
        // row (dashboardTrackCompletionPercentageProvider's 62%) reusing the
        // same label text as the row above it, making two different numbers
        // look like they shared one meaning.
        expect(
          find.text('Track progress'),
          findsNothing,
          reason:
              'A second row must not reuse the bare "Track progress" label '
              'for a value sourced from a different provider/formula — the '
              'screen must never show two different percentages under the '
              'same label.',
        );

        // The dashboardTrackCompletionPercentageProvider-sourced number
        // (62%) must still render, but under its own, distinct label.
        expect(
          find.text('62%'),
          findsOneWidget,
          reason:
              'dashboardTrackCompletionPercentageProvider\'s value must '
              'still be visible on screen — just not mislabeled as '
              '"Track progress".',
        );
      },
    );

    testWidgets('zero-valued metrics still render both labels at 0%', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(
        _wrap(
          track: track,
          overrides: _overridesFor(
            db: db,
            track: track,
            curriculum: CurriculumId.mishnayos,
            dashboardCompletion: 0.0,
            currentCycle: 0.0,
            lifetime: 0.0,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Both labels must render even when the user has no progress yet,
      // so the dual-progress contract is the same in empty state.
      expect(find.text('Track progress: 0%'), findsOneWidget);
      expect(find.text('Lifetime: 0%'), findsOneWidget);
    });
  });

  group('Track Detail — goal add/edit affordance', () {
    testWidgets('exposes a "Set Goal" tile when the track has no goal', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(
        _wrap(
          track: track,
          overrides: _overridesFor(
            db: db,
            track: track,
            curriculum: CurriculumId.mishnayos,
            dashboardCompletion: 0.0,
            currentCycle: 0.0,
            lifetime: 0.0,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const ValueKey('trackDetail.goalTile')),
        findsOneWidget,
        reason:
            'Track detail must surface a goal add/edit affordance so a goal '
            'can be set post-creation without re-running the add-track wizard.',
      );
      expect(
        find.text('Set Goal'),
        findsOneWidget,
        reason: 'With no existing goal the tile reads "Set Goal".',
      );
    });

    testWidgets('tapping the goal tile and submitting persists a goal', (
      tester,
    ) async {
      final track = _track();
      await tester.pumpWidget(
        _wrap(
          track: track,
          overrides: _overridesFor(
            db: db,
            track: track,
            curriculum: CurriculumId.mishnayos,
            dashboardCompletion: 0.0,
            currentCycle: 0.0,
            lifetime: 0.0,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // The goal row FK-references curriculum_tracks(id); insert the track
      // row so the goal INSERT satisfies the foreign-key constraint.
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              id: Value(track.id),
              profileId: track.profileId,
              curriculumId: track.curriculumId,
              state: Value(track.state),
              stateChangedAt: track.stateChangedAt,
              activatedAt: track.activatedAt,
            ),
          );

      // No goal exists yet for this track.
      expect(await db.goalDao.getGoalByTrack(track.id), isNull);

      // Open the goal-setup form.
      await tester.tap(find.byKey(const ValueKey('trackDetail.goalTile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The goal-setup form renders its mode toggle + submit button.
      expect(find.text('Create Goal'), findsOneWidget);

      // The form defaults to 'deadline' mode which requires a date before
      // submitting. Switch to 'No deadline' mode so the form is immediately
      // submittable without any additional date-picker interaction.
      await tester.tap(find.text('No deadline'));
      await tester.pump();

      // Submit the goal (no-deadline mode requires no further input), then
      // let the write + navigation pop settle.
      await tester.tap(find.text('Create Goal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      final persisted = await db.goalDao.getGoalByTrack(track.id);
      expect(
        persisted,
        isNotNull,
        reason:
            'Submitting the goal form must persist a goal row for this track '
            'via the goal repository write path.',
      );
      expect(persisted!.trackId, track.id);
      expect(persisted.profileId, track.profileId);
      expect(persisted.curriculumId, CurriculumId.mishnayos.storageKey);
    });
  });

  group('Track Detail — Items remaining in the pace unit (daf)', () {
    testWidgets(
      'daf-paced Bavli track shows DAF count for Items remaining, not amudim',
      (tester) async {
        final track = _track(curriculum: CurriculumId.bavli);

        // FK: the goal row references curriculum_tracks(id).
        await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                id: Value(track.id),
                profileId: track.profileId,
                curriculumId: track.curriculumId,
                state: Value(track.state),
                stateChangedAt: track.stateChangedAt,
                activatedAt: track.activatedAt,
              ),
            );
        // Daf-granularity pace goal.
        await db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                profileId: track.profileId,
                curriculumId: track.curriculumId,
                trackId: track.id,
                description: const Value('Daf goal'),
                goalType: const Value('pace'),
                paceValue: const Value(7),
                pacePeriod: const Value('per_week'),
                paceGranularity: const Value('daf'),
                createdAt: DateTime.utc(2026, 1, 1),
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );

        final overrides = [
          ..._overridesFor(
            db: db,
            track: track,
            curriculum: CurriculumId.bavli,
            dashboardCompletion: 0.0, // 0% → remaining == total
            currentCycle: 0.0,
            lifetime: 0.0,
          ),
          // 100 amudim (leaf) collapse to 50 dapim (coarse).
          scopedCoarseUnitCountProvider(
            CurriculumId.bavli,
          ).overrideWith((ref) async => 50),
        ];

        await tester.pumpWidget(_wrap(track: track, overrides: overrides));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // Items remaining must show the DAF count (50), not the amud count (100).
        expect(
          find.text('50'),
          findsOneWidget,
          reason:
              'A daf-paced track must show "Items remaining" in dapim (50), '
              'matching the Est. finish basis — not amudim.',
        );
        expect(
          find.text('100'),
          findsNothing,
          reason: 'The amud (leaf) count must not leak into a daf-paced track.',
        );
      },
    );
  });

  group('Track Detail — Goal row shows the pace unit noun (P1 iter-2)', () {
    testWidgets(
      'daf-paced Bavli goal row reads "7 Dafim · Per week", not bare "7 · …"',
      (tester) async {
        final track = _track(curriculum: CurriculumId.bavli);

        // FK: the goal row references curriculum_tracks(id).
        await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                id: Value(track.id),
                profileId: track.profileId,
                curriculumId: track.curriculumId,
                state: Value(track.state),
                stateChangedAt: track.stateChangedAt,
                activatedAt: track.activatedAt,
              ),
            );
        // 7-daf-per-week pace goal — the granularity carries the unit noun.
        await db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                profileId: track.profileId,
                curriculumId: track.curriculumId,
                trackId: track.id,
                description: const Value('Daf goal'),
                goalType: const Value('pace'),
                paceValue: const Value(7),
                pacePeriod: const Value('per_week'),
                paceGranularity: const Value('daf'),
                createdAt: DateTime.utc(2026, 1, 1),
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );

        final overrides = [
          ..._overridesFor(
            db: db,
            track: track,
            curriculum: CurriculumId.bavli,
            dashboardCompletion: 0.0,
            currentCycle: 0.0,
            lifetime: 0.0,
          ),
          scopedCoarseUnitCountProvider(
            CurriculumId.bavli,
          ).overrideWith((ref) async => 50),
        ];

        await tester.pumpWidget(_wrap(track: track, overrides: overrides));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // The Goal config row must read the same unit-noun format as the
        // Required-pace row in TrackInfoCard (iter-1 fix) — "7 Dafim · Per week".
        expect(
          find.text('7 Dafim · Per week'),
          findsWidgets,
          reason:
              'The Track-Detail Goal row must include the pace unit noun '
              '("7 Dafim · Per week"), matching the Required-pace row — not the '
              'bare "7 · Per week".',
        );
        // The bare, noun-less format must NOT appear anywhere on the screen.
        expect(
          find.text('7 · Per week'),
          findsNothing,
          reason:
              'The bare noun-less pace value ("7 · Per week") must no longer '
              'render on the Track-Detail screen.',
        );
      },
    );
  });

  group('Track Detail — differentiated bulk-prior tile (Task #16)', () {
    testWidgets(
      'bulk-prior tile uses outlined/secondary styling with new "previously learned" copy',
      (tester) async {
        final track = _track();
        await tester.pumpWidget(
          _wrap(
            track: track,
            overrides: _overridesFor(
              db: db,
              track: track,
              curriculum: CurriculumId.mishnayos,
              dashboardCompletion: 0.1,
              currentCycle: 0.1,
              lifetime: 0.2,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // New copy — the bulk-prior tile no longer says "Mark Content Done";
        // it now says "Mark as previously learned" to signal the historical
        // / lifetime nature of the action.
        expect(
          find.text('Mark as previously learned'),
          findsOneWidget,
          reason:
              'Bulk-prior tile must use the new "previously learned" copy so '
              'it cannot be confused with a live "Mark complete" action.',
        );
        expect(
          find.text('Mark Content Done'),
          findsNothing,
          reason: 'Legacy bulk-mark copy must be replaced.',
        );

        // Visual differentiation — the tile must carry an outlined shape and
        // a tinted background, distinct from the neighbouring "Edit" /
        // "Delete" plain ListTiles. We assert the concrete ShapeBorder /
        // tileColor properties so a regression that drops the outline fails.
        final bulkTileFinder = find.byKey(
          const ValueKey('trackDetail.bulkPriorTile'),
        );
        expect(bulkTileFinder, findsOneWidget);

        final bulkTile = tester.widget<ListTile>(bulkTileFinder);
        expect(
          bulkTile.shape,
          isA<RoundedRectangleBorder>(),
          reason: 'Bulk-prior tile must have a RoundedRectangleBorder.',
        );
        final shape = bulkTile.shape! as RoundedRectangleBorder;
        expect(
          shape.side.width,
          greaterThan(0),
          reason:
              'Bulk-prior tile must render a non-zero border (outlined) to '
              'differentiate it from primary action tiles.',
        );
        expect(
          shape.side.color,
          isNot(equals(const Color(0x00000000))),
          reason:
              'Bulk-prior tile outline must use a visible (non-transparent) '
              'colour so the secondary styling is perceptible.',
        );
        expect(
          bulkTile.tileColor,
          isNotNull,
          reason:
              'Bulk-prior tile must apply a tileColor tint as part of the '
              'secondary visual treatment.',
        );

        // Cross-check against a sibling ListTile (Edit Track) — that one
        // MUST NOT carry the outline, proving the styling difference is real.
        final editTileFinder = find.ancestor(
          of: find.text('Edit Track'),
          matching: find.byType(ListTile),
        );
        expect(editTileFinder, findsOneWidget);
        final editTile = tester.widget<ListTile>(editTileFinder);
        // Edit tile has no shape (or a shape without a visible border).
        if (editTile.shape is RoundedRectangleBorder) {
          final editShape = editTile.shape! as RoundedRectangleBorder;
          expect(
            editShape.side.width,
            equals(0.0),
            reason:
                'Sibling Edit tile must NOT carry the bulk-prior outline — '
                'the visual contrast is the whole point of the differentiation.',
          );
        }
        expect(
          editTile.tileColor,
          isNull,
          reason:
              'Sibling Edit tile must not be tinted; only the bulk-prior '
              'tile carries the secondary tile colour.',
        );
      },
    );
  });
}
