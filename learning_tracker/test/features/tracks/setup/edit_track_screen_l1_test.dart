// L1 widget tests — EditTrackScreen + ChazaraInlineSetup
//
// Covers:
//   • Renders current track name, goal section and study-days section.
//   • Save → confirm dialog → service.editTrack() call verified via mocktail.
//   • Confirm dialog cancel path (no save call).
//   • ChazaraInlineSetup: quick-fill chips populate typed, validated review
//     intervals; add/remove and legacy plan round-trips are covered.
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

// ignore_for_file: directives_ordering, unused_element_parameter, prefer_const_constructors

import 'dart:io' as dart_io;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_edit_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_edit_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/edit_track_screen.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_chazara.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/firestore_fake.dart';
import '../../../helpers/firestore_fixtures.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockTrackEditService extends Mock implements TrackEditService {}

// ── Helpers ───────────────────────────────────────────────────────────────────

late FirestoreCurriculumTrackRepository _trackRepository;
late FirestoreGoalRepository _goalRepository;
late FirestoreStageDefinitionRepository _stageRepository;
late FirestoreStudyDayConfigRepository _studyDayRepository;

/// Firestore-native fixtures for the current curriculum-scoped track model.
const _uid = 'edit-track-screen-test-uid';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY3';

CurriculumTrackEntity _track({String curriculumId = 'mishnayos'}) =>
    CurriculumTrackEntity(
      curriculumId: CurriculumId.fromStorageKey(curriculumId)!,
      state: 'active',
      activatedAt: DateTime.utc(2026, 1, 1),
    );

Future<void> _seedGoal(
  FakeFirebaseFirestore firestore, {
  String curriculumId = 'mishnayos',
  String description = 'Test Track',
  String goalType = 'pace',
  int paceValue = 3,
  String pacePeriod = 'per_week',
}) async {
  await seedGoal(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: CurriculumId.fromStorageKey(curriculumId)!,
    description: description,
    goalType: goalType,
    paceValue: goalType == 'pace' ? paceValue : null,
    pacePeriod: goalType == 'pace' ? pacePeriod : null,
  );
}

Future<void> _seedLearnStage(
  FakeFirebaseFirestore firestore, {
  String curriculumId = 'mishnayos',
}) async {
  final curriculum = CurriculumId.fromStorageKey(curriculumId)!;
  await seedStageDefinitions(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: curriculum,
    stages: [
      StageDefinition(
        curriculumId: curriculum,
        stageOrder: 1,
        stageName: 'Learn',
        delayDays: 0,
        isDefault: false,
        scheduleType: ScheduleType.delay,
      ),
    ],
  );
}

