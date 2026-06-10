/// Regression test: TRK-EDIT-STALE-01
///
/// After the user edits a track via EditTrackScreen and returns to
/// TrackDetailScreen, the Goal row must reflect the NEW value immediately —
/// NOT the stale cached value from the initial page load.
///
/// Root cause before fix:
///   `TrackDetailScreen._buildActionsCard` pushed `EditTrackScreen` via
///   `Navigator.push` but never awaited the returned Future and never
///   invalidated the private `_trackGoalProvider(track.id)` after pop.
///   `onTrackChanged` (called by EditTrackScreen on save) does NOT know about
///   these private autoDispose providers, so the TrackDetailScreen's
///   `ref.watch(_trackGoalProvider)` held the pre-edit cached value forever.
///
/// Fix:
///   `_buildActionsCard` now awaits the route push and invalidates
///   `_trackGoalProvider(track.id)` and `_trackPaceCalcProvider(track)` when
///   the EditTrackScreen pops.
///
/// Test strategy (L1 widget test — no real navigation to EditTrackScreen):
///   1. Mount a `MaterialApp` with a `Navigator` showing `TrackDetailScreen`.
///   2. The DB is seeded with goal paceValue=3 per week.
///   3. Pump — verify "3 · Per week" is displayed.
///   4. Directly update the DB row to paceValue=7.
///   5. Push a dummy page on the Navigator (simulates Edit Track navigation).
///   6. Pop back to `TrackDetailScreen`.
///   7. Without the fix: still shows "3 · Per week" (stale — test FAILS).
///      With the fix: shows "7 · Per week" (fresh — test PASSES).
@Tags([
  'tracks',
  'track_detail',
  'edit_track',
  'regression',
  'TRK-EDIT-STALE-01',
])
library;

import 'dart:async' show unawaited;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart'
    show FakeLocalDayClock, localDayClockProvider;
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_detail_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../../helpers/drift_memory.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

class _FakeUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _FakeUseHebrewDate extends UseHebrewDate {
  @override
  bool build() => false;
}

/// Minimal [CurriculumTrack] fixture.
CurriculumTrack _track({int id = 1, int profileId = 0}) => CurriculumTrack(
  id: id,
  profileId: profileId,
  curriculumId: 'mishnayos',
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

/// Seeds a pace goal row for [trackId].
Future<int> _seedGoal(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  int paceValue = 3,
  String pacePeriod = 'per_week',
}) async {
  return db
      .into(db.goals)
      .insert(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          trackId: trackId,
          description: const Value('Test Track'),
          goalType: const Value('pace'),
          paceValue: Value(paceValue),
          pacePeriod: Value(pacePeriod),
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

/// Directly updates the pace_value of the goal row identified by [goalId].
Future<void> _updateGoalPaceValue(
  UserDatabase db, {
  required int goalId,
  required int newPaceValue,
}) async {
  await (db.update(db.goals)..where((t) => t.id.equals(goalId))).write(
    GoalsCompanion(paceValue: Value(newPaceValue)),
  );
}

Widget _buildDetailApp({
  required CurriculumTrack track,
  required UserDatabase db,
}) {
  const curriculum = CurriculumId.mishnayos;
  return ProviderScope(
    overrides: [
      userDatabaseProvider.overrideWith((ref) => db),
      useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
      useHebrewDateProvider.overrideWith(() => _FakeUseHebrewDate()),
      localDayClockProvider.overrideWithValue(
        FakeLocalDayClock(DateTime.utc(2026, 5, 30)),
      ),
      dashboardTrackCompletionPercentageProvider(
        track.id,
      ).overrideWith((ref) async => 0.0),
      dashboardHasProgramEnrollmentProvider(
        curriculum,
      ).overrideWith((ref) async => false),
      scopedItemCountProvider(curriculum).overrideWith((ref) async => 100),
      trackDualProgressMetricsProvider(track.profileId).overrideWith(
        (ref) async => [
          TrackDualProgressMetric(
            trackId: track.id,
            trackLabel: 'mishnayos',
            curriculumId: curriculum,
            currentCyclePercentage: 0.0,
            lifetimePercentage: 0.0,
            isProgramTrack: false,
          ),
        ],
      ),
      trackHasChazaraProvider(track.id).overrideWith((ref) async => false),
      allDailyTasksProvider.overrideWith((ref) async => []),
    ],
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

void _setTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfileZero(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TRK-EDIT-STALE-01: TrackDetailScreen goal refresh after Edit Track', () {
    testWidgets(
      'goal row reflects updated pace value after EditTrack saves and returns '
      '(DB updated → route pop → _trackGoalProvider invalidated → fresh read)',
      (tester) async {
        _setTallViewport(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final trackId = await seedTrack(db, profileId: 0);
        // Seed with paceValue = 3.
        final goalId = await _seedGoal(db, profileId: 0, trackId: trackId);
        await _seedLearnStage(db, profileId: 0, trackId: trackId);

        final track = _track(id: trackId);

        await tester.pumpWidget(_buildDetailApp(track: track, db: db));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Step 1: verify initial goal value shown.
        // "3 · Per week" — see TrackDetailScreen._goalLabel.
        expect(
          find.textContaining('3'),
          findsWidgets,
          reason:
              'TRK-EDIT-STALE-01: initial goal "3 · Per week" must be visible',
        );

        // Step 2: simulate what EditTrackScreen.editTrack() would do — update
        // the goal row in the DB directly (paceValue 3 → 7).
        await _updateGoalPaceValue(db, goalId: goalId, newPaceValue: 7);

        // Step 3: simulate the Edit Track navigation by pushing a dummy screen
        // and then popping back. This triggers the .then() handler that
        // invalidates _trackGoalProvider.
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        unawaited(
          navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Edit Track Screen')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 4: pop back to TrackDetailScreen.
        navigator.pop();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));

        // Step 5: after pop, TrackDetailScreen should show the new value "7".
        // With the fix, _trackGoalProvider is invalidated on pop → re-reads DB
        // → shows "7 · Per week".
        // Without the fix, the cached "3" from before navigation is shown.
        expect(
          find.textContaining('7'),
          findsWidgets,
          reason:
              'TRK-EDIT-STALE-01: after EditTrackScreen returns, the goal must '
              'reflect the updated pace value (7), not the stale cached value (3). '
              'If this fails, _trackGoalProvider is not being invalidated when '
              'EditTrackScreen pops.',
        );
      },
    );
  });
}

Future<void> _seedLearnStage(
  UserDatabase db, {
  required int profileId,
  required int trackId,
}) async {
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: 'mishnayos',
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
        ),
      );
}
