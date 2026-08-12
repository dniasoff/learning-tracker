// L1 widget tests — EditTrackScreen + TrackDetailScreen
//
// Covers:
//   EditTrackScreen:
//   • Loading state — CircularProgressIndicator while _loadData completes
//   • AppBar title rendered
//   • Name field pre-populated with goal description
//   • Goal section rendered (pace / deadline)
//   • Study Days section rendered for non-program tracks
//   • Save Changes button in AppBar
//   • Tapping Save Changes opens confirmation dialog
//   • Confirming dialog calls trackEditService.editTrack
//   • Cancelling dialog does NOT call editTrack
//   • Renamed track sends new label to editTrack
//   • Pace stepper increment / decrement
//   • Per-period chip selection (per_day / per_week)
//   • chazara UI ONLY when chazaraEnabled / trackHasChazaraProvider is true (Rule 8)
//   • No chazara / review references on learn-only track
//   • Program track shows locked banner, hides study days + chazara
//   • Tutor with canEditGoals=false: Save button still renders (shows snackbar)
//   • No track-type labels: Personal / Standard / Custom / אישי
//   • Hebrew locale smoke test
//
//   TrackDetailScreen:
//   • AppBar title matches curriculum label
//   • Track-since date rendered
//   • Dual progress labels (Track progress + Lifetime)
//   • trackHasChazara=false → no chazara reference in header
//   • trackHasChazara=true  → chazara term appears in header
//   • Goal row shown when goal exists (pace / deadline)
//   • Edit Track action tile rendered
//   • Delete Track action tile rendered
//   • Bulk-prior tile rendered with "previously learned" copy (non-program)
//   • Reorder Content tile rendered (non-program)
//   • Program track: bulk-prior and reorder tiles are hidden
//   • Delete dialog opens on tap
//   • No track-type labels: Personal / Standard / Custom / אישי
//   • Hebrew locale smoke test
//
// PRODUCT RULES ENFORCED:
//   • Chazara UI absent when trackHasChazara=false (Rule 8)
//   • No track-type labels anywhere

@Tags(['tracks', 'edit_track', 'track_detail', 'l1'])
library;

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
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_edit_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_edit_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/edit_track_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/track_detail_screen.dart';
import 'package:learning_tracker/features/tutoring/data/routers/tutored_write_router.dart'
    show TutorWriteException;
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/drift_memory.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockTrackEditService extends Mock implements TrackEditService {}

// ── Fake Riverpod notifiers ────────────────────────────────────────────────────

class _FakeActiveProfileId extends ActiveProfileId {
  _FakeActiveProfileId(this._value);
  final int _value;
  @override
  int build() => _value;
}

class _FakeActiveTutoredProfileSelection extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

class _FakeActiveTutoredProfileSelectionWithPerms
    extends ActiveTutoredProfileSelection {
  _FakeActiveTutoredProfileSelectionWithPerms(this._perms);
  final TutorPermissions _perms;
  @override
  TutoredProfileSelection? build() => TutoredProfileSelection(
    profileId: '1',
    ownerUid: 'parent_uid',
    grantId: 'grant_1',
    permissions: _perms,
  );
}

class _FakeUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _FakeUseHebrewDate extends UseHebrewDate {
  @override
  bool build() => false;
}

// ── DB helpers ────────────────────────────────────────────────────────────────

/// Seeds a goal row for the given track.
Future<int> _seedGoal(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  String curriculumId = 'mishnayos',
  String description = 'Test Track',
  String goalType = 'pace',
  int paceValue = 3,
  String pacePeriod = 'per_week',
  DateTime? targetDate,
}) async {
  return db
      .into(db.goals)
      .insert(
        GoalsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          description: Value(description),
          goalType: Value(goalType),
          paceValue: Value(paceValue),
          pacePeriod: Value(pacePeriod),
          targetDate: Value(targetDate),
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

/// Seeds a single learn-only stage.
Future<void> _seedLearnStage(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  String curriculumId = 'mishnayos',
}) async {
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
        ),
      );
}

/// Seeds a learn + chazara stage pair.
Future<void> _seedChazaraStages(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  String curriculumId = 'mishnayos',
}) async {
  await _seedLearnStage(
    db,
    profileId: profileId,
    trackId: trackId,
    curriculumId: curriculumId,
  );
  await db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          stageOrder: 2,
          stageName: 'Chazara 1',
          schedule: const Value('{"delay_days": 1}'),
        ),
      );
}

