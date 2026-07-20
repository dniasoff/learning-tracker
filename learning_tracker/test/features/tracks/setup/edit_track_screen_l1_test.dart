// L1 widget tests — EditTrackScreen + ChazaraInlineSetup
//
// Covers:
//   • Renders current track name, goal section and study-days section.
//   • Save → confirm dialog → service.editTrack() call verified via mocktail.
//   • Confirm dialog cancel path (no save call).
//   • ChazaraInlineSetup: presets shown; custom cycle enforces min 1 / max 5
//     rounds.
//   • Chazara UI rendered ONLY when track has chazara enabled (Rule 8).
//   • A no-chazara track shows NO chazara / review controls at all.
//   • No "track type" / "Personal" / "Standard" / "Custom" label anywhere.
//
// PUMP RIG:
//   ProviderScope(overrides:[...], child: MaterialApp(locale, delegates, home:
//   EditTrackScreen(track:...)))
//   No pumpAndSettle on open async streams; double-pump after widget mount.
//   Teardown: pumpWidget(SizedBox.shrink) + pump(Duration.zero).

@Tags(['tracks', 'edit_track', 'l1'])
library;

import 'dart:io' as dart_io;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_edit_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_edit_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/edit_track_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/chazara_widgets.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_chazara.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/drift_memory.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockTrackEditService extends Mock implements TrackEditService {}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Builds a minimal [CurriculumTrack] for tests.
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

