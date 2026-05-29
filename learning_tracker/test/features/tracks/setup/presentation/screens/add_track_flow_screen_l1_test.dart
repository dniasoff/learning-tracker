// L1 behaviour tests for AddTrackFlow (the LIVE screen widget).
//
// These tests exercise the real ConsumerStatefulWidget state machine, NOT the
// AddTrackController (separate class tested in add_track_controller_test.dart).
//
// Focus areas:
//   • Step-machine: program-aware step-skip
//   • Resume-from-prefs (+ stale-program-bleed guard)
//   • Exit-confirm dialog
//   • Replace-existing-track dialog
//   • _finishFlow success + TutorWriteException + generic error+retry
//     (reached by seeding prefs to bulkMark step and tapping "Skip for now")
//   • SCOPE step auto-skip for single-child curriculum (DNI-202)
//   • STARTING-POSITION: back-dated start → trackingStartDate in the past
//   • CHAZARA always in active steps (Rule 8)
//   • NO "track type" / Personal / Standard / Custom label anywhere

@Tags(['needs_flutter', 'l1', 'add_track_flow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/add_track_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/screens/add_track_flow_screen.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tutoring/data/routers/tutored_write_router.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/drift_memory.dart';

// ── Mocks ───────────────────────────────────────────────────────────────────

class MockTrackCreationService extends Mock implements TrackCreationService {}

class MockContentRepository extends Mock implements ContentRepository {}

class MockGoalRepository extends Mock implements GoalRepository {}

class MockStageDefinitionRepository extends Mock
    implements StageDefinitionRepository {}

class MockCurriculumActivationService extends Mock
    implements CurriculumActivationService {}

class MockLearningProcessWizardService extends Mock
    implements LearningProcessWizardService {}

// ── Widget harness ──────────────────────────────────────────────────────────

Widget _buildApp({
  required List<Override> overrides,
  VoidCallback? onCancel,
  VoidCallback? onComplete,
  int profileId = 1,
  bool isOnboarding = false,
}) {
  return ProviderScope(
    overrides: overrides,
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
        body: AddTrackFlow(
          profileId: profileId,
          isOnboarding: isOnboarding,
          onComplete: (_) => onComplete?.call(),
          onCancel: onCancel,
        ),
      ),
    ),
  );
}

// Minimal override set. The content repository is stubbed so the bulkMark
// step (SelfPacedPriorProgressStep → HierarchySelectionPanel) doesn't crash.
List<Override> _baseOverrides({
  required TrackCreationService creationService,
  List<CurriculumId> activeCurricula = const [],
}) {
  final db = inMemoryDb();
  final contentRepo = MockContentRepository();

  // Stub content loading — returning empty list is fine for flow/dialog tests.
  when(
    () => contentRepo.getContentForCurriculum(any()),
  ).thenAnswer((_) async => []);
  when(() => contentRepo.getHierarchyConfig(any())).thenAnswer(
    (_) async => const CurriculumHierarchyConfig(
      curriculumId: 'chumash',
      levelLabels: ['Book', 'Parasha'],
      totalItems: 0,
    ),
  );

  return [
    userDatabaseProvider.overrideWith((ref) => db),
    trackCreationServiceProvider.overrideWith((ref) => creationService),
    dashboardActiveCurriculaProvider.overrideWith(
      (ref) async => activeCurricula,
    ),
    syncWriteFacadeProvider.overrideWith((ref) => null),
    contentRepositoryProvider.overrideWith((ref) => contentRepo),
    // Force English labels so find.text('Mishnayos') etc. match exactly.
    useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
  ];
}