Future<void> _seedChazaraStages(
  FakeFirebaseFirestore firestore, {
  String curriculumId = 'mishnayos',
}) async {
  final curriculum = CurriculumId.fromStorageKey(curriculumId)!;
  await seedStageDefinitions(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: curriculum,
    stages: [
      for (final stage in [(1, 'Learn', 0), (2, 'Chazara 1', 1)])
        StageDefinition(
          curriculumId: curriculum,
          stageOrder: stage.$1,
          stageName: stage.$2,
          delayDays: stage.$3,
          isDefault: false,
          scheduleType: ScheduleType.delay,
        ),
    ],
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
  required CurriculumTrackEntity track,
  required FakeFirebaseFirestore db,
  required _MockTrackEditService mockService,
  bool hasChazara = false,
  List<DailyTask> dailyTasks = const [],
  bool useHebrew = false,
  TransliterationVariant? variant,
}) {
  return ProviderScope(
    overrides: [
      firestoreCurriculumTrackRepositoryProvider.overrideWith(
        (ref) async => _trackRepository,
      ),
      firestoreGoalRepositoryProvider.overrideWith(
        (ref) async => _goalRepository,
      ),
      firestoreStageDefinitionRepositoryProvider.overrideWith(
        (ref) async => _stageRepository,
      ),
      firestoreStudyDayConfigRepositoryProvider.overrideWith(
        (ref) async => _studyDayRepository,
      ),
      trackEditServiceProvider.overrideWithValue(mockService),
      activeProfileIdProvider.overrideWith(
        () => _FakeActiveProfileId(_profileId),
      ),
      activeTutoredProfileSelectionProvider.overrideWith(
        () => _FakeActiveTutoredProfileSelection(),
      ),
      trackHasChazaraProvider(
        track.curriculumId,
      ).overrideWithValue(AsyncData(hasChazara)),
      dashboardHasProgramEnrollmentProvider(
        CurriculumId.values.where((c) => c == track.curriculumId).first,
      ).overrideWithValue(const AsyncData(false)),
      dashboardActiveCurriculaProvider.overrideWith(
        (ref) => Future.value([track.curriculumId]),
      ),
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
      firestoreCurriculumTrackRepositoryProvider.overrideWith(
        (ref) async => _trackRepository,
      ),
      firestoreGoalRepositoryProvider.overrideWith(
        (ref) async => _goalRepository,
      ),
      firestoreStageDefinitionRepositoryProvider.overrideWith(
        (ref) async => _stageRepository,
      ),
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
  final String _value;
  @override
  String build() => _value;
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
    registerFallbackValue(
      GoalEntity(
        curriculumId: CurriculumId.mishnayos,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
  });

  late FakeFirebaseFirestore db;
  late _MockTrackEditService mockService;

  setUp(() async {
    db = createFakeFirestore(authenticatedUid: _uid);
    _trackRepository = FirestoreCurriculumTrackRepository(
      firestore: db,
      uid: _uid,
      profileId: _profileId,
    );
    _goalRepository = FirestoreGoalRepository(
      firestore: db,
      uid: _uid,
      profileId: _profileId,
    );
    _stageRepository = FirestoreStageDefinitionRepository(
      firestore: db,
      uid: _uid,
      profileId: _profileId,
    );
    _studyDayRepository = FirestoreStudyDayConfigRepository(
      firestore: db,
      uid: _uid,
      profileId: _profileId,
    );
    mockService = _MockTrackEditService();
    // Default stub: editTrack completes successfully.
    when(
      () => mockService.editTrack(
        goal: any(named: 'goal'),
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

  tearDown(() async {});

  // ── Group: initial render ─────────────────────────────────────────────────

  group('EditTrackScreen — initial render', () {
    testWidgets('shows AppBar title "Edit Track"', (tester) async {
      await _seedGoal(db);

      await tester.pumpWidget(
        _buildApp(track: _track(), db: db, mockService: mockService),
      );
      await _pump(tester);

      expect(find.text('Edit Track'), findsWidgets);
      expect(find.byType(AppBar), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('renders current track name in name field', (tester) async {
      await _seedGoal(db, description: 'My Mishnayos');

      await tester.pumpWidget(
        _buildApp(track: _track(), db: db, mockService: mockService),
      );
      await _pump(tester);

      // The name TextField should contain the goal's description.
      expect(find.widgetWithText(TextField, 'My Mishnayos'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows Goal section when goal exists', (tester) async {
      await _seedGoal(db);

      await tester.pumpWidget(
        _buildApp(track: _track(), db: db, mockService: mockService),
      );
      await _pump(tester);

      // "Goal" section heading must be visible.
      expect(find.text('Goal'), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('shows Study Days section for non-program track', (
      tester,
    ) async {
      await _seedGoal(db);

      await tester.pumpWidget(
        _buildApp(track: _track(), db: db, mockService: mockService),
      );
      await _pump(tester);

      expect(find.text('Study Days'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets('shows "Save Changes" button', (tester) async {
      await _seedGoal(db);

      await tester.pumpWidget(
        _buildApp(track: _track(), db: db, mockService: mockService),
      );
      await _pump(tester);

      expect(find.text('Save Changes'), findsOneWidget);

      await _tearDown(tester);
    });

    testWidgets(
      'no "track type" / Personal / Standard / Custom label visible',
      (tester) async {
        await _seedGoal(db);

        await tester.pumpWidget(
          _buildApp(track: _track(), db: db, mockService: mockService),
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
      await _seedGoal(
        db,
        goalType: 'pace',
        paceValue: 3,
        pacePeriod: 'per_week',
      );

      await tester.pumpWidget(
        _buildApp(track: _track(), db: db, mockService: mockService),
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
        await _seedGoal(
          db,
          goalType: 'pace',
          paceValue: 3,
          pacePeriod: 'per_week',
        );

        await tester.pumpWidget(
          _buildApp(track: _track(), db: db, mockService: mockService),
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
      await _seedGoal(db);

      await tester.pumpWidget(
        _buildApp(
          track: _track(),
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
      await _seedGoal(db);

      await tester.pumpWidget(
        _buildApp(
          track: _track(),
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
      await _seedGoal(db);

      await tester.pumpWidget(
        _buildApp(
          track: _track(),
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
      await _seedGoal(db);

      await tester.pumpWidget(
        _buildApp(track: _track(), db: db, mockService: mockService),
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
      await _seedGoal(db);

      await tester.pumpWidget(
        _buildApp(track: _track(), db: db, mockService: mockService),
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
          goal: any(named: 'goal'),
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
      await _seedGoal(db);

      await tester.pumpWidget(
        _buildApp(track: _track(), db: db, mockService: mockService),
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
          goal: any(named: 'goal'),
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
      await _seedGoal(db, description: 'Old Name');

      await tester.pumpWidget(
        _buildApp(track: _track(), db: db, mockService: mockService),
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
          goal: any(named: 'goal'),
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
      await _seedGoal(db);
      await _seedChazaraStages(db);

      await tester.pumpWidget(
        _buildApp(
          track: _track(),
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

    testWidgets('Edit Track opens the shared editable review plan', (
      tester,
    ) async {
      _setTallViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _seedGoal(db);
      await _seedChazaraStages(db);

      await tester.pumpWidget(
        _buildApp(
          track: _track(),
          db: db,
          mockService: mockService,
          hasChazara: true,
        ),
      );
      await _pump(tester);
      await tester.tap(find.text('Change').first);
      await tester.pumpAndSettle();

      expect(find.text('Review intervals'), findsOneWidget);
      expect(find.text('Learn only'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);

      await _tearDown(tester);
    });

    testWidgets('track WITHOUT chazara stages shows NO Review section', (
      tester,
    ) async {
      _setTallViewport(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _seedGoal(db);
      // Only learn stage — no chazara.
      await _seedLearnStage(db);

      await tester.pumpWidget(
        _buildApp(
          track: _track(),
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
        await _seedGoal(db);

        await tester.pumpWidget(
          _buildApp(
            track: _track(),
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

  // ── Group: ChazaraInlineSetup — editable review plan ────────────────────

  group('ChazaraInlineSetup — editable review plan', () {
    testWidgets('quick-fill chips populate the editable interval list', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          onComplete: (_) {},
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Learn only'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ChoiceChip).at(1),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(find.text('1+7'), findsOneWidget);
      expect(find.text('1+7+30'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        '1',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        '7',
      );
      expect(find.text('Custom Cycle'), findsNothing);
      await _tearDown(tester);
    });

    testWidgets('typing, adding and removing intervals saves the edited plan', (
      tester,
    ) async {
      LearningProcessWizardResult? result;
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          initialDelays: [2, 5],
          onComplete: (r) => result = r,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField).at(0), '3');
      await tester.tap(find.text('Add interval'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(3));
      await tester.enterText(find.byType(TextField).at(2), '30');
      await tester.tap(find.byTooltip('Remove review interval 2'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(result!.wizardResult.customRounds!.map((r) => r.delayDays), [
        3,
        30,
      ]);
      await _tearDown(tester);
    });

    testWidgets('an existing custom cycle round-trips with identical delays', (
      tester,
    ) async {
      LearningProcessWizardResult? result;
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          initialDelays: [2, 9, 40],
          onComplete: (r) => result = r,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(result!.wizardResult.customRounds!.map((r) => r.delayDays), [
        2,
        9,
        40,
      ]);
      await _tearDown(tester);
    });

    testWidgets('review plans can exceed the old five-session UI cap', (
      tester,
    ) async {
      LearningProcessWizardResult? result;
      const delays = [1, 2, 3, 4, 5, 6];
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          initialDelays: delays,
          onComplete: (r) => result = r,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(TextField), findsNWidgets(6));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(
        result!.wizardResult.customRounds!.map((r) => r.delayDays),
        delays,
      );
      await _tearDown(tester);
    });

    testWidgets(
      'preset rounds preserve stored delays and invalid plans show errors',
      (tester) async {
        LearningProcessWizardResult? result;
        await tester.pumpWidget(
          _buildChazaraApp(
            curriculumId: CurriculumId.mishnayos,
            onComplete: (r) => result = r,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('1+7+30'));
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(result!.wizardResult.customRounds!.map((r) => r.delayDays), [
          1,
          7,
          30,
        ]);
        await _tearDown(tester);

        await tester.pumpWidget(
          _buildChazaraApp(
            curriculumId: CurriculumId.mishnayos,
            initialDelays: [1, 7],
            onComplete: (_) {},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.enterText(find.byType(TextField).at(0), '8');
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(
          find.text('Each interval must be greater than the one before it.'),
          findsOneWidget,
        );
        await _tearDown(tester);
      },
    );

    testWidgets('stored intervals above the input limit round-trip unchanged', (
      tester,
    ) async {
      LearningProcessWizardResult? result;
      const delays = [10000, 1000000];
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          initialDelays: delays,
          onComplete: (r) => result = r,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        '10000',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        '1000000',
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(
        result!.wizardResult.customRounds!.map((round) => round.delayDays),
        delays,
      );
      await _tearDown(tester);
    });

    testWidgets('Learn only quick-fill emits no review', (tester) async {
      LearningProcessWizardResult? result;
      await tester.pumpWidget(
        _buildChazaraApp(
          curriculumId: CurriculumId.mishnayos,
          onComplete: (r) => result = r,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Learn only'));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(result!.wizardResult.choice, WizardChoice.noReview);
      await _tearDown(tester);
    });
  });

  group('EditTrackScreen — RTL locale renders without errors', () {
    testWidgets('Hebrew locale: screen mounts and shows AppBar title', (
      tester,
    ) async {
      await _seedGoal(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreCurriculumTrackRepositoryProvider.overrideWith(
              (ref) async => _trackRepository,
            ),
            firestoreGoalRepositoryProvider.overrideWith(
              (ref) async => _goalRepository,
            ),
            firestoreStageDefinitionRepositoryProvider.overrideWith(
              (ref) async => _stageRepository,
            ),
            firestoreStudyDayConfigRepositoryProvider.overrideWith(
              (ref) async => _studyDayRepository,
            ),
            trackEditServiceProvider.overrideWithValue(mockService),
            activeProfileIdProvider.overrideWith(
              () => _FakeActiveProfileId(_profileId),
            ),
            activeTutoredProfileSelectionProvider.overrideWith(
              () => _FakeActiveTutoredProfileSelection(),
            ),
            trackHasChazaraProvider(
              CurriculumId.mishnayos,
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
            home: EditTrackScreen(track: _track()),
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