/// Seeds a [Goal] row for the given [trackId] in [db].
Future<int> _seedGoal(
  UserDatabase db, {
  required int profileId,
  required int trackId,
  String curriculumId = 'mishnayos',
  String description = 'Test Track',
  String goalType = 'pace',
  int paceValue = 3,
  String pacePeriod = 'per_week',
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
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

/// Seeds a learn stage (stageOrder=1) for [trackId].
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

/// Seeds a learn + chazara stage pair for [trackId].
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

/// Pumps [EditTrackScreen] with a full [ProviderScope] rig.
///
/// [hasChazara]   — overrides [trackHasChazaraProvider] for the track.
/// [mockService]  — overrides [trackEditServiceProvider].
/// [dailyTasks]   — overrides [allDailyTasksProvider] (empty by default).
///
/// Callers that need to assert on sections below the fold (e.g. Review) must
/// call `tester.view.physicalSize = Size(800, 4000)` before pumping, because
/// ListView lazy-culls off-screen items. See [_setTallViewport] helper.
Widget _buildApp({
  required CurriculumTrack track,
  required UserDatabase db,
  required _MockTrackEditService mockService,
  bool hasChazara = false,
  List<DailyTask> dailyTasks = const [],
  bool useHebrew = false,
  TransliterationVariant? variant,
}) {
  return ProviderScope(
    overrides: [
      userDatabaseProvider.overrideWith((ref) => db),
      trackEditServiceProvider.overrideWithValue(mockService),
      activeProfileIdProvider.overrideWith(() => _FakeActiveProfileId(1)),
      activeTutoredProfileSelectionProvider.overrideWith(
        () => _FakeActiveTutoredProfileSelection(),
      ),
      trackHasChazaraProvider(
        track.id,
      ).overrideWithValue(AsyncData(hasChazara)),
      dashboardHasProgramEnrollmentProvider(
        CurriculumId.values
            .where((c) => c.storageKey == track.curriculumId)
            .first,
      ).overrideWithValue(const AsyncData(false)),
      allDailyTasksProvider.overrideWith((ref) => Future.value(dailyTasks)),
      useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms(useHebrew)),
      if (variant != null)
        currentTransliterationVariantProvider.overrideWithValue(variant),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
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

/// Pumps [ChazaraInlineSetup] inside a minimal app.
///
/// Wraps in a fixed 800x1200 viewport so that [Expanded] inside the sheet
/// has bounded vertical space and does not throw overflow errors.
Widget _buildChazaraApp({
  required CurriculumId curriculumId,
  List<int>? initialDelays,
  required void Function(LearningProcessWizardResult?) onComplete,
}) {
  return ProviderScope(
    overrides: [
      useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          height: 800,
          child: ChazaraInlineSetup(
            curriculumId: curriculumId,
            headerTitle: 'Review (Chazara)',
            headerSubtitle: 'Configure review rounds.',
            initialDelays: initialDelays,
            onComplete: onComplete,
          ),
        ),
      ),
    ),
  );
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// Sets the test viewport to 800x4000 so that all EditTrackScreen ListView
/// sections are rendered (including the Review section which appears below
/// the fold on the default ~800x600 test viewport).
///
/// Flutter ListView uses lazy Sliver rendering: items below the viewport are
/// NOT in the widget tree. `find.text(skipOffstage: false)` only finds
/// off-screen items that ARE in the tree; culled items are invisible to finders.
void _setTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
}

/// Lets the [EditTrackScreen] complete its [_loadData] async initialisation.
Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

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

class _FakeUseHebrewTerms extends UseHebrewTerms {
  _FakeUseHebrewTerms([this._value = false]);
  final bool _value;
  @override
  bool build() => _value;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(CurriculumId.mishnayos);
  });

  late UserDatabase db;
  late _MockTrackEditService mockService;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    mockService = _MockTrackEditService();
    // Default stub: editTrack completes successfully.
    when(
      () => mockService.editTrack(
        trackId: any(named: 'trackId'),
        goalId: any(named: 'goalId'),
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

  // ── Group: initial render ─────────────────────────────────────────────────

  group('EditTrackScreen — initial render', () {
    testWidgets('shows AppBar title "Edit Track"', (tester) async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      expect(find.text('Edit Track'), findsWidgets);
      expect(find.byType(AppBar), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('renders current track name in name field', (tester) async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(
        db,
        profileId: 1,
        trackId: trackId,
        description: 'My Mishnayos',
      );

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      // The name TextField should contain the goal's description.
      expect(find.widgetWithText(TextField, 'My Mishnayos'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows Goal section when goal exists', (tester) async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      // "Goal" section heading must be visible.
      expect(find.text('Goal'), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('shows Study Days section for non-program track', (
      tester,
    ) async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      expect(find.text('Study Days'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows "Save Changes" button', (tester) async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      expect(find.text('Save Changes'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets(
      'no "track type" / Personal / Standard / Custom label visible',
      (tester) async {
        final trackId = await seedTrack(
          db,
          profileId: 1,
          curriculumId: 'mishnayos',
        );
        await _seedGoal(db, profileId: 1, trackId: trackId);

        await tester.pumpWidget(
          _buildApp(
            track: _track(id: trackId),
            db: db,
            mockService: mockService,
          ),
        );
        await _pump(tester);

        // None of these should appear anywhere on screen.
        expect(find.text('Personal'), findsNothing);
        expect(find.text('Standard'), findsNothing);
        expect(find.text('Custom'), findsNothing);
        expect(find.textContaining('Track Type'), findsNothing);
        expect(find.textContaining('track type'), findsNothing);
        // The Hebrew term for personal (אישי) must also be absent.
        expect(find.text('אישי'), findsNothing);

        await _tearDown(tester);
      },
    );

    testWidgets('pace goal: shows pace value stepper with current value', (
      tester,
    ) async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(
        db,
        profileId: 1,
        trackId: trackId,
        goalType: 'pace',
        paceValue: 3,
        pacePeriod: 'per_week',
      );

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      // The pace value "3" should be visible.
      expect(find.text('3'), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets(
      'AUD-tracks-10 (AX-3): pace +/- stepper buttons expose non-empty, '
      'button-role Semantics labels for their increase/decrease actions',
      (tester) async {
        final handle = tester.ensureSemantics();

        final trackId = await seedTrack(
          db,
          profileId: 1,
          curriculumId: 'mishnayos',
        );
        await _seedGoal(
          db,
          profileId: 1,
          trackId: trackId,
          goalType: 'pace',
          paceValue: 3,
          pacePeriod: 'per_week',
        );

        await tester.pumpWidget(
          _buildApp(
            track: _track(id: trackId),
            db: db,
            mockService: mockService,
          ),
        );
        await _pump(tester);

        final decreaseIcon = find.byIcon(Icons.remove_rounded);
        final increaseIcon = find.byIcon(Icons.add_rounded);
        expect(decreaseIcon, findsOneWidget);
        expect(increaseIcon, findsOneWidget);

        // AC2 (literal): a widget test finds a Semantics node with a button
        // role and non-empty label at each control's location.
        final decreaseSemantics = tester.getSemantics(decreaseIcon);
        final increaseSemantics = tester.getSemantics(increaseIcon);

        // The stepper also conveys enabled/disabled state (the decrease
        // button disables at paceValue == 1), so `enabled:` is threaded
        // into Semantics — hence hasEnabledState/isEnabled appear here too.
        expect(
          decreaseSemantics,
          matchesSemantics(
            label: 'Decrease pace value',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
          ),
          reason:
              'AUD-tracks-10: the pace "decrease" stepper button must '
              'expose a non-empty, button-role Semantics label',
        );
        expect(
          increaseSemantics,
          matchesSemantics(
            label: 'Increase pace value',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
          ),
          reason:
              'AUD-tracks-10: the pace "increase" stepper button must '
              'expose a non-empty, button-role Semantics label',
        );
        expect(
          decreaseSemantics.label,
          isNot(equals(increaseSemantics.label)),
          reason: 'AUD-tracks-10: increase/decrease must carry distinct labels',
        );

        handle.dispose();
        await _tearDown(tester);
      },
    );
  });

  // ── Group: study-days day-6 label (nusach + Hebrew terms) ─────────────────

  group('EditTrackScreen — day-6 label honours nusach + Hebrew terms', () {
    testWidgets('Ashkenazi (en) → "Shabbos"', (tester) async {
      _setTallViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
          variant: TransliterationVariant.ashkenazi,
        ),
      );
      await _pump(tester);

      expect(find.text('Shabbos'), findsOneWidget);
      expect(find.text('Shabbat'), findsNothing);
      expect(find.text('שבת'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('Sephardi (en) → "Shabbat"', (tester) async {
      _setTallViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
          variant: TransliterationVariant.sephardi,
        ),
      );
      await _pump(tester);

      expect(find.text('Shabbat'), findsOneWidget);
      expect(find.text('Shabbos'), findsNothing);
      expect(find.text('שבת'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('Hebrew terms ON → "שבת"', (tester) async {
      _setTallViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
          useHebrew: true,
        ),
      );
      await _pump(tester);

      expect(find.text('שבת'), findsOneWidget);
      expect(find.text('Shabbos'), findsNothing);
      expect(find.text('Shabbat'), findsNothing);

      await _tearDown(tester);
    });
  });

  // ── Group: save flow ──────────────────────────────────────────────────────

  group('EditTrackScreen — save flow', () {
    testWidgets('tapping Save Changes opens confirmation dialog', (
      tester,
    ) async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      // Tap the "Save Changes" TextButton in the AppBar.
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // The confirm dialog must appear.
      expect(find.text('Apply changes?'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('confirming save dialog calls trackEditService.editTrack', (
      tester,
    ) async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      // Tap "Save Changes" → open dialog.
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap the "Save Changes" FilledButton inside the dialog.
      final dialogSaveButtons = find.byType(FilledButton);
      expect(dialogSaveButtons, findsOneWidget);
      await tester.tap(dialogSaveButtons);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // editTrack must have been called exactly once.
      verify(
        () => mockService.editTrack(
          trackId: trackId,
          goalId: any(named: 'goalId'),
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
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      // Open dialog.
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Cancel.
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // No call to editTrack after cancel.
      verifyNever(
        () => mockService.editTrack(
          trackId: any(named: 'trackId'),
          goalId: any(named: 'goalId'),
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

    testWidgets('editing track name sends new label to editTrack', (
      tester,
    ) async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(
        db,
        profileId: 1,
        trackId: trackId,
        description: 'Old Name',
      );

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
        ),
      );
      await _pump(tester);

      // Edit name.
      await tester.enterText(find.byType(TextField), 'New Name');
      await tester.pump();

      // Save → confirm.
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The label argument passed to editTrack must be the new name.
      final captured = verify(
        () => mockService.editTrack(
          trackId: trackId,
          goalId: any(named: 'goalId'),
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

      expect(
        captured.first,
        'New Name',
        reason: 'editTrack must receive the edited label',
      );

      await _tearDown(tester);
    });
  });

  // ── Group: chazara rule (Rule 8) ─────────────────────────────────────────

  group('EditTrackScreen — chazara UI gating (Rule 8)', () {
    testWidgets('track WITH chazara stages shows Review section', (
      tester,
    ) async {
      // Use a tall viewport so all ListView sections are rendered.
      // EditTrackScreen's Review section appears below the fold on
      // the default ~800x600 test viewport due to ListView lazy culling.
      _setTallViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);
      await _seedChazaraStages(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
          hasChazara: true,
        ),
      );
      await _pump(tester);

      // The "Review (Chazara)" section must be visible.
      expect(
        find.text('Review (Chazara)'),
        findsOneWidget,
        reason:
            'Rule 8: Review section must show when track has chazara enabled',
      );

      await _tearDown(tester);
    });

    testWidgets('track WITHOUT chazara stages shows NO Review section', (
      tester,
    ) async {
      _setTallViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);
      // Only learn stage — no chazara.
      await _seedLearnStage(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        _buildApp(
          track: _track(id: trackId),
          db: db,
          mockService: mockService,
          hasChazara: false, // explicitly no chazara
        ),
      );
      await _pump(tester);

      // Review section must be entirely absent even in tall viewport.
      expect(find.text('Review (Chazara)'), findsNothing);
      // "Change" button for chazara must also be absent.
      expect(find.text('Change'), findsNothing);

      await _tearDown(tester);
    });

    testWidgets(
      'no-chazara track shows no review / chazara references anywhere',
      (tester) async {
        _setTallViewport(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final trackId = await seedTrack(
          db,
          profileId: 1,
          curriculumId: 'mishnayos',
        );
        await _seedGoal(db, profileId: 1, trackId: trackId);

        await tester.pumpWidget(
          _buildApp(
            track: _track(id: trackId),
            db: db,
            mockService: mockService,
            hasChazara: false,
          ),
        );
        await _pump(tester);

        // No chazara summary text.
        expect(find.textContaining('No review'), findsNothing);
        // No review section heading at all.
        expect(find.textContaining('Review'), findsNothing);

        await _tearDown(tester);
      },
    );
  });

  // ── Group: ChazaraInlineSetup — preset selection ─────────────────────────

  group('ChazaraInlineSetup — preset selection', () {
    testWidgets('all 4 built-in presets are visible', (tester) async {
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          onComplete: (_) {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Learn Only'), findsOneWidget);
      expect(find.text('1 day'), findsOneWidget);
      expect(find.text('1 + 7 days'), findsOneWidget);
      expect(find.text('1 + 7 + 30 days'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('Custom Cycle section is visible', (tester) async {
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          onComplete: (_) {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Custom Cycle'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('initialDelays pre-selects the matching preset', (
      tester,
    ) async {
      LearningProcessWizardResult? result;
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          initialDelays: [1, 7], // matches "1 + 7 days" preset
          onComplete: (r) => result = r,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Confirm the pre-selected preset so we can inspect the result.
      final continueBtn = find.byType(FilledButton);
      expect(continueBtn, findsOneWidget);
      await tester.tap(continueBtn);
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.wizardResult.choice, WizardChoice.custom);
      expect(
        result!.wizardResult.customRounds?.map((r) => r.delayDays).toList(),
        [1, 7],
      );

      await _tearDown(tester);
    });
  });

  // ── Group: ChazaraInlineSetup — custom cycle min/max ────────────────────

  group('ChazaraInlineSetup — custom cycle min 1 / max 5 rounds', () {
    testWidgets('Add round chip visible when custom rounds < 5', (
      tester,
    ) async {
      // Start with 1 custom round (initialDelays doesn't match any preset).
      // presets: [], [1], [1,7], [1,7,30] — so [3] triggers custom mode.
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          initialDelays: [3], // not a preset → custom mode, 1 round
          onComplete: (_) {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // The AddRoundChip renders Icons.add (not Icons.add_rounded).
      // It must be present when _customDelays.length < 5.
      expect(find.byIcon(Icons.add), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('Add round chip hidden when custom rounds == 5', (
      tester,
    ) async {
      // 5 custom rounds → no add chip.
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          initialDelays: [1, 2, 4, 8, 16], // 5 rounds
          onComplete: (_) {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Precondition: all 5 rounds actually rendered (otherwise the absence
      // check below would be vacuous — it could pass because setup failed,
      // not because the max-5 guard fired).
      expect(find.byType(CustomDayEditorChip), findsNWidgets(5));

      // With 5 rounds in custom mode, the add-round chip must be hidden.
      // Implementation check: the source code uses:
      //   if (_customDelays.length < 5) AddRoundChip(...)
      // With 5 rounds the chip is not in the widget tree at all.
      //
      // Find the AddRoundChip widget itself rather than its internal
      // Icons.add — that icon is ambiguous with the per-round "+1 day"
      // TinyCircleButton inside every CustomDayEditorChip (also Icons.add),
      // so an icon-only finder would always find something regardless of
      // whether the add-round chip is present.
      expect(find.byType(AddRoundChip), findsNothing);

      await _tearDown(tester);
    });

    testWidgets('adding rounds via add chip increments round count', (
      tester,
    ) async {
      // Start with a single custom round; add one more.
      int? capturedRoundCount;
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          initialDelays: [3], // not a preset → forces custom mode, 1 round
          onComplete: (r) {
            capturedRoundCount = r?.wizardResult.customRounds?.length;
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Precondition: exactly 1 custom round rendered before the tap.
      expect(find.byType(CustomDayEditorChip), findsNWidgets(1));

      // Tap the add-round chip. Find the AddRoundChip widget itself rather
      // than its internal Icons.add — that icon is ambiguous with the
      // per-round "+1 day" TinyCircleButton (also Icons.add), so an
      // icon-only finder would tap the wrong control if AddRoundChip
      // happened not to be present.
      final addChip = find.byType(AddRoundChip);
      expect(
        addChip,
        findsOneWidget,
        reason: 'Custom mode with 1 round must show the add-round chip',
      );
      await tester.tap(addChip);
      await tester.pump();

      // Round count must have gone from 1 to 2 in the widget tree.
      expect(find.byType(CustomDayEditorChip), findsNWidgets(2));

      // Confirm and capture.
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // Real assertion: adding one round to a single-round custom cycle
      // must produce exactly 2 custom rounds (not merely "at least 1",
      // which would pass even if the add chip did nothing).
      expect(
        capturedRoundCount,
        2,
        reason: 'Adding a round from 1 must produce exactly 2 custom rounds',
      );

      await _tearDown(tester);
    });

    testWidgets('single round: remove button absent (min 1 round enforced)', (
      tester,
    ) async {
      // Start in custom mode with exactly 1 round.
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          initialDelays: [3], // custom (not a preset)
          onComplete: (_) {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Precondition: exactly 1 custom round rendered.
      expect(find.byType(CustomDayEditorChip), findsNWidgets(1));

      // The implementation sets:
      //   onRemove: _customDelays.length > 1 ? () => ... : null
      // and CustomDayEditorChip only builds the "Remove" control at all when
      // onRemove is non-null (`if (onRemove != null) [...TextButton...]`) —
      // it renders as a TextButton (labelled via l10n.actionRemove), not an
      // IconButton with a close/cancel icon. With exactly 1 round, onRemove
      // is null, so the TextButton must be entirely absent from the tree.
      expect(
        find.byType(TextButton),
        findsNothing,
        reason: 'min-1 enforcement: no remove control when rounds == 1',
      );

      await _tearDown(tester);
    });

    testWidgets(
      'AUD-tracks-10 (AX-3): per-round day +/- TinyCircleButton controls '
      'expose non-empty, button-role Semantics labels',
      (tester) async {
        final handle = tester.ensureSemantics();

        await tester.pumpWidget(
          _buildChazaraApp(
            curriculumId: CurriculumId.mishnayos,
            initialDelays: [3], // not a preset → custom mode, 1 round
            onComplete: (_) {},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(CustomDayEditorChip), findsNWidgets(1));

        // Scope to descendants of the chip — Icons.add is otherwise
        // ambiguous with the sibling AddRoundChip (also Icons.add; see the
        // comments on the two tests above).
        final chip = find.byType(CustomDayEditorChip);
        final decreaseIcon = find.descendant(
          of: chip,
          matching: find.byIcon(Icons.remove),
        );
        final increaseIcon = find.descendant(
          of: chip,
          matching: find.byIcon(Icons.add),
        );
        expect(decreaseIcon, findsOneWidget);
        expect(increaseIcon, findsOneWidget);

        // AC2 (literal): a widget test finds a Semantics node with a button
        // role and non-empty label at each control's location.
        final decreaseSemantics = tester.getSemantics(decreaseIcon);
        final increaseSemantics = tester.getSemantics(increaseIcon);

        expect(
          decreaseSemantics,
          matchesSemantics(label: 'Decrease review day count', isButton: true),
          reason:
              'AUD-tracks-10: the per-round "decrease day" TinyCircleButton '
              'must expose a non-empty, button-role Semantics label',
        );
        expect(
          increaseSemantics,
          matchesSemantics(label: 'Increase review day count', isButton: true),
          reason:
              'AUD-tracks-10: the per-round "increase day" TinyCircleButton '
              'must expose a non-empty, button-role Semantics label',
        );
        expect(
          decreaseSemantics.label,
          isNot(equals(increaseSemantics.label)),
          reason: 'AUD-tracks-10: increase/decrease must carry distinct labels',
        );

        handle.dispose();
        await _tearDown(tester);
      },
    );

    testWidgets('Learn Only preset produces noReview wizard result', (
      tester,
    ) async {
      LearningProcessWizardResult? result;
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          onComplete: (r) => result = r,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap "Learn Only" preset.
      await tester.tap(find.text('Learn Only'));
      await tester.pump();

      // Confirm.
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(result, isNotNull);
      expect(
        result!.wizardResult.choice,
        WizardChoice.noReview,
        reason: 'Learn Only preset must produce WizardChoice.noReview result',
      );

      await _tearDown(tester);
    });

    testWidgets('1+7+30 preset produces 3 custom rounds with correct delays', (
      tester,
    ) async {
      LearningProcessWizardResult? result;
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          onComplete: (r) => result = r,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('1 + 7 + 30 days'));
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(result, isNotNull);
      final delays = result!.wizardResult.customRounds
          ?.map((r) => r.delayDays)
          .toList();
      expect(delays, [1, 7, 30]);

      await _tearDown(tester);
    });
  });

  // ── Group: RTL render ────────────────────────────────────────────────────

  group('EditTrackScreen — RTL locale renders without errors', () {
    testWidgets('Hebrew locale: screen mounts and shows AppBar title', (
      tester,
    ) async {
      final trackId = await seedTrack(
        db,
        profileId: 1,
        curriculumId: 'mishnayos',
      );
      await _seedGoal(db, profileId: 1, trackId: trackId);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userDatabaseProvider.overrideWith((ref) => db),
            trackEditServiceProvider.overrideWithValue(mockService),
            activeProfileIdProvider.overrideWith(() => _FakeActiveProfileId(1)),
            activeTutoredProfileSelectionProvider.overrideWith(
              () => _FakeActiveTutoredProfileSelection(),
            ),
            trackHasChazaraProvider(
              trackId,
            ).overrideWithValue(const AsyncData(false)),
            dashboardHasProgramEnrollmentProvider(
              CurriculumId.mishnayos,
            ).overrideWithValue(const AsyncData(false)),
            allDailyTasksProvider.overrideWith((ref) => Future.value([])),
            useHebrewTermsProvider.overrideWith(() => _FakeUseHebrewTerms()),
          ],
          child: MaterialApp(
            locale: const Locale('he'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: EditTrackScreen(track: _track(id: trackId)),
          ),
        ),
      );
      await _pump(tester);

      // Hebrew locale: AppBar title should be the Hebrew translation of
      // "Edit Track" (or English fallback if not translated) — just ensure
      // the screen renders without error.
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
      expect(tester.takeException(), isNull);

      await _tearDown(tester);
    });
  });

  // ── Group: no hardcoded strings ───────────────────────────────────────────

  group('EditTrackScreen — no hardcoded user-facing strings', () {
    test('screen source uses l10n for all key strings', () {
      // Verify that UI strings visible in the screen come from l10n keys, not
      // raw English literals embedded in the widget.
      const src = '''
trackEditTitle
trackEditSaveButton
trackEditConfirmTitle
trackEditConfirmBody
trackEditSectionName
trackEditSectionStudyDays
trackEditSectionReview
''';
      // All expected l10n keys should be referenced in the source file.
      final screenSrc = _readEditTrackScreenSource();
      for (final key in src.trim().split('\n')) {
        expect(
          screenSrc,
          contains(key),
          reason: 'EditTrackScreen must reference l10n key: $key',
        );
      }
    });
  });
}

// ── Source-read helper (for string audit) ─────────────────────────────────────

String _readEditTrackScreenSource() {
  try {
    final file = dart_io.File(
      'lib/features/tracks/setup/presentation/screens/edit_track_screen.dart',
    );
    return file.existsSync() ? file.readAsStringSync() : '';
  } catch (_) {
    return '';
  }
}