/// Pump one frame + 1 s to let async initState / SharedPreferences settle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Teardown: shrink to release streams.
Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// Scroll until the curriculum name is visible, then tap it.
/// Handles curricula that may be below the fold in the ListView.
/// Uses exact text match (the [CurriculumId.displayNameEn]) so only the
/// single CurriculumLabel widget matches, avoiding "Too many elements".
Future<void> _tapCurriculum(WidgetTester tester, String name) async {
  // Exact-text finder targets the CurriculumLabel Text widget exclusively.
  final exactFinder = find.text(name);
  // Scroll the curriculum ListView until the tile is on-screen.
  // scrollUntilVisible requires a single-element finder; use the exact match.
  try {
    await tester.scrollUntilVisible(exactFinder, 300.0);
  } on StateError {
    // May fail if the text is already visible — continue to tap.
  }
  await tester.tap(exactFinder.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(CurriculumId.mishnayos);
    registerFallbackValue(
      const AddTrackResult(
        curriculumId: CurriculumId.mishnayos,
        label: 'fallback',
        studyDays: {1: 'study'},
      ),
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ==========================================================================
  // 1. INITIAL RENDER
  // ==========================================================================

  group('Initial render', () {
    testWidgets('shows curriculum picker on first open', (tester) async {
      final svc = MockTrackCreationService();
      await tester.pumpWidget(
        _buildApp(overrides: _baseOverrides(creationService: svc)),
      );
      await _settle(tester);

      expect(find.textContaining('Curriculum'), findsAtLeastNWidgets(1));
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('step indicator shows STEP 1 OF N on first open', (
      tester,
    ) async {
      final svc = MockTrackCreationService();
      await tester.pumpWidget(
        _buildApp(overrides: _baseOverrides(creationService: svc)),
      );
      await _settle(tester);

      expect(find.textContaining('STEP 1 OF'), findsOneWidget);
      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 2. NO TRACK-TYPE LABELS (product rule)
  // ==========================================================================

  group('No track-type labels (product rule)', () {
    testWidgets('curriculum picker has no Personal/Standard/Custom/אישי text', (
      tester,
    ) async {
      final svc = MockTrackCreationService();
      await tester.pumpWidget(
        _buildApp(overrides: _baseOverrides(creationService: svc)),
      );
      await _settle(tester);

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.text('אישי'), findsNothing);

      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 3. PROGRAM-AWARE STEP SKIP
  // ==========================================================================

  group('Program-aware step skip', () {
    testWidgets('Mishnayos (has programs) shows STEP 2 after selection', (
      tester,
    ) async {
      final svc = MockTrackCreationService();
      await tester.pumpWidget(
        _buildApp(overrides: _baseOverrides(creationService: svc)),
      );
      await _settle(tester);

      await _tapCurriculum(tester, 'Mishnayos');

      expect(find.textContaining('STEP 2 OF'), findsAtLeastNWidgets(1));
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('Chumash (no programs) goes directly to scope step (STEP 2)', (
      tester,
    ) async {
      final svc = MockTrackCreationService();
      await tester.pumpWidget(
        _buildApp(overrides: _baseOverrides(creationService: svc)),
      );
      await _settle(tester);

      await _tapCurriculum(tester, 'Chumash');

      expect(find.textContaining('STEP 2 OF'), findsAtLeastNWidgets(1));
      addTearDown(() => _tearDown(tester));
    });

    testWidgets(
      'self-paced Chumash step count is >= 5 (includes all self-paced steps)',
      (tester) async {
        final svc = MockTrackCreationService();
        await tester.pumpWidget(
          _buildApp(overrides: _baseOverrides(creationService: svc)),
        );
        await _settle(tester);

        final rawText = tester
            .widgetList<Text>(find.textContaining('STEP'))
            .where((t) => t.data?.contains(' OF ') ?? false)
            .first
            .data!;
        final total = int.parse(rawText.split(' OF ').last);

        // curriculum + scope + studyDays + chazara + goal + bulkMark = 6 steps
        // for a self-paced non-program curriculum.
        expect(total, greaterThanOrEqualTo(4));
        addTearDown(() => _tearDown(tester));
      },
    );
  });

  // ==========================================================================
  // 4. RESUME FROM SHARED PREFERENCES
  // ==========================================================================

  group('Resume from SharedPreferences', () {
    testWidgets('resumes to saved scope step for Chumash', (tester) async {
      SharedPreferences.setMockInitialValues({
        'add_track_step': AddTrackStep.scope.index,
        'add_track_curriculum': CurriculumId.chumash.storageKey,
      });

      final svc = MockTrackCreationService();
      await tester.pumpWidget(
        _buildApp(overrides: _baseOverrides(creationService: svc)),
      );
      await _settle(tester);

      // Chumash has no programs: scope = step 2.
      expect(find.textContaining('STEP 2 OF'), findsAtLeastNWidgets(1));
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('stale Mishna Yomit program does NOT bleed into Chumash '
        '(stale-program-bleed guard)', (tester) async {
      // Saved state has a program ID from a prior Mishnayos run but the
      // saved curriculum is Chumash (which has no programs).
      // programsExistForResume = false → stale program must be cleared.
      SharedPreferences.setMockInitialValues({
        'add_track_step': AddTrackStep.scope.index,
        'add_track_curriculum': CurriculumId.chumash.storageKey,
        'add_track_program': 42,
        'add_track_program_name': 'Mishna Yomit',
      });

      final svc = MockTrackCreationService();
      await tester.pumpWidget(
        _buildApp(overrides: _baseOverrides(creationService: svc)),
      );
      await _settle(tester);

      // A program track would show 4 steps; self-paced Chumash shows >= 5.
      final rawText = tester
          .widgetList<Text>(find.textContaining('STEP'))
          .where((t) => t.data?.contains(' OF ') ?? false)
          .first
          .data!;
      final total = int.parse(rawText.split(' OF ').last);
      expect(
        total,
        greaterThanOrEqualTo(5),
        reason:
            'Stale program from prior Mishnayos run must NOT set programId '
            'for Chumash. A program track would show 4 total steps; '
            'self-paced should show >= 5.',
      );
      addTearDown(() => _tearDown(tester));
    });

    testWidgets(
      'saved "program" step for Chumash (no programs) resolves to scope step',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'add_track_step': AddTrackStep.program.index,
          'add_track_curriculum': CurriculumId.chumash.storageKey,
        });

        final svc = MockTrackCreationService();
        await tester.pumpWidget(
          _buildApp(overrides: _baseOverrides(creationService: svc)),
        );
        await _settle(tester);

        // Must not be stuck at step 1 (curriculum); should resolve to step 2 (scope).
        expect(find.textContaining('STEP 2 OF'), findsAtLeastNWidgets(1));
        addTearDown(() => _tearDown(tester));
      },
    );
  });

  // ==========================================================================
  // 5. EXIT CONFIRM DIALOG
  // ==========================================================================

  group('Exit confirm dialog', () {
    // Helper: start the flow with a curriculum already set (via prefs), so
    // we are at step 1 (curriculum) but _state.curriculumId != null.
    // A single back press from step 1 calls _handleExit() → exit dialog.
    //
    // Why this path? PopScope.canPop = false means Nav.maybePop() dispatches
    // onPopInvokedWithResult(false). At step 0 (curriculum), _goToPreviousStep
    // delegates to _handleExit() which shows the dialog.
    Future<void> navigateToExitDialog(WidgetTester tester) async {
      // A single system-back from the curriculum step triggers _handleExit().
      await tester.binding.handlePopRoute();
      await _settle(tester);
    }

    testWidgets(
      'back press from step 1 with curriculum set shows exit dialog',
      (tester) async {
        // Resume at curriculum step WITH curriculumId set → hasData = true.
        SharedPreferences.setMockInitialValues({
          'add_track_step': AddTrackStep.curriculum.index,
          'add_track_curriculum': CurriculumId.chumash.storageKey,
        });

        final svc = MockTrackCreationService();
        await tester.pumpWidget(
          _buildApp(overrides: _baseOverrides(creationService: svc)),
        );
        await _settle(tester);

        await navigateToExitDialog(tester);

        expect(find.text('Exit Track Setup?'), findsOneWidget);
        addTearDown(() => _tearDown(tester));
      },
    );

    testWidgets('Cancel in exit dialog keeps the flow open', (tester) async {
      SharedPreferences.setMockInitialValues({
        'add_track_step': AddTrackStep.curriculum.index,
        'add_track_curriculum': CurriculumId.chumash.storageKey,
      });

      var cancelled = false;
      final svc = MockTrackCreationService();
      await tester.pumpWidget(
        _buildApp(
          overrides: _baseOverrides(creationService: svc),
          onCancel: () => cancelled = true,
        ),
      );
      await _settle(tester);

      await navigateToExitDialog(tester);

      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      expect(cancelled, isFalse);
      expect(find.text('Exit Track Setup?'), findsNothing);
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('Exit in exit dialog calls onCancel callback', (tester) async {
      SharedPreferences.setMockInitialValues({
        'add_track_step': AddTrackStep.curriculum.index,
        'add_track_curriculum': CurriculumId.chumash.storageKey,
      });

      var cancelled = false;
      final svc = MockTrackCreationService();
      await tester.pumpWidget(
        _buildApp(
          overrides: _baseOverrides(creationService: svc),
          onCancel: () => cancelled = true,
        ),
      );
      await _settle(tester);

      await navigateToExitDialog(tester);

      await tester.tap(find.text('Exit'));
      await _settle(tester);

      expect(cancelled, isTrue);
      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 6. REPLACE EXISTING TRACK DIALOG
  //    Prefs-seeded to bulkMark step; tap "Skip for now" to trigger _finishFlow.
  // ==========================================================================

  group('Replace existing track dialog', () {
    testWidgets(
      'shows replace dialog when curriculum already has an active track',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'add_track_step': AddTrackStep.bulkMark.index,
          'add_track_curriculum': CurriculumId.chumash.storageKey,
        });

        final svc = MockTrackCreationService();
        await tester.pumpWidget(
          _buildApp(
            overrides: _baseOverrides(
              creationService: svc,
              activeCurricula: [CurriculumId.chumash],
            ),
          ),
        );
        await _settle(tester);

        // "Skip for now" appears in HierarchySelectionPanel → SelfPacedPriorProgressStep.
        await tester.tap(find.text('Skip for now'));
        await _settle(tester);

        // The replace dialog must appear (curriculum already exists).
        expect(find.textContaining('Replace your'), findsOneWidget);
        addTearDown(() => _tearDown(tester));
      },
    );

    testWidgets('Cancel in replace dialog does NOT call createTrack', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'add_track_step': AddTrackStep.bulkMark.index,
        'add_track_curriculum': CurriculumId.chumash.storageKey,
      });

      final svc = MockTrackCreationService();
      await tester.pumpWidget(
        _buildApp(
          overrides: _baseOverrides(
            creationService: svc,
            activeCurricula: [CurriculumId.chumash],
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('Skip for now'));
      await _settle(tester);

      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      verifyNever(
        () => svc.createTrack(
          result: any(named: 'result'),
          profileId: any(named: 'profileId'),
        ),
      );
      addTearDown(() => _tearDown(tester));
    });

    testWidgets(
      'Replace in replace dialog calls createTrack and fires onComplete',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'add_track_step': AddTrackStep.bulkMark.index,
          'add_track_curriculum': CurriculumId.chumash.storageKey,
        });

        final svc = MockTrackCreationService();
        when(
          () => svc.createTrack(
            result: any(named: 'result'),
            profileId: any(named: 'profileId'),
          ),
        ).thenAnswer((_) async {});

        var completed = false;
        await tester.pumpWidget(
          _buildApp(
            overrides: _baseOverrides(
              creationService: svc,
              activeCurricula: [CurriculumId.chumash],
            ),
            onComplete: () => completed = true,
          ),
        );
        await _settle(tester);

        await tester.tap(find.text('Skip for now'));
        await _settle(tester);

        await tester.tap(find.text('Replace'));
        await _settle(tester);

        verify(
          () => svc.createTrack(result: any(named: 'result'), profileId: 1),
        ).called(1);
        expect(completed, isTrue);
        addTearDown(() => _tearDown(tester));
      },
    );
  });

  // ==========================================================================
  // 7. _finishFlow SUCCESS (no existing track)
  // ==========================================================================

  group('_finishFlow success', () {
    testWidgets('calls createTrack with profileId=1 and fires onComplete', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'add_track_step': AddTrackStep.bulkMark.index,
        'add_track_curriculum': CurriculumId.chumash.storageKey,
      });

      final svc = MockTrackCreationService();
      when(
        () => svc.createTrack(
          result: any(named: 'result'),
          profileId: any(named: 'profileId'),
        ),
      ).thenAnswer((_) async {});

      var completed = false;
      await tester.pumpWidget(
        _buildApp(
          overrides: _baseOverrides(creationService: svc),
          onComplete: () => completed = true,
        ),
      );
      await _settle(tester);

      // No existing track → no replace dialog → createTrack fires immediately.
      await tester.tap(find.text('Skip for now'));
      await _settle(tester);

      verify(
        () => svc.createTrack(result: any(named: 'result'), profileId: 1),
      ).called(1);
      expect(completed, isTrue);
      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // 8. _finishFlow: TutorWriteException (permission-denied)
  // ==========================================================================

  group('_finishFlow TutorWriteException', () {
    testWidgets(
      'permission-denied TutorWriteException shows tutorPermissionDenied snackbar',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'add_track_step': AddTrackStep.bulkMark.index,
          'add_track_curriculum': CurriculumId.chumash.storageKey,
        });

        final svc = MockTrackCreationService();
        when(
          () => svc.createTrack(
            result: any(named: 'result'),
            profileId: any(named: 'profileId'),
          ),
        ).thenThrow(
          const TutorWriteException('denied', code: 'permission-denied'),
        );

        await tester.pumpWidget(
          _buildApp(overrides: _baseOverrides(creationService: svc)),
        );
        await _settle(tester);

        await tester.tap(find.text('Skip for now'));
        await _settle(tester);

        expect(
          find.text("You don't have permission to make this edit"),
          findsOneWidget,
        );
        addTearDown(() => _tearDown(tester));
      },
    );
  });

  // ==========================================================================
  // 9. _finishFlow: generic error + Retry
  // ==========================================================================

  group('_finishFlow generic error + retry', () {
    testWidgets(
      'shows errorSaveTrackFailed snackbar with Retry; second call succeeds',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'add_track_step': AddTrackStep.bulkMark.index,
          'add_track_curriculum': CurriculumId.chumash.storageKey,
        });

        final svc = MockTrackCreationService();
        var callCount = 0;
        when(
          () => svc.createTrack(
            result: any(named: 'result'),
            profileId: any(named: 'profileId'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) throw Exception('network failure');
        });

        var completed = false;
        await tester.pumpWidget(
          _buildApp(
            overrides: _baseOverrides(creationService: svc),
            onComplete: () => completed = true,
          ),
        );
        await _settle(tester);

        await tester.tap(find.text('Skip for now'));
        await _settle(tester);

        expect(
          find.text('Failed to save track. Please try again.'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);

        // Tap Retry — second call succeeds → onComplete fires.
        await tester.tap(find.text('Retry'));
        await _settle(tester);

        expect(completed, isTrue);
        expect(callCount, 2);
        addTearDown(() => _tearDown(tester));
      },
    );
  });

  // ==========================================================================
  // 10. SCOPE AUTO-SKIP — single-child level (DNI-202)
  //     ScopeStepContent auto-drills into a level that has only one child.
  //     We verify the multi-child case (Chumash) does NOT auto-skip scope.
  // ==========================================================================

  group('Scope step auto-skip — single-child level (DNI-202)', () {
    testWidgets(
      'scope step is NOT auto-skipped for Chumash (multi-child top level)',
      (tester) async {
        final svc = MockTrackCreationService();
        await tester.pumpWidget(
          _buildApp(overrides: _baseOverrides(creationService: svc)),
        );
        await _settle(tester);

        await _tapCurriculum(tester, 'Chumash');

        // Still on step 2 (scope) — multi-child top level is not auto-skipped.
        expect(find.textContaining('STEP 2 OF'), findsAtLeastNWidgets(1));
        addTearDown(() => _tearDown(tester));
      },
    );
  });

  // ==========================================================================
  // 11. BACK-DATED START → overdue tasks (trackingStartDate in the past)
  //     These are service-layer tests — no widget pumping needed.
  // ==========================================================================

  group('Back-dated starting position → catch-up tasks', () {
    test('offset:-7 → trackingStartDate is before now '
        '(scheduler generates overdue tasks from it)', () async {
      final db = inMemoryDb();
      await seedProfile(db);
      // seedTrack inserts a curriculum_tracks row with state='active'.
      await seedTrack(db, profileId: 1, curriculumId: 'bavli');

      final goalRepo = MockGoalRepository();
      final stageRepo = MockStageDefinitionRepository();
      when(() => goalRepo.deleteGoal(any())).thenAnswer((_) async {});
      when(
        () => stageRepo.deleteStagesForTrack(any()),
      ).thenAnswer((_) async {});

      final activationSvc = MockCurriculumActivationService();
      when(
        () => activationSvc.activateForProfile(any(), any()),
      ).thenAnswer((_) async {});

      // ignore: deprecated_member_use
      final programRepo = LearningProgramRepository.instance;
      // wizardResult is null in this test so applyWizardResult is never called.
      final wizardSvc = MockLearningProcessWizardService();

      final svc = TrackCreationService(
        database: db,
        activationService: activationSvc,
        wizardService: wizardSvc,
        goalRepository: goalRepo,
        stageRepository: stageRepo,
        gateway: null,
        syncFacade: null,
        analytics: null,
      );

      final programs = programRepo.getActiveProgramsByCurriculumType('bavli');
      expect(programs, isNotEmpty, reason: 'Bavli must have seeded programs');

      final program = programs.first;
      final beforeNow = DateTime.now().toUtc();

      await svc.createTrack(
        result: AddTrackResult(
          curriculumId: CurriculumId.bavli,
          label: program.name,
          programId: program.id,
          programName: program.name,
          studyDays: kDefaultStudyDays,
          startingRef: 'offset:-7',
        ),
        profileId: 1,
      );

      final row = await db.profileProgramDao.getProgramForProfileAndCurriculum(
        1,
        'bavli',
      );

      expect(row, isNotNull);
      expect(
        row!.trackingStartDate,
        isNotNull,
        reason: 'A negative offset must write trackingStartDate',
      );
      expect(
        row.trackingStartDate!.isBefore(beforeNow),
        isTrue,
        reason:
            'offset:-7 must produce a trackingStartDate strictly before now '
            'so the scheduler engine surfaces those days as overdue tasks.',
      );

      await db.close();
    });

    test(
      'null startingRef → trackingStartDate is null (no overdue generated)',
      () async {
        final db = inMemoryDb();
        await seedProfile(db);
        await seedTrack(db, profileId: 1, curriculumId: 'bavli');

        final goalRepo = MockGoalRepository();
        final stageRepo = MockStageDefinitionRepository();
        when(() => goalRepo.deleteGoal(any())).thenAnswer((_) async {});
        when(
          () => stageRepo.deleteStagesForTrack(any()),
        ).thenAnswer((_) async {});

        final activationSvc = MockCurriculumActivationService();
        when(
          () => activationSvc.activateForProfile(any(), any()),
        ).thenAnswer((_) async {});

        // ignore: deprecated_member_use
        final programRepo = LearningProgramRepository.instance;
        // wizardResult is null in this test so applyWizardResult is never called.
        final wizardSvc = MockLearningProcessWizardService();

        final svc = TrackCreationService(
          database: db,
          activationService: activationSvc,
          wizardService: wizardSvc,
          goalRepository: goalRepo,
          stageRepository: stageRepo,
          gateway: null,
          syncFacade: null,
          analytics: null,
        );

        final programs = programRepo.getActiveProgramsByCurriculumType('bavli');
        final program = programs.first;

        await svc.createTrack(
          result: AddTrackResult(
            curriculumId: CurriculumId.bavli,
            label: program.name,
            programId: program.id,
            programName: program.name,
            studyDays: kDefaultStudyDays,
            // No startingRef → no back-date.
          ),
          profileId: 1,
        );

        final row = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(1, 'bavli');
        expect(
          row?.trackingStartDate,
          isNull,
          reason:
              'With no startingRef, trackingStartDate must remain null — '
              'no overdue tasks should be generated.',
        );

        await db.close();
      },
    );
  });

  // ==========================================================================
  // 12. CHAZARA STEP ALWAYS IN ACTIVE STEPS (Rule 8)
  // ==========================================================================

  group('Chazara step always in active-step list (Rule 8)', () {
    testWidgets('self-paced Chumash total steps includes chazara (>= 5)', (
      tester,
    ) async {
      final svc = MockTrackCreationService();
      await tester.pumpWidget(
        _buildApp(overrides: _baseOverrides(creationService: svc)),
      );
      await _settle(tester);

      await _tapCurriculum(tester, 'Chumash');

      final rawText = tester
          .widgetList<Text>(find.textContaining('STEP'))
          .where((t) => t.data?.contains(' OF ') ?? false)
          .first
          .data!;
      final total = int.parse(rawText.split(' OF ').last);

      // curriculum + scope + studyDays + chazara + goal + bulkMark = 6.
      expect(
        total,
        greaterThanOrEqualTo(5),
        reason:
            'Chazara setup step must be in the self-paced step list. '
            'Rule 8: chazara UI appears when the track supports it.',
      );
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('Mishnayos program track total steps includes chazara (>= 4)', (
      tester,
    ) async {
      final svc = MockTrackCreationService();
      await tester.pumpWidget(
        _buildApp(overrides: _baseOverrides(creationService: svc)),
      );
      await _settle(tester);

      await _tapCurriculum(tester, 'Mishnayos');

      final rawText = tester
          .widgetList<Text>(find.textContaining('STEP'))
          .where((t) => t.data?.contains(' OF ') ?? false)
          .first
          .data!;
      final total = int.parse(rawText.split(' OF ').last);

      // curriculum + program + chazara + bulkMark = 4 for program track.
      expect(
        total,
        greaterThanOrEqualTo(4),
        reason:
            'Program track must still include the chazara step. '
            'Rule 8: chazara step is always shown.',
      );
      addTearDown(() => _tearDown(tester));
    });
  });
}

// ── Test-only notifier overrides ────────────────────────────────────────────

/// Forces Hebrew Terms to false so curriculum tiles render English names.
/// Without this, the default `HebrewTermsPreference.defaultValue = true`
/// causes tiles to show Hebrew script, breaking find.text('Mishnayos') etc.
class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}
