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

// ignore_for_file: directives_ordering, unused_element_parameter, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart'
    show FakeLocalDayClock, localDayClockProvider;
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_detail_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

import '../../../../../helpers/firestore_fake.dart';
import '../../../../../helpers/firestore_fixtures.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

class _FakeUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _FakeUseHebrewDate extends UseHebrewDate {
  @override
  bool build() => false;
}

late FirestoreGoalRepository goalRepository;
late FirestoreStageDefinitionRepository stageRepository;

const _uid = 'track-detail-stale-test-uid';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY5';

CurriculumTrackEntity _track() => CurriculumTrackEntity(
  curriculumId: CurriculumId.mishnayos,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

Future<String> _seedGoal(
  FakeFirebaseFirestore firestore, {
  int paceValue = 3,
  String pacePeriod = 'per_week',
}) => seedGoal(
  firestore,
  uid: _uid,
  profileId: _profileId,
  curriculumId: CurriculumId.mishnayos,
  description: 'Test Track',
  goalType: 'pace',
  paceValue: paceValue,
  pacePeriod: pacePeriod,
);

Future<void> _updateGoalPaceValue(
  FakeFirebaseFirestore firestore, {
  required String goalId,
  required int newPaceValue,
}) async {
  await firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('goals')
      .doc(goalId)
      .update({'pace_value': newPaceValue});
}

Widget _buildDetailApp({
  required CurriculumTrackEntity track,
  required FakeFirebaseFirestore db,
}) {
  const curriculum = CurriculumId.mishnayos;
  return ProviderScope(
    overrides: [
      firestoreGoalRepositoryProvider.overrideWith(
        (ref) async => goalRepository,
      ),
      firestoreStageDefinitionRepositoryProvider.overrideWith(
        (ref) async => stageRepository,
      ),
      firestoreStudyDayConfigRepositoryProvider.overrideWith(
        (ref) async => FirestoreStudyDayConfigRepository(
          firestore: db,
          uid: _uid,
          profileId: _profileId,
        ),
      ),
      useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
      useHebrewDateProvider.overrideWith(() => _FakeUseHebrewDate()),
      localDayClockProvider.overrideWithValue(
        FakeLocalDayClock(DateTime.utc(2026, 5, 30)),
      ),
      dashboardTrackCompletionPercentageProvider(
        track.curriculumId,
      ).overrideWith((ref) async => 0.0),
      dashboardHasProgramEnrollmentProvider(
        curriculum,
      ).overrideWith((ref) async => false),
      scopedItemCountProvider(curriculum).overrideWith((ref) async => 100),
      trackDualProgressMetricsProvider.overrideWith(
        (ref) async => [
          TrackDualProgressMetric(
            trackLabel: 'mishnayos',
            curriculumId: curriculum,
            currentCyclePercentage: 0.0,
            lifetimePercentage: 0.0,
            isProgramTrack: false,
          ),
        ],
      ),
      trackHasChazaraProvider(
        track.curriculumId,
      ).overrideWith((ref) async => false),
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

  late FakeFirebaseFirestore db;

  setUp(() async {
    db = createFakeFirestore(authenticatedUid: _uid);
    goalRepository = FirestoreGoalRepository(
      firestore: db,
      uid: _uid,
      profileId: _profileId,
    );
    stageRepository = FirestoreStageDefinitionRepository(
      firestore: db,
      uid: _uid,
      profileId: _profileId,
    );
  });

  tearDown(() {});

  group('TRK-EDIT-STALE-01: TrackDetailScreen goal refresh after Edit Track', () {
    testWidgets(
      'goal row reflects updated pace value after EditTrack saves and returns '
      '(DB updated → route pop → _trackGoalProvider invalidated → fresh read)',
      (tester) async {
        _setTallViewport(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Seed with paceValue = 3.
        final goalId = await _seedGoal(db);

        final track = _track();

        await tester.pumpWidget(_buildDetailApp(track: track, db: db));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Step 1: verify initial goal value shown.
        // "3 · Per week" — see TrackDetailScreen._goalLabel.
        final goalRow = find
            .ancestor(of: find.text('Goal'), matching: find.byType(Row))
            .first;
        final oldGoal = find.descendant(
          of: goalRow,
          matching: find.text('3 · Per week'),
        );
        expect(
          oldGoal,
          findsOneWidget,
          reason:
              'TRK-EDIT-STALE-01: initial goal "3 · Per week" must be visible',
        );

        // Step 2: use the real Edit Track action. Its route-completion handler
        // is the production seam that invalidates _trackGoalProvider.
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        final editTrack = find.text('Edit Track');
        expect(editTrack, findsOneWidget);
        await tester.tap(editTrack);
        await tester.pumpAndSettle();

        // Step 3: the real Edit Track screen is now open. The DB update models
        // its successful save before returning to the detail screen.
        await _updateGoalPaceValue(db, goalId: goalId, newPaceValue: 7);
        navigator.pop();
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));

        // Step 5: after pop, TrackDetailScreen should show the new value "7".
        // With the fix, _trackGoalProvider is invalidated on pop → re-reads DB
        // → shows "7 · Per week".
        // Without the fix, the cached "3" from before navigation is shown.
        final newGoal = find.descendant(
          of: goalRow,
          matching: find.text('7 · Per week'),
        );
        expect(
          oldGoal,
          findsNothing,
          reason: 'the stale pace value must disappear after the refresh',
        );
        expect(
          newGoal,
          findsOneWidget,
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