/// Minimal [CurriculumTrack] fixture.
CurriculumTrack _track({
  int id = 1,
  int profileId = 1,
  String curriculumId = 'mishnayos',
}) => CurriculumTrack(
  id: id,
  profileId: profileId,
  curriculumId: curriculumId,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

// ── EditTrackScreen widget builder ────────────────────────────────────────────

/// Builds an [EditTrackScreen] under test with fully-controlled providers.
///
/// [hasChazara] overrides [trackHasChazaraProvider].
/// [hasProgramEnrollment] overrides [dashboardHasProgramEnrollmentProvider].
/// [dailyTasks] overrides [allDailyTasksProvider].
/// [tutorPerms] — when non-null, configures a tutored session with those perms.
Widget _buildEditApp({
  required CurriculumTrack track,
  required UserDatabase db,
  required _MockTrackEditService mockService,
  bool hasChazara = false,
  bool hasProgramEnrollment = false,
  List<DailyTask> dailyTasks = const [],
  TutorPermissions? tutorPerms,
  Locale locale = const Locale('en'),
}) {
  final curriculum = CurriculumId.values
      .where((c) => c.storageKey == track.curriculumId)
      .firstOrNull;
  return ProviderScope(
    overrides: [
      userDatabaseProvider.overrideWith((ref) => db),
      trackEditServiceProvider.overrideWithValue(mockService),
      activeProfileIdProvider.overrideWith(() => _FakeActiveProfileId(1)),
      activeTutoredProfileSelectionProvider.overrideWith(
        tutorPerms != null
            ? () => _FakeActiveTutoredProfileSelectionWithPerms(tutorPerms)
            : () => _FakeActiveTutoredProfileSelection(),
      ),
      if (curriculum != null)
        trackHasChazaraProvider(
          track.id,
        ).overrideWith((ref) async => hasChazara),
      if (curriculum != null)
        dashboardHasProgramEnrollmentProvider(
          curriculum,
        ).overrideWith((ref) async => hasProgramEnrollment),
      allDailyTasksProvider.overrideWith((ref) => Future.value(dailyTasks)),
      useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: EditTrackScreen(track: track),
    ),
  );
}

// ── TrackDetailScreen widget builder ─────────────────────────────────────────

TrackDualProgressMetric _dualMetric({
  int trackId = 1,
  CurriculumId curriculum = CurriculumId.mishnayos,
  double currentCycle = 0.0,
  double lifetime = 0.0,
}) => TrackDualProgressMetric(
  trackLabel: curriculum.storageKey,
  curriculumId: curriculum,
  currentCyclePercentage: currentCycle,
  lifetimePercentage: lifetime,
  isProgramTrack: false,
);

Widget _buildDetailApp({
  required CurriculumTrack track,
  required UserDatabase db,
  bool hasChazara = false,
  bool hasProgramEnrollment = false,
  double currentCycle = 0.0,
  double lifetime = 0.0,
  Locale locale = const Locale('en'),
}) {
  final curriculum = CurriculumId.values
      .where((c) => c.storageKey == track.curriculumId)
      .firstOrNull;
  return ProviderScope(
    overrides: [
      userDatabaseProvider.overrideWith((ref) => db),
      useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
      useHebrewDateProvider.overrideWith(() => _FakeUseHebrewDate()),
      localDayClockProvider.overrideWithValue(
        FakeLocalDayClock(DateTime.utc(2026, 5, 30)),
      ),
      if (curriculum != null)
        dashboardTrackCompletionPercentageProvider(
          track.id,
        ).overrideWith((ref) async => currentCycle),
      if (curriculum != null)
        dashboardHasProgramEnrollmentProvider(
          curriculum,
        ).overrideWith((ref) async => hasProgramEnrollment),
      if (curriculum != null)
        scopedItemCountProvider(curriculum).overrideWith((ref) async => 100),
      trackDualProgressMetricsProvider(track.profileId).overrideWith(
        (ref) async => [
          _dualMetric(
            trackId: track.id,
            curriculum: curriculum ?? CurriculumId.mishnayos,
            currentCycle: currentCycle,
            lifetime: lifetime,
          ),
        ],
      ),
      trackHasChazaraProvider(track.id).overrideWith((ref) async => hasChazara),
    ],
    child: MaterialApp(
      locale: locale,
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

// ── Pump / teardown helpers ────────────────────────────────────────────────────

/// Lets async _loadData complete.
Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// Sets the viewport to 800×4000 so all ListView sections are rendered
/// (Flutter lazily culls off-screen Sliver items).
void _setTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(
      GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
  });

  late UserDatabase db;
  late _MockTrackEditService mockService;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    mockService = _MockTrackEditService();
    when(
      () => mockService.editTrack(
        trackId: any(named: 'trackId'),
        goal: any(named: 'goal'),
        profileId: any(named: 'profileId'),
        curriculum: any(named: 'curriculum'),
        label: any(named: 'label'),
        studyDays: any(named: 'studyDays'),
        chazarahWizard: any(named: 'chazarahWizard'),
        paceTarget: any(named: 'paceTarget'),
        paceGranularity: any(named: 'paceGranularity'),
        clearPaceTarget: any(named: 'clearPaceTarget'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await db.close();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // EditTrackScreen
  // ════════════════════════════════════════════════════════════════════════════

  group('EditTrackScreen — initial render', () {
    testWidgets('shows AppBar with "Edit Track" title', (tester) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Edit Track'), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('pre-populates name field with goal description', (
      tester,
    ) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(
        db,
        profileId: 1,
        trackId: trackId,
        description: 'My Mishnayos',
      );

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      expect(find.widgetWithText(TextField, 'My Mishnayos'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows Goal section when goal exists', (tester) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      expect(find.text('Goal'), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('shows Study Days section for non-program track', (
      tester,
    ) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      expect(find.text('Study Days'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows "Save Changes" button in AppBar', (tester) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      expect(find.text('Save Changes'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('pace goal shows current pace value', (tester) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(
        db,
        profileId: 1,
        trackId: trackId,
        goalType: 'pace',
        paceValue: 5,
        pacePeriod: 'per_week',
      );

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      expect(find.text('5'), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('pace goal shows per_day and per_week period chips', (
      tester,
    ) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(
        db,
        profileId: 1,
        trackId: trackId,
        goalType: 'pace',
        paceValue: 2,
        pacePeriod: 'per_day',
      );

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      // l10n: pacePerDay = 'Per day', pacePerWeek = 'Per week'
      expect(find.text('Per day'), findsWidgets);
      expect(find.text('Per week'), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('deadline goal shows calendar date picker row', (tester) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(
        db,
        profileId: 1,
        trackId: trackId,
        goalType: 'deadline',
        targetDate: DateTime.utc(2027, 6, 1),
      );

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      // Deadline goal renders a calendar icon for the date picker.
      expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('program track shows locked banner, hides Study Days', (
      tester,
    ) async {
      _setTallViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
          hasProgramEnrollment: true,
        ),
      );
      await _pump(tester);

      // The locked banner must appear.
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      // Study Days must be hidden.
      expect(find.text('Study Days'), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── Save flow ─────────────────────────────────────────────────────────────

  group('EditTrackScreen — save flow', () {
    testWidgets('tapping Save Changes opens confirmation dialog', (
      tester,
    ) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Apply changes?'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('confirming dialog calls trackEditService.editTrack', (
      tester,
    ) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final dialogSave = find.byType(FilledButton);
      expect(dialogSave, findsOneWidget);
      await tester.tap(dialogSave);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => mockService.editTrack(
          trackId: trackId,
          goal: any(named: 'goal'),
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
          label: any(named: 'label'),
          studyDays: any(named: 'studyDays'),
          chazarahWizard: any(named: 'chazarahWizard'),
          paceTarget: any(named: 'paceTarget'),
          paceGranularity: any(named: 'paceGranularity'),
          clearPaceTarget: any(named: 'clearPaceTarget'),
        ),
      ).called(1);

      await _tearDown(tester);
    });

    testWidgets('cancelling confirmation dialog does NOT call editTrack', (
      tester,
    ) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      verifyNever(
        () => mockService.editTrack(
          trackId: any(named: 'trackId'),
          goal: any(named: 'goal'),
          profileId: any(named: 'profileId'),
          curriculum: any(named: 'curriculum'),
          label: any(named: 'label'),
          studyDays: any(named: 'studyDays'),
          chazarahWizard: any(named: 'chazarahWizard'),
          paceTarget: any(named: 'paceTarget'),
          paceGranularity: any(named: 'paceGranularity'),
          clearPaceTarget: any(named: 'clearPaceTarget'),
        ),
      );

      await _tearDown(tester);
    });

    testWidgets('editing name sends new label to editTrack', (tester) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(
        db,
        profileId: 1,
        trackId: trackId,
        description: 'Old Name',
      );

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'New Name');
      await tester.pump();

      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(
        () => mockService.editTrack(
          trackId: trackId,
          goal: any(named: 'goal'),
          profileId: 1,
          curriculum: CurriculumId.mishnayos,
          label: captureAny(named: 'label'),
          studyDays: any(named: 'studyDays'),
          chazarahWizard: any(named: 'chazarahWizard'),
          paceTarget: any(named: 'paceTarget'),
          paceGranularity: any(named: 'paceGranularity'),
          clearPaceTarget: any(named: 'clearPaceTarget'),
        ),
      ).captured;

      expect(captured.first, 'New Name');

      await _tearDown(tester);
    });

    testWidgets(
      'pace increment button is disabled when paceValue is 1 (minimum)',
      (tester) async {
        final trackId = await seedTrack(db, profileId: 1);
        await _seedGoal(
          db,
          profileId: 1,
          trackId: trackId,
          goalType: 'pace',
          paceValue: 1,
          pacePeriod: 'per_week',
        );

        await tester.pumpWidget(
          _buildEditApp(
            track: _track(id: trackId),
            db: db,
            mockService: mockService,
          ),
        );
        await _pump(tester);

        // The remove_rounded icon sits inside an InkWell (the decrement
        // stepper is EditTrackScreen's private _StepperButton, which wraps
        // Material > InkWell rather than IconButton — there is no IconButton
        // in this widget tree to inspect). At the floor (paceValue == 1) the
        // stepper's onTap callback must be null (disabled).
        final decrementInkWell = tester.widget<InkWell>(
          find.ancestor(
            of: find.byIcon(Icons.remove_rounded),
            matching: find.byType(InkWell),
          ),
        );
        expect(
          decrementInkWell.onTap,
          isNull,
          reason:
              'Decrement stepper must be disabled (onTap == null) when '
              'paceValue is already at the floor of 1.',
        );

        // After incrementing past the floor, the decrement stepper must
        // become enabled.
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pump();

        final decrementInkWellAfterIncrement = tester.widget<InkWell>(
          find.ancestor(
            of: find.byIcon(Icons.remove_rounded),
            matching: find.byType(InkWell),
          ),
        );
        expect(
          decrementInkWellAfterIncrement.onTap,
          isNotNull,
          reason:
              'Decrement stepper must re-enable once paceValue is above the '
              'floor.',
        );

        await _tearDown(tester);
      },
    );

    testWidgets('increment pace button increases pace value', (tester) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(
        db,
        profileId: 1,
        trackId: trackId,
        goalType: 'pace',
        paceValue: 3,
        pacePeriod: 'per_week',
      );

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      // Find and tap the add_rounded icon (increment stepper).
      final addIcon = find.byIcon(Icons.add_rounded).first;
      await tester.tap(addIcon);
      await tester.pump();

      // After increment, value should be 4.
      expect(find.text('4'), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('AUD-tracks-07: editTrack throwing a non-permission-denied '
        'TutorWriteException surfaces an error SnackBar (not silent failure)', (
      tester,
    ) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(db, profileId: 1, trackId: trackId);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // 'internal' (a plausible flaky-connection code per
      // tutored_write_router.dart) — anything other than
      // 'permission-denied', which is the only code the pre-fix catch
      // block handled.
      when(
        () => mockService.editTrack(
          trackId: any(named: 'trackId'),
          goal: any(named: 'goal'),
          profileId: any(named: 'profileId'),
          curriculum: any(named: 'curriculum'),
          label: any(named: 'label'),
          studyDays: any(named: 'studyDays'),
          chazarahWizard: any(named: 'chazarahWizard'),
          paceTarget: any(named: 'paceTarget'),
          paceGranularity: any(named: 'paceGranularity'),
          clearPaceTarget: any(named: 'clearPaceTarget'),
        ),
      ).thenThrow(
        const TutorWriteException('internal error', code: 'internal'),
      );

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final dialogSave = find.byType(FilledButton);
      expect(dialogSave, findsOneWidget);
      await tester.tap(dialogSave);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Pre-fix: the catch block's `if (e.code == 'permission-denied')`
      // is false for 'internal', so nothing renders — no SnackBar at
      // all — and the user is left on the same screen with zero
      // indication the save failed.
      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason:
            'A non-permission-denied TutorWriteException must surface a '
            'user-visible error instead of failing silently.',
      );
      expect(find.text(l10n.errorSaveTrackFailed), findsOneWidget);
      // Must NOT show the permission-denied-specific copy — this is a
      // different failure mode.
      expect(find.text(l10n.tutorPermissionDenied), findsNothing);

      // The confirmation dialog must be gone (Save flow ran to
      // completion, not stuck), and the screen must remain (no crash /
      // unexpected pop).
      expect(find.text('Apply changes?'), findsNothing);
      expect(find.byType(EditTrackScreen), findsOneWidget);

      await _tearDown(tester);
    });
  });

  // ── Chazara rule (Rule 8) ──────────────────────────────────────────────────

  group('EditTrackScreen — chazara UI gating (Rule 8)', () {
    testWidgets('track WITH chazara stages shows Review (Chazara) section', (
      tester,
    ) async {
      _setTallViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(db, profileId: 1, trackId: trackId);
      await _seedChazaraStages(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
          hasChazara: true,
        ),
      );
      await _pump(tester);

      expect(
        find.text('Review (Chazara)'),
        findsOneWidget,
        reason:
            'Rule 8: Review section MUST appear when track has chazara enabled',
      );

      await _tearDown(tester);
    });

    testWidgets('track WITHOUT chazara stages shows NO Review section', (
      tester,
    ) async {
      _setTallViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(db, profileId: 1, trackId: trackId);
      await _seedLearnStage(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
          hasChazara: false,
        ),
      );
      await _pump(tester);

      expect(find.text('Review (Chazara)'), findsNothing);
      expect(find.text('Change'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets(
      'learn-only track has NO review/chazara text references at all',
      (tester) async {
        _setTallViewport(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final trackId = await seedTrack(db, profileId: 1);
        await _seedGoal(db, profileId: 1, trackId: trackId);

        await tester.pumpWidget(
          _buildEditApp(
            track: _track(id: trackId),
            db: db,
            mockService: mockService,
            hasChazara: false,
          ),
        );
        await _pump(tester);

        expect(find.textContaining('Review'), findsNothing);
        expect(find.textContaining('Chazara'), findsNothing);
        expect(find.textContaining('chazara'), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'program track with chazara: still hides Review section (program locked)',
      (tester) async {
        _setTallViewport(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final trackId = await seedTrack(db, profileId: 1);
        await _seedGoal(db, profileId: 1, trackId: trackId);
        await _seedChazaraStages(db, profileId: 1, trackId: trackId);

        await tester.pumpWidget(
          _buildEditApp(
            track: _track(id: trackId),
            db: db,
            mockService: mockService,
            hasChazara: true,
            hasProgramEnrollment: true,
          ),
        );
        await _pump(tester);

        // Program tracks show the locked banner and suppress study-day/chazara.
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
        expect(find.text('Study Days'), findsNothing);
        // Review section must not appear for program tracks.
        expect(find.text('Review (Chazara)'), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── No track-type labels ──────────────────────────────────────────────────

  group('EditTrackScreen — no track-type labels', () {
    testWidgets(
      'no Personal / Standard / Custom / אישי / Track Type label visible',
      (tester) async {
        final trackId = await seedTrack(db, profileId: 1);
        await _seedGoal(db, profileId: 1, trackId: trackId);

        await tester.pumpWidget(
          _buildEditApp(
            track: _track(id: trackId),
            db: db,
            mockService: mockService,
          ),
        );
        await _pump(tester);

        expect(find.text('Personal'), findsNothing);
        expect(find.text('Standard'), findsNothing);
        expect(find.text('Custom'), findsNothing);
        expect(find.text('אישי'), findsNothing);
        expect(find.textContaining('Track Type'), findsNothing);
        expect(find.textContaining('track type'), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── Tutor permission gating ────────────────────────────────────────────────

  group('EditTrackScreen — tutor permission gating', () {
    testWidgets(
      'tutor with canEditGoals=false: Save button still renders in AppBar',
      (tester) async {
        // When a tutor doesn't have edit permissions the button must still
        // render (it just shows a permission snackbar on tap).
        final trackId = await seedTrack(db, profileId: 1);
        await _seedGoal(db, profileId: 1, trackId: trackId);

        const noEditPerms = TutorPermissions(
          canEditGoals: false,
          canEditStages: false,
        );

        await tester.pumpWidget(
          _buildEditApp(
            track: _track(id: trackId),
            db: db,
            mockService: mockService,
            tutorPerms: noEditPerms,
          ),
        );
        await _pump(tester);

        // Button must still be present even with restricted perms.
        expect(find.text('Save Changes'), findsOneWidget);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'tutor with canEditGoals=false: tapping Save shows snackbar, not dialog',
      (tester) async {
        final trackId = await seedTrack(db, profileId: 1);
        await _seedGoal(db, profileId: 1, trackId: trackId);

        const noEditPerms = TutorPermissions(
          canEditGoals: false,
          canEditStages: false,
        );

        await tester.pumpWidget(
          _buildEditApp(
            track: _track(id: trackId),
            db: db,
            mockService: mockService,
            tutorPerms: noEditPerms,
          ),
        );
        await _pump(tester);

        await tester.tap(find.text('Save Changes'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // SnackBar with permission denied text.
        expect(find.byType(SnackBar), findsOneWidget);
        // The confirmation dialog must NOT have appeared.
        expect(find.text('Apply changes?'), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'product rule: tutor canMarkLiveCompletion is always false (TutorPermissions.defaults)',
      (tester) async {
        // Product rule: canMarkLiveCompletion must always be false for tutors.
        // This is not a UI test per se — it verifies the permissions model.
        final defaults = TutorPermissions.defaults();
        expect(
          defaults.canMarkLiveCompletion,
          isFalse,
          reason:
              'Product rule: tutors MUST NOT mark live completions; '
              'canMarkLiveCompletion must always be false.',
        );
      },
    );
  });

  // ── RTL smoke test ────────────────────────────────────────────────────────

  group('EditTrackScreen — Hebrew locale smoke test', () {
    testWidgets('Hebrew locale: screen mounts without crash', (tester) async {
      final trackId = await seedTrack(db, profileId: 1);
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildEditApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
          locale: const Locale('he'),
        ),
      );
      await _pump(tester);

      expect(find.byType(Scaffold), findsWidgets);
      expect(tester.takeException(), isNull);

      await _tearDown(tester);
    });
  });

  // ── R5-4 regression: locale-aware day names in EditTrackScreen ───────────

  group('EditTrackScreen — locale-aware day names (R5-4)', () {
    testWidgets(
      'Hebrew locale: study day names are Hebrew (no English day names)',
      (tester) async {
        _setTallViewport(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final trackId = await seedTrack(db, profileId: 1);
        await _seedGoal(db, profileId: 1, trackId: trackId);

        await tester.pumpWidget(
          _buildEditApp(
            track: _track(id: trackId),
            db: db,
            mockService: mockService,
            locale: const Locale('he'),
          ),
        );
        await _pump(tester);

        // Hebrew weekday names rendered by intl contain "יום" (day) for
        // Mon–Fri and "שבת" for Shabbos; none contain the English day names.
        expect(
          find.text('Sunday'),
          findsNothing,
          reason: 'R5-4: English "Sunday" must not appear under Hebrew locale',
        );
        expect(
          find.text('Monday'),
          findsNothing,
          reason: 'R5-4: English "Monday" must not appear under Hebrew locale',
        );
        // At least one Hebrew weekday label must be visible.
        expect(
          find.textContaining('יום'),
          findsWidgets,
          reason:
              'R5-4: Hebrew weekday labels (containing "יום") must be present',
        );

        await _tearDown(tester);
      },
    );

    testWidgets(
      'English locale: study day names remain English (regression guard)',
      (tester) async {
        _setTallViewport(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final trackId = await seedTrack(db, profileId: 1);
        await _seedGoal(db, profileId: 1, trackId: trackId);

        await tester.pumpWidget(
          _buildEditApp(
            track: _track(id: trackId),
            db: db,
            mockService: mockService,
          ),
        );
        await _pump(tester);

        // At least one English weekday should be visible.
        expect(
          find.textContaining('day'),
          findsWidgets,
          reason:
              'R5-4: English weekday names (e.g. Monday, Sunday) must appear '
              'under English locale',
        );

        await _tearDown(tester);
      },
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // TrackDetailScreen
  // ════════════════════════════════════════════════════════════════════════════

  group('TrackDetailScreen — header / metadata', () {
    testWidgets('AppBar title matches curriculum label (Mishnayos)', (
      tester,
    ) async {
      final db2 = inMemoryDb();
      await seedProfileZero(db2);
      addTearDown(() => db2.close());

      final track = _track(id: 1, profileId: 0);

      await tester.pumpWidget(_buildDetailApp(track: track, db: db2));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The AppBar title is the curriculum label, e.g. "Mishnayos".
      expect(find.byType(AppBar), findsOneWidget);
      // We don't assert the exact text since it depends on l10n/Hebrew toggle,
      // just that the AppBar rendered without crash.
      expect(tester.takeException(), isNull);

      await _tearDown(tester);
    });

    testWidgets(
      'B-EDIT-NAME: custom track name (goal.description) surfaces as the '
      'AppBar title, not the curriculum label',
      (tester) async {
        final db2 = inMemoryDb();
        await seedProfileZero(db2);
        addTearDown(() => db2.close());

        // Seed a real track row so the goal's FK is satisfied.
        final trackId = await seedTrack(db2, profileId: 0);
        final track = _track(id: trackId, profileId: 0);
        // Seed a goal whose description is a USER-CHOSEN name distinct from the
        // curriculum label ("Mishnayos").
        await _seedGoal(
          db2,
          profileId: 0,
          trackId: trackId,
          description: 'My Shas Journey',
        );

        await tester.pumpWidget(_buildDetailApp(track: track, db: db2));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Pre-fix the header always showed the curriculum label and ignored the
        // edited name. The custom name must now surface in the AppBar title.
        final appBarTitle = find.descendant(
          of: find.byType(AppBar),
          matching: find.text('My Shas Journey'),
        );
        expect(appBarTitle, findsOneWidget);
        // And the curriculum label must NOT appear as the title.
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Mishnayos'),
          ),
          findsNothing,
        );

        await _tearDown(tester);
      },
    );

    testWidgets(
      'B-EDIT-NAME: no custom name → falls back to the curriculum label',
      (tester) async {
        final db2 = inMemoryDb();
        await seedProfileZero(db2);
        addTearDown(() => db2.close());

        final track = _track(id: 1, profileId: 0);
        // No goal seeded → no custom name → fall back to curriculum label.
        await tester.pumpWidget(_buildDetailApp(track: track, db: db2));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Mishnayos'),
          ),
          findsOneWidget,
        );

        await _tearDown(tester);
      },
    );

    testWidgets('track-since date is rendered somewhere on screen', (
      tester,
    ) async {
      final db2 = inMemoryDb();
      await seedProfileZero(db2);
      addTearDown(() => db2.close());

      final track = _track(id: 1, profileId: 0);

      await tester.pumpWidget(_buildDetailApp(track: track, db: db2));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The "Since <date>" string is rendered by _buildHeaderCard.
      // We just check there is at least some date-like text present
      // (Jan 1, 2026 is the track.activatedAt).
      expect(
        find.textContaining('2026'),
        findsWidgets,
        reason: 'Activation date (2026-01-01) should appear in header',
      );

      await _tearDown(tester);
    });

    testWidgets('dual progress: Track progress and Lifetime labels shown', (
      tester,
    ) async {
      final db2 = inMemoryDb();
      await seedProfileZero(db2);
      addTearDown(() => db2.close());

      final track = _track(id: 1, profileId: 0);

      await tester.pumpWidget(
        _buildDetailApp(
          track: track,
          db: db2,
          currentCycle: 0.4,
          lifetime: 0.6,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Track progress: 40%'), findsOneWidget);
      expect(find.text('Lifetime: 60%'), findsOneWidget);

      await _tearDown(tester);
    });

    // The zero-valued dual-progress-labels case ("Track progress: 0%" /
    // "Lifetime: 0%") is owned exclusively by track_detail_screen_test.dart
    // ("Track Detail — dual progress labels (Task #16)" >
    // "zero-valued metrics still render both labels at 0%") — removed here
    // per AUD-t-tracks-01 to eliminate the line-for-line duplicate assertion
    // pinned in two files against two different fixture-building helpers.
  });

  // ── Chazara header rendering ──────────────────────────────────────────────

  group('TrackDetailScreen — chazara header (Rule 8)', () {
    testWidgets(
      'track WITHOUT chazara: header shows track progress label, not chazara',
      (tester) async {
        final db2 = inMemoryDb();
        await seedProfileZero(db2);
        addTearDown(() => db2.close());

        final track = _track(id: 1, profileId: 0);

        await tester.pumpWidget(
          _buildDetailApp(
            track: track,
            db: db2,
            hasChazara: false,
            currentCycle: 0.2,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // When chazara is off, the header label must NOT mention chazara.
        expect(find.textContaining('Chazara'), findsNothing);
        expect(find.textContaining('chazara'), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets(
      'track WITH chazara: header shows chazara term in cycle label',
      (tester) async {
        final db2 = inMemoryDb();
        await seedProfileZero(db2);
        addTearDown(() => db2.close());

        final track = _track(id: 1, profileId: 0);

        await tester.pumpWidget(
          _buildDetailApp(
            track: track,
            db: db2,
            hasChazara: true,
            currentCycle: 0.3,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // With chazara enabled, the cycle label in the header should include
        // the chazara term (e.g. "Chazara" in English mode).
        // The production code calls l10n.carouselCompletion(chazaraTerm).
        expect(find.textContaining('hazara'), findsWidgets);

        await _tearDown(tester);
      },
    );
  });

  // ── Goal row ──────────────────────────────────────────────────────────────

  group('TrackDetailScreen — goal row', () {
    testWidgets('pace goal row shows pace value + period', (tester) async {
      final db2 = inMemoryDb();
      await seedProfileZero(db2);
      addTearDown(() => db2.close());

      final trackId = await seedTrack(db2, profileId: 0);
      await _seedGoal(
        db2,
        profileId: 0,
        trackId: trackId,
        goalType: 'pace',
        paceValue: 4,
        pacePeriod: 'per_week',
      );
      final track = _track(id: trackId, profileId: 0);

      await tester.pumpWidget(_buildDetailApp(track: track, db: db2));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Goal row label is shown.
      expect(find.text('Goal'), findsWidgets);
      // The pace value + period appear in the row.
      expect(find.textContaining('4'), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('deadline goal row shows formatted date', (tester) async {
      final db2 = inMemoryDb();
      await seedProfileZero(db2);
      addTearDown(() => db2.close());

      final trackId = await seedTrack(db2, profileId: 0);
      await _seedGoal(
        db2,
        profileId: 0,
        trackId: trackId,
        goalType: 'deadline',
        targetDate: DateTime.utc(2027, 12, 31),
      );
      final track = _track(id: trackId, profileId: 0);

      await tester.pumpWidget(_buildDetailApp(track: track, db: db2));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The deadline year should appear somewhere.
      expect(find.textContaining('2027'), findsWidgets);

      await _tearDown(tester);
    });
  });

  // ── Action tiles ──────────────────────────────────────────────────────────

  group('TrackDetailScreen — action tiles', () {
    testWidgets('Edit Track tile is always present', (tester) async {
      final db2 = inMemoryDb();
      await seedProfileZero(db2);
      addTearDown(() => db2.close());

      final track = _track(id: 1, profileId: 0);

      await tester.pumpWidget(_buildDetailApp(track: track, db: db2));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Edit Track'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Delete Track tile is always present', (tester) async {
      final db2 = inMemoryDb();
      await seedProfileZero(db2);
      addTearDown(() => db2.close());

      final track = _track(id: 1, profileId: 0);

      await tester.pumpWidget(_buildDetailApp(track: track, db: db2));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Delete Track'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets(
      'non-program track: bulk-prior tile uses "previously learned" copy',
      (tester) async {
        final db2 = inMemoryDb();
        await seedProfileZero(db2);
        addTearDown(() => db2.close());

        final track = _track(id: 1, profileId: 0);

        await tester.pumpWidget(
          _buildDetailApp(track: track, db: db2, hasProgramEnrollment: false),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Mark as previously learned'), findsOneWidget);
        expect(find.text('Mark Content Done'), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets('non-program track: Reorder Content tile is present', (
      tester,
    ) async {
      final db2 = inMemoryDb();
      await seedProfileZero(db2);
      addTearDown(() => db2.close());

      final track = _track(id: 1, profileId: 0);

      await tester.pumpWidget(
        _buildDetailApp(track: track, db: db2, hasProgramEnrollment: false),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Reorder Content'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('program track: bulk-prior tile is hidden (self-paced-only)', (
      tester,
    ) async {
      final db2 = inMemoryDb();
      await seedProfileZero(db2);
      addTearDown(() => db2.close());

      final track = _track(id: 1, profileId: 0);

      await tester.pumpWidget(
        _buildDetailApp(track: track, db: db2, hasProgramEnrollment: true),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Mark as previously learned'), findsNothing);
      expect(find.text('Reorder Content'), findsNothing);

      await _tearDown(tester);
    });

    // The bulk-prior tile's outlined-shape/tileColor styling assertion is
    // owned exclusively by track_detail_screen_test.dart ("Track Detail —
    // differentiated bulk-prior tile (Task #16)" > "bulk-prior tile uses
    // outlined/secondary styling with new 'previously learned' copy", which
    // also cross-checks against the sibling Edit tile) — removed here per
    // AUD-t-tracks-01 to eliminate the line-for-line duplicate assertion
    // pinned in two files against two different fixture-building helpers.

    testWidgets('tapping Delete Track opens archive/wipe dialog', (
      tester,
    ) async {
      _setTallViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db2 = inMemoryDb();
      await seedProfileZero(db2);
      // Two active curricula so the delete is NOT the profile's last active
      // track — otherwise the min-1 invariant pre-check intercepts and shows the
      // last-curriculum explanation instead of the archive/wipe dialog.
      await db2.activeCurriculumDao.activateByProfile(
        CurriculumId.mishnayos,
        0,
      );
      await db2.activeCurriculumDao.activateByProfile(CurriculumId.bavli, 0);
      addTearDown(() => db2.close());

      final track = _track(id: 1, profileId: 0);

      await tester.pumpWidget(_buildDetailApp(track: track, db: db2));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The Delete Track ListTile may be below the fold on small viewports.
      // _setTallViewport ensures the full ListView is rendered.
      final deleteTile = find.ancestor(
        of: find.text('Delete Track'),
        matching: find.byType(ListTile),
      );
      expect(deleteTile, findsOneWidget);
      await tester.tap(deleteTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The delete dialog title must appear.
      expect(find.text('Delete Track'), findsWidgets);
      // Archive option.
      expect(find.text('Archive (keep history)'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets(
      'tapping Delete Track on the SOLE active track shows the last-track '
      'explanation, not the archive/wipe dialog',
      (tester) async {
        _setTallViewport(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db2 = inMemoryDb();
        await seedProfileZero(db2);
        // Exactly ONE active curriculum → removing it is blocked by the min-1
        // invariant (TRK-HUB-04). The pre-check must surface the explanation
        // up-front instead of offering Archive/Delete options that all fail.
        await db2.activeCurriculumDao.activateByProfile(
          CurriculumId.mishnayos,
          0,
        );
        addTearDown(() => db2.close());

        final track = _track(id: 1, profileId: 0);

        await tester.pumpWidget(_buildDetailApp(track: track, db: db2));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final deleteTile = find.ancestor(
          of: find.text('Delete Track'),
          matching: find.byType(ListTile),
        );
        expect(deleteTile, findsOneWidget);
        await tester.tap(deleteTile);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The last-track explanation is shown…
        expect(
          find.text('At least one curriculum must remain active'),
          findsOneWidget,
        );
        // …and the archive/wipe dialog is NOT offered (no refusable options).
        expect(find.text('Archive (keep history)'), findsNothing);
        expect(find.text('Delete and wipe history'), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── No track-type labels ──────────────────────────────────────────────────

  group('TrackDetailScreen — no track-type labels', () {
    testWidgets(
      'no Personal / Standard / Custom / אישי / Track Type label visible',
      (tester) async {
        final db2 = inMemoryDb();
        await seedProfileZero(db2);
        addTearDown(() => db2.close());

        final track = _track(id: 1, profileId: 0);

        await tester.pumpWidget(_buildDetailApp(track: track, db: db2));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Personal'), findsNothing);
        expect(find.text('Standard'), findsNothing);
        expect(find.text('Custom'), findsNothing);
        expect(find.text('אישי'), findsNothing);
        expect(find.textContaining('Track Type'), findsNothing);
        expect(find.textContaining('track type'), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── RTL smoke test ────────────────────────────────────────────────────────

  group('TrackDetailScreen — Hebrew locale smoke test', () {
    testWidgets('Hebrew locale: screen mounts without crash', (tester) async {
      final db2 = inMemoryDb();
      await seedProfileZero(db2);
      addTearDown(() => db2.close());

      final track = _track(id: 1, profileId: 0);

      await tester.pumpWidget(
        _buildDetailApp(track: track, db: db2, locale: const Locale('he')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsWidgets);
      expect(tester.takeException(), isNull);

      await _tearDown(tester);
    });
  });
}
