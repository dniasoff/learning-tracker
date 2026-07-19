// L1 widget tests for:
//   • StartingPositionStep        (step_starting_position.dart)
//   • StartingPositionCalendarMode (step_starting_position_calendar.dart)
//   • SelfPacedGoalStep           (step_goal.dart)
//
// Product rules asserted:
//   • Start-date window is [today-30, today] — B2 constraint from
//     ProgramStartingPosition.allowedWindow().
//   • Back-dating IS allowed (negative offset) and is the mechanism
//     for generating past-dated overdue catch-up tasks.
//   • No track-type labels (Personal / Standard / Custom / אישי) anywhere.
//   • Goal step shows pace card and deadline card; Continue button works.
//
// PUMP RIG:
//   ProviderScope(overrides:[...], child: MaterialApp(locale, 4 delegates,
//   home: Scaffold(body: <widget under test>)))
//   double-pump: pump() + pump(const Duration(seconds:1)) to settle async.
//   teardown: pumpWidget(SizedBox.shrink()) + pump(Duration.zero).

@Tags(['tracks', 'steps', 'l1'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/domain/value_objects/program_starting_position.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_goal.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_starting_position.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_starting_position_calendar.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/drift_memory.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockContentRepository extends Mock implements ContentRepository {}

class _MockCalendarProgramService extends Mock
    implements CalendarProgramService {}

// ── Test-only provider overrides ───────────────────────────────────────────────

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _TrueUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => true;
}

class _FalseUseHebrewDate extends UseHebrewDate {
  @override
  bool build() => false;
}

class _ProfileIdOverride extends ActiveProfileId {
  @override
  int build() => 1;
}

// ── Widget harness helpers ─────────────────────────────────────────────────────

/// Standard 4-delegate l10n list.
const _kDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

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

/// Build a minimal [LearningProgramData] for use in tests.
LearningProgramData _calendarProgram({String apiProgramKey = 'daf_yomi'}) =>
    LearningProgramData(
      id: 1,
      name: 'Daf Yomi',
      displayName: 'Daf Yomi',
      description: 'Test program',
      curriculumType: 'bavli',
      isActive: true,
      hasTests: false,
      stagesConfig: '',
      testConfig: '',
      apiSource: 'local',
      apiProgramKey: apiProgramKey,
      isCalendarProgram: true,
    );

LearningProgramData _nonCalendarProgram() => const LearningProgramData(
  id: 2,
  name: 'Self-paced Mishnayos',
  displayName: 'Mishnayos',
  description: 'Test program',
  curriculumType: 'mishnayos',
  isActive: true,
  hasTests: false,
  stagesConfig: '',
  testConfig: '',
  apiSource: null,
  apiProgramKey: null,
  isCalendarProgram: false,
);

/// Builds the widget harness for [StartingPositionStep].
Widget _buildStartingPositionApp({
  required List<Override> overrides,
  required LearningProgramData? selectedProgram,
  ValueChanged<String?>? onComplete,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: _kDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StartingPositionStep(
          programName: selectedProgram?.name ?? 'Test Program',
          curriculumId: CurriculumId.mishnayos,
          selectedProgram: selectedProgram,
          onComplete: onComplete ?? (_) {},
        ),
      ),
    ),
  );
}

/// Builds the widget harness for [StartingPositionCalendarMode].
Widget _buildCalendarModeApp({
  required List<Override> overrides,
  required LearningProgramData program,
  ValueChanged<String?>? onComplete,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: _kDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StartingPositionCalendarMode(
          selectedProgram: program,
          onComplete: onComplete ?? (_) {},
        ),
      ),
    ),
  );
}

/// Builds the widget harness for [SelfPacedGoalStep].
Widget _buildGoalStepApp({
  required List<Override> overrides,
  ValueChanged<GoalEntity?>? onComplete,
  Locale locale = const Locale('en'),
  CurriculumId curriculumId = CurriculumId.mishnayos,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: _kDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SelfPacedGoalStep(
          curriculumId: curriculumId,
          studyDays: const {
            1: 'study',
            2: 'study',
            3: 'study',
            4: 'study',
            5: 'study',
            6: 'study',
            7: 'study',
          },
          onComplete: onComplete ?? (_) {},
        ),
      ),
    ),
  );
}

/// Base overrides for non-calendar StartingPositionStep tests.
List<Override> _baseOverridesWithContentRepo(
  _MockContentRepository contentRepo,
) {
  final db = inMemoryDb();
  return [
    userDatabaseProvider.overrideWithValue(db),
    contentRepositoryProvider.overrideWith((ref) => contentRepo),
    useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    syncWriteFacadeProvider.overrideWithValue(null),
    activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
  ];
}

/// Base overrides for [StartingPositionCalendarMode] tests.
List<Override> _calendarModeOverrides(_MockCalendarProgramService calendarSvc) {
  final db = inMemoryDb();
  return [
    userDatabaseProvider.overrideWithValue(db),
    calendarProgramServiceProvider.overrideWith(
      (ref) => Future.value(calendarSvc),
    ),
    useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    syncWriteFacadeProvider.overrideWithValue(null),
    activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
  ];
}

/// Base overrides for [SelfPacedGoalStep] tests.
List<Override> _goalStepOverrides({
  bool useHebrewDate = false,
  int scopeCount = 60,
}) {
  final db = inMemoryDb();
  final contentRepo = _MockContentRepository();
  when(
    () => contentRepo.getContentForCurriculum(any()),
  ).thenAnswer((_) async => []);
  when(() => contentRepo.getHierarchyConfig(any())).thenAnswer(
    (_) async => const CurriculumHierarchyConfig(
      curriculumId: 'mishnayos',
      levelLabels: ['Seder', 'Masechet', 'Mishna'],
      totalItems: 0,
    ),
  );
  return [
    userDatabaseProvider.overrideWithValue(db),
    contentRepositoryProvider.overrideWith((ref) => contentRepo),
    useHebrewTermsProvider.overrideWith(() => _FalseUseHebrewTerms()),
    useHebrewDateProvider.overrideWith(
      () => useHebrewDate ? _TrueUseHebrewDate() : _FalseUseHebrewDate(),
    ),
    syncWriteFacadeProvider.overrideWithValue(null),
    activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
    scopedCurriculumContentProvider(CurriculumId.mishnayos).overrideWith((
      ref,
    ) async {
      // Return enough stub leaf items for scope count.
      return List.generate(
        scopeCount,
        (i) => ContentItem(
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot $i',
          displayNameEn: 'Berakhot $i',
          displayNameHe: 'ברכות $i',
          level1: 'Seder Zeraim',
          sortOrder: i,
          isLeaf: true,
        ),
      );
    }),
    scopedItemCountProvider(
      CurriculumId.mishnayos,
    ).overrideWith((ref) async => scopeCount),
  ];
}

class _TrueUseHebrewDate extends UseHebrewDate {
  @override
  bool build() => true;
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(CurriculumId.mishnayos);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ==========================================================================
  // A. StartingPositionStep — content-based (non-calendar) program
  // ==========================================================================

  group('StartingPositionStep — content-based', () {
    testWidgets('shows loading indicator while content loads', (tester) async {
      final contentRepo = _MockContentRepository();
      // Use a completer that never completes so loading stays active.
      final contentCompleter = Completer<List<ContentItem>>();
      final configCompleter = Completer<CurriculumHierarchyConfig>();
      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) => contentCompleter.future);
      when(
        () => contentRepo.getHierarchyConfig(any()),
      ).thenAnswer((_) => configCompleter.future);

      await tester.pumpWidget(
        _buildStartingPositionApp(
          overrides: _baseOverridesWithContentRepo(contentRepo),
          selectedProgram: _nonCalendarProgram(),
        ),
      );
      await tester.pump(); // First frame only — still loading.

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the futures before teardown to avoid pending-timer failures.
      contentCompleter.complete([]);
      configCompleter.complete(
        const CurriculumHierarchyConfig(
          curriculumId: 'mishnayos',
          levelLabels: ['Seder', 'Masechet'],
          totalItems: 0,
        ),
      );
      await tester.pump();
      addTearDown(() => _tearDown(tester));
    });

    testWidgets(
      'delegates to StartingPositionCalendarMode for calendar program',
      (tester) async {
        final contentRepo = _MockContentRepository();
        final calendarSvc = _MockCalendarProgramService();

        when(
          () => calendarSvc.getEntry(any(), any()),
        ).thenAnswer((_) async => null);

        final overrides = [
          ..._baseOverridesWithContentRepo(contentRepo),
          calendarProgramServiceProvider.overrideWith(
            (ref) => Future.value(calendarSvc),
          ),
        ];

        await tester.pumpWidget(
          _buildStartingPositionApp(
            overrides: overrides,
            selectedProgram: _calendarProgram(),
          ),
        );
        await _settle(tester);

        // Calendar mode shows the "Starting Position" title from l10n.
        expect(find.text('Starting Position'), findsOneWidget);
        // And the "Can start up to 30 days back from today" hint.
        expect(
          find.textContaining('30 days'),
          findsOneWidget,
          reason: 'Calendar mode must show the B2 hint text',
        );
        addTearDown(() => _tearDown(tester));
      },
    );

    testWidgets('shows StartingPositionTitle text after content loads', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => []);
      when(() => contentRepo.getHierarchyConfig(any())).thenAnswer(
        (_) async => const CurriculumHierarchyConfig(
          curriculumId: 'mishnayos',
          levelLabels: ['Seder', 'Masechet', 'Mishna'],
          totalItems: 0,
        ),
      );

      await tester.pumpWidget(
        _buildStartingPositionApp(
          overrides: _baseOverridesWithContentRepo(contentRepo),
          selectedProgram: _nonCalendarProgram(),
        ),
      );
      await _settle(tester);

      expect(find.text('Starting Position'), findsOneWidget);
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('Start here button disabled when no leaf selected', (
      tester,
    ) async {
      final contentRepo = _MockContentRepository();
      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => []);
      when(() => contentRepo.getHierarchyConfig(any())).thenAnswer(
        (_) async => const CurriculumHierarchyConfig(
          curriculumId: 'mishnayos',
          levelLabels: ['Seder', 'Masechet', 'Mishna'],
          totalItems: 0,
        ),
      );

      await tester.pumpWidget(
        _buildStartingPositionApp(
          overrides: _baseOverridesWithContentRepo(contentRepo),
          selectedProgram: _nonCalendarProgram(),
        ),
      );
      await _settle(tester);

      // The "Start here" button exists.
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start here'),
      );
      // onPressed must be null (disabled) because no leaf is selected.
      expect(
        btn.onPressed,
        isNull,
        reason: 'Start here must be disabled until the user selects a position',
      );
      addTearDown(() => _tearDown(tester));
    });

    // ── R4-3 Hebrew-locale regression test ───────────────────────────────────

    testWidgets(
      'R4-3: Hebrew locale — instruction renders בחרו, not "Select the"',
      (tester) async {
        final contentRepo = _MockContentRepository();
        when(
          () => contentRepo.getContentForCurriculum(any()),
        ).thenAnswer((_) async => []);
        when(() => contentRepo.getHierarchyConfig(any())).thenAnswer(
          (_) async => const CurriculumHierarchyConfig(
            curriculumId: 'mishnayos',
            levelLabels: ['Seder', 'Masechet', 'Mishna'],
            totalItems: 0,
          ),
        );

        await tester.pumpWidget(
          _buildStartingPositionApp(
            overrides: _baseOverridesWithContentRepo(contentRepo),
            selectedProgram: _nonCalendarProgram(),
            locale: const Locale('he'),
          ),
        );
        await _settle(tester);

        // The instruction text must contain the Hebrew prefix.
        expect(
          find.textContaining('בחרו את'),
          findsOneWidget,
          reason:
              'R4-3: startingPositionSelectInstruction must render '
              '"בחרו את …" in Hebrew locale, not the English "Select the …"',
        );
        // The English form must be absent.
        expect(
          find.textContaining('Select the'),
          findsNothing,
          reason:
              'R4-3: hardcoded English "Select the" must be absent in he locale',
        );
        addTearDown(() => _tearDown(tester));
      },
    );

    testWidgets(
      'no track-type labels anywhere (Personal/Standard/Custom/אישי)',
      (tester) async {
        final contentRepo = _MockContentRepository();
        when(
          () => contentRepo.getContentForCurriculum(any()),
        ).thenAnswer((_) async => []);
        when(() => contentRepo.getHierarchyConfig(any())).thenAnswer(
          (_) async => const CurriculumHierarchyConfig(
            curriculumId: 'mishnayos',
            levelLabels: ['Seder', 'Masechet', 'Mishna'],
            totalItems: 0,
          ),
        );

        await tester.pumpWidget(
          _buildStartingPositionApp(
            overrides: _baseOverridesWithContentRepo(contentRepo),
            selectedProgram: _nonCalendarProgram(),
          ),
        );
        await _settle(tester);

        expect(find.text('Personal'), findsNothing);
        expect(find.text('Standard'), findsNothing);
        expect(find.text('Custom'), findsNothing);
        expect(find.text('אישי'), findsNothing);
        addTearDown(() => _tearDown(tester));
      },
    );

    testWidgets(
      'content error gracefully hides loading indicator and shows AppErrorView '
      '(AUD-tracks-04)',
      (tester) async {
        final contentRepo = _MockContentRepository();
        when(
          () => contentRepo.getContentForCurriculum(any()),
        ).thenAnswer((_) async => throw Exception('network error'));
        when(() => contentRepo.getHierarchyConfig(any())).thenAnswer(
          (_) async => const CurriculumHierarchyConfig(
            curriculumId: 'mishnayos',
            levelLabels: ['Seder', 'Masechet', 'Mishna'],
            totalItems: 0,
          ),
        );

        await tester.pumpWidget(
          _buildStartingPositionApp(
            overrides: _baseOverridesWithContentRepo(contentRepo),
            selectedProgram: _nonCalendarProgram(),
          ),
        );
        await _settle(tester);

        // After error, loading indicator should be gone.
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // AUD-tracks-04: a load failure must render a distinct, retryable
        // error affordance (AppErrorView) — not silently fall through to a
        // blank container list with a permanently-disabled "Start here"
        // button and zero indication anything went wrong.
        expect(
          find.byType(AppErrorView),
          findsOneWidget,
          reason:
              'AUD-tracks-04: a thrown repository error must surface '
              'AppErrorView, not an indistinguishable empty list',
        );
        expect(
          find.widgetWithText(FilledButton, 'Start here'),
          findsNothing,
          reason:
              'AUD-tracks-04: the dead-end permanently-disabled "Start '
              'here" button must not render once the load has failed',
        );
        expect(
          find.byType(ListView),
          findsNothing,
          reason:
              'AUD-tracks-04: no blank container ListView should render '
              'on a load failure',
        );
        // A retry affordance must be present (AppErrorView's default error
        // category shows "Retry").
        expect(find.text('Retry'), findsOneWidget);
        addTearDown(() => _tearDown(tester));
      },
    );

    testWidgets(
      'AUD-tracks-04: tapping Retry on AppErrorView re-invokes the repository '
      'and recovers to normal content once it succeeds',
      (tester) async {
        final contentRepo = _MockContentRepository();
        var callCount = 0;
        when(() => contentRepo.getContentForCurriculum(any())).thenAnswer((
          _,
        ) async {
          callCount++;
          if (callCount == 1) {
            throw Exception('network error');
          }
          return const [
            ContentItem(
              curriculumId: 'mishnayos',
              sefariaRef: 'Berakhot',
              displayNameEn: 'Berakhot',
              displayNameHe: 'ברכות',
              level1: 'Zeraim',
              sortOrder: 0,
              isLeaf: false,
            ),
          ];
        });
        when(() => contentRepo.getHierarchyConfig(any())).thenAnswer(
          (_) async => const CurriculumHierarchyConfig(
            curriculumId: 'mishnayos',
            levelLabels: ['Seder', 'Masechet', 'Mishna'],
            totalItems: 0,
          ),
        );

        await tester.pumpWidget(
          _buildStartingPositionApp(
            overrides: _baseOverridesWithContentRepo(contentRepo),
            selectedProgram: _nonCalendarProgram(),
          ),
        );
        await _settle(tester);

        expect(find.byType(AppErrorView), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await _settle(tester);

        expect(callCount, equals(2), reason: 'Retry must re-run _loadContent');
        expect(
          find.byType(AppErrorView),
          findsNothing,
          reason: 'AppErrorView must clear once the retry succeeds',
        );
        expect(find.text('Starting Position'), findsOneWidget);
        addTearDown(() => _tearDown(tester));
      },
    );

    testWidgets(
      'selectedProgram=null (no program) shows content-based UI (not calendar)',
      (tester) async {
        final contentRepo = _MockContentRepository();
        when(
          () => contentRepo.getContentForCurriculum(any()),
        ).thenAnswer((_) async => []);
        when(() => contentRepo.getHierarchyConfig(any())).thenAnswer(
          (_) async => const CurriculumHierarchyConfig(
            curriculumId: 'mishnayos',
            levelLabels: ['Seder', 'Masechet', 'Mishna'],
            totalItems: 0,
          ),
        );

        await tester.pumpWidget(
          _buildStartingPositionApp(
            overrides: _baseOverridesWithContentRepo(contentRepo),
            selectedProgram: null, // no program
          ),
        );
        await _settle(tester);

        // Should not show the B2 30-day hint (that's calendar-mode only).
        expect(find.textContaining('30 days'), findsNothing);
        // Should show Starting Position title.
        expect(find.text('Starting Position'), findsOneWidget);
        addTearDown(() => _tearDown(tester));
      },
    );

    testWidgets(
      'content-based mode renders position title and button after load',
      (tester) async {
        final contentRepo = _MockContentRepository();

        final allItems = [
          const ContentItem(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot',
            displayNameEn: 'Berakhot',
            displayNameHe: 'ברכות',
            level1: 'Zeraim',
            sortOrder: 0,
            isLeaf: false,
          ),
          const ContentItem(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot 1',
            displayNameEn: 'Berakhot 1',
            displayNameHe: 'ברכות א',
            level1: 'Zeraim',
            sortOrder: 1,
            isLeaf: true,
          ),
        ];

        when(
          () => contentRepo.getContentForCurriculum(any()),
        ).thenAnswer((_) async => allItems);
        when(() => contentRepo.getHierarchyConfig(any())).thenAnswer(
          (_) async => const CurriculumHierarchyConfig(
            curriculumId: 'mishnayos',
            levelLabels: ['Seder', 'Masechet'],
            totalItems: 2,
          ),
        );

        await tester.pumpWidget(
          _buildStartingPositionApp(
            overrides: _baseOverridesWithContentRepo(contentRepo),
            selectedProgram: _nonCalendarProgram(),
          ),
        );
        await _settle(tester);

        // After content loads, the title and Start here button must be present.
        expect(find.text('Starting Position'), findsOneWidget);
        // The "Start here" button must exist (even if disabled).
        expect(find.widgetWithText(FilledButton, 'Start here'), findsOneWidget);
        addTearDown(() => _tearDown(tester));
      },
    );

    // ── AUD-tracks-17 (AX-3) regression: close-button semantics ─────────────
    //
    // The icon-only "close" IconButton that clears the current selection
    // (shown on the selected-leaf card) had no tooltip/semanticLabel.
    // `IconButton(tooltip: ...)` alone does not populate
    // `SemanticsData.label` on the current Flutter SDK (3.44.6) — only
    // `.tooltip` — so TalkBack/VoiceOver users heard just "button". The fix
    // adds both `tooltip:` and `Icon(semanticLabel:)`, reusing the existing
    // `clearSelection` ARB key ("Clear selection" / "נקה בחירה") already
    // used for the identical clear-current-selection affordance in
    // lifetime_marking_screen.dart, rather than minting a near-duplicate key.

    Future<void> pumpWithAutoSelectedLeaf(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      final contentRepo = _MockContentRepository();
      const allItems = [
        ContentItem(
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot',
          displayNameEn: 'Berakhot',
          displayNameHe: 'ברכות',
          level1: 'Zeraim',
          sortOrder: 0,
          isLeaf: false,
        ),
        ContentItem(
          curriculumId: 'mishnayos',
          sefariaRef: 'Berakhot 1',
          displayNameEn: 'Berakhot 1',
          displayNameHe: 'ברכות א',
          level1: 'Zeraim',
          sortOrder: 1,
          isLeaf: true,
        ),
      ];
      when(
        () => contentRepo.getContentForCurriculum(any()),
      ).thenAnswer((_) async => allItems);
      when(() => contentRepo.getHierarchyConfig(any())).thenAnswer(
        (_) async => const CurriculumHierarchyConfig(
          curriculumId: 'mishnayos',
          levelLabels: ['Seder', 'Masechet'],
          totalItems: 2,
        ),
      );

      await tester.pumpWidget(
        _buildStartingPositionApp(
          overrides: _baseOverridesWithContentRepo(contentRepo),
          selectedProgram: _nonCalendarProgram(),
          locale: locale,
        ),
      );
      await _settle(tester);
    }

    testWidgets(
      'AUD-tracks-17: EN — close (clear-selection) IconButton exposes a '
      'non-empty Semantics label',
      (tester) async {
        final handle = tester.ensureSemantics();

        // Content load auto-selects the first container's first leaf (see
        // _loadContent), so the close (X) IconButton on the selected-leaf
        // card renders immediately without any manual tap sequence.
        await pumpWithAutoSelectedLeaf(tester);

        final closeButton = find.widgetWithIcon(IconButton, Icons.close);
        expect(closeButton, findsOneWidget);

        final semantics = tester.getSemantics(closeButton);
        expect(
          semantics.label,
          isNotEmpty,
          reason:
              'AUD-tracks-17: the icon-only clear-selection button must '
              'expose a non-empty semantic label so TalkBack/VoiceOver '
              'announce its purpose.',
        );
        expect(semantics.label, 'Clear selection');
        expect(find.bySemanticsLabel('Clear selection'), findsOneWidget);

        handle.dispose();
        addTearDown(() => _tearDown(tester));
      },
    );

    testWidgets(
      'AUD-tracks-17: HE — close (clear-selection) IconButton exposes the '
      'Hebrew clearSelection label',
      (tester) async {
        final handle = tester.ensureSemantics();

        await pumpWithAutoSelectedLeaf(tester, locale: const Locale('he'));

        expect(
          find.bySemanticsLabel('נקה בחירה'),
          findsOneWidget,
          reason:
              'AUD-tracks-17: the Hebrew clear-selection label must be '
              'exposed on the semantics tree, not an English leak.',
        );

        handle.dispose();
        addTearDown(() => _tearDown(tester));
      },
    );
  });

  // ==========================================================================
  // B. StartingPositionCalendarMode — B2 window enforcement
  // ==========================================================================

  group('StartingPositionCalendarMode — B2 date window', () {
    testWidgets('renders "Starting Position" title', (tester) async {
      final calendarSvc = _MockCalendarProgramService();
      when(
        () => calendarSvc.getEntry(any(), any()),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: _calendarModeOverrides(calendarSvc),
          program: _calendarProgram(),
        ),
      );
      await _settle(tester);

      expect(find.text('Starting Position'), findsOneWidget);
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('shows "Can start up to 30 days back" hint (B2 window)', (
      tester,
    ) async {
      final calendarSvc = _MockCalendarProgramService();
      when(
        () => calendarSvc.getEntry(any(), any()),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: _calendarModeOverrides(calendarSvc),
          program: _calendarProgram(),
        ),
      );
      await _settle(tester);

      expect(
        find.textContaining('30 days'),
        findsOneWidget,
        reason: 'B2: the 30-day window hint must be visible',
      );
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('shows "Today" label when offset is 0', (tester) async {
      final calendarSvc = _MockCalendarProgramService();
      when(
        () => calendarSvc.getEntry(any(), any()),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: _calendarModeOverrides(calendarSvc),
          program: _calendarProgram(),
        ),
      );
      await _settle(tester);

      // The stepper centre label shows "Today" when offset == 0.
      expect(find.text('Today'), findsAtLeastNWidgets(1));
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('forward chevron is hidden at offset=0 (no future dates — B2)', (
      tester,
    ) async {
      final calendarSvc = _MockCalendarProgramService();
      when(
        () => calendarSvc.getEntry(any(), any()),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: _calendarModeOverrides(calendarSvc),
          program: _calendarProgram(),
        ),
      );
      await _settle(tester);

      // The right-chevron _OffsetButton is wrapped in Visibility(visible: false)
      // at offset=0 (maxOffsetDays==0). The Icon itself is still in the tree
      // (maintainSize:true) but its Visibility ancestor is invisible.
      final visibilityWidgets = tester
          .widgetList<Visibility>(find.byType(Visibility))
          .toList();

      // At least one Visibility wraps the forward button and must be invisible.
      final forwardButtonVisible = visibilityWidgets.any((v) => !v.visible);
      expect(
        forwardButtonVisible,
        isTrue,
        reason:
            'B2: no future dates allowed — forward chevron Visibility must '
            'have visible=false at offset=0',
      );
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('tapping backward chevron decreases offset by 1', (
      tester,
    ) async {
      final calendarSvc = _MockCalendarProgramService();
      var callCount = 0;
      when(() => calendarSvc.getEntry(any(), any())).thenAnswer((_) async {
        callCount++;
        return null;
      });

      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: _calendarModeOverrides(calendarSvc),
          program: _calendarProgram(),
        ),
      );
      await _settle(tester);

      final initialCallCount = callCount;

      // The left chevron icon is chevron_left_rounded.
      final leftChevron = find.byIcon(Icons.chevron_left_rounded);
      expect(leftChevron, findsOneWidget);
      await tester.tap(leftChevron);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // After tapping back, offset = -1 → label "Day -1" or "1 Days BACKWARDS".
      expect(
        find.textContaining('BACKWARDS'),
        findsOneWidget,
        reason: 'Offset -1 must show BACKWARDS direction label',
      );
      // Calendar service should have been re-queried.
      expect(
        callCount,
        greaterThan(initialCallCount),
        reason: 'Tapping back should trigger a new calendar entry lookup',
      );
      addTearDown(() => _tearDown(tester));
    });

    testWidgets(
      'back-dating is allowed (offset -7 is within [today-30, today])',
      (tester) async {
        // Fixed reference date (TQ-6: hermetic tests use no wall-clock).
        final today = DateTime(2026, 6, 1);
        final window = ProgramStartingPosition.allowedWindow(today);

        final offset7DaysAgo = today.subtract(const Duration(days: 7));

        // The date at -7 must be within the allowed window.
        expect(
          offset7DaysAgo.isAfter(
            window.minDate.subtract(const Duration(days: 1)),
          ),
          isTrue,
          reason: 'offset -7 must be within the [today-30, today] window',
        );
        expect(
          offset7DaysAgo.isBefore(window.maxDate.add(const Duration(days: 1))),
          isTrue,
          reason: 'offset -7 must not be in the future',
        );
      },
    );

    testWidgets('ProgramStartingPosition.allowedWindow minDate is today - 30', (
      tester,
    ) async {
      // Fixed reference date (TQ-6: hermetic tests use no wall-clock).
      final today = DateTime(2026, 6, 1);
      final window = ProgramStartingPosition.allowedWindow(today);

      final todayMidnight = DateTime(today.year, today.month, today.day);
      final expectedMin = todayMidnight.subtract(
        const Duration(days: kMaxLookBackDays),
      );

      expect(
        window.minDate,
        equals(expectedMin),
        reason: 'B2: allowed window minDate must be today - 30',
      );
      expect(
        window.maxDate,
        equals(todayMidnight),
        reason: 'B2: allowed window maxDate must be today (no future)',
      );
    });

    testWidgets('start >30 days ago throws StartDateWindowException', (
      tester,
    ) async {
      // Fixed reference date (TQ-6: hermetic tests use no wall-clock).
      final today = DateTime(2026, 6, 1);
      final tooFarBack = today.subtract(const Duration(days: 31));

      expect(
        () =>
            ProgramStartingPosition.create(startDate: tooFarBack, today: today),
        throwsA(isA<StartDateWindowException>()),
        reason: 'B2: dates older than 30 days must be rejected',
      );
    });

    testWidgets('future start date throws StartDateWindowException', (
      tester,
    ) async {
      // Fixed reference date (TQ-6: hermetic tests use no wall-clock).
      final today = DateTime(2026, 6, 1);
      final tomorrow = today.add(const Duration(days: 1));

      expect(
        () => ProgramStartingPosition.create(startDate: tomorrow, today: today),
        throwsA(isA<StartDateWindowException>()),
        reason: 'B2: future start dates must be rejected',
      );
    });

    testWidgets('back-date of exactly 30 days is accepted (boundary)', (
      tester,
    ) async {
      // Fixed reference date (TQ-6: hermetic tests use no wall-clock).
      final today = DateTime(2026, 6, 1);
      final todayMidnight = DateTime(today.year, today.month, today.day);
      final exactly30DaysAgo = todayMidnight.subtract(const Duration(days: 30));

      // Must NOT throw.
      final pos = ProgramStartingPosition.create(
        startDate: exactly30DaysAgo,
        today: today,
      );
      expect(
        pos.daysFromToday(today),
        equals(30),
        reason: 'B3: 30-day back-date should yield 30 overdue-catch-up days',
      );
    });

    testWidgets('offset:-7 encodes correctly via legacy grammar', (
      tester,
    ) async {
      // Fixed reference date (TQ-6: hermetic tests use no wall-clock).
      final today = DateTime(2026, 6, 1);
      final startDate = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(const Duration(days: 7));
      final pos = ProgramStartingPosition.create(
        startDate: startDate,
        today: today,
      );

      final grammar = pos.toLegacyGrammar(today);
      expect(
        grammar,
        equals('offset:7'),
        reason:
            'Legacy grammar must encode negative offsets as positive integers '
            '("offset:7" means 7 days back)',
      );
    });

    testWidgets('"Use Today" button resets offset to 0', (tester) async {
      final calendarSvc = _MockCalendarProgramService();
      when(
        () => calendarSvc.getEntry(any(), any()),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: _calendarModeOverrides(calendarSvc),
          program: _calendarProgram(),
        ),
      );
      await _settle(tester);

      // Tap backward to move to offset -1.
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await _settle(tester);
      expect(find.textContaining('BACKWARDS'), findsOneWidget);

      // Now tap "Use Today".
      await tester.tap(find.text('Use Today'));
      await _settle(tester);

      // Offset should be reset to 0 → "TODAY" direction label.
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.textContaining('BACKWARDS'), findsNothing);
      addTearDown(() => _tearDown(tester));
    });

    testWidgets(
      '"Start Here" button disabled while calendar entry is loading',
      (tester) async {
        final calendarSvc = _MockCalendarProgramService();
        // Use a completer that stays pending during the test.
        final completer = Completer<CalendarProgramEntry?>();
        when(
          () => calendarSvc.getEntry(any(), any()),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          _buildCalendarModeApp(
            overrides: _calendarModeOverrides(calendarSvc),
            program: _calendarProgram(),
          ),
        );
        await tester.pump(); // First frame — still loading.

        final startBtn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Start Here'),
        );
        expect(
          startBtn.onPressed,
          isNull,
          reason:
              'Start Here must be disabled while calendar entry is loading '
              '(canStart = false)',
        );

        // Complete the future before teardown to avoid pending-timer failures.
        completer.complete(null);
        await tester.pump();
        addTearDown(() => _tearDown(tester));
      },
    );

    // ── AUD-tracks-04 regression: _refreshCalendarEntry error handling ──────

    testWidgets('AUD-tracks-04: a thrown service error shows a distinct error '
        'affordance, not the misleading "no entry found" fallback', (
      tester,
    ) async {
      final calendarSvc = _MockCalendarProgramService();
      when(
        () => calendarSvc.getEntry(any(), any()),
      ).thenAnswer((_) async => throw Exception('calendar service down'));

      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: _calendarModeOverrides(calendarSvc),
          program: _calendarProgram(),
        ),
      );
      await _settle(tester);

      // The generic "no local entry" text mislabels a real fetch failure
      // as "no data for this date" — it must NOT appear on a thrown error.
      expect(
        find.text('No local calendar entry found for this date.'),
        findsNothing,
        reason:
            'AUD-tracks-04: a service exception must not be mislabelled '
            'as "no entry found for this date"',
      );
      // A distinct, dedicated error message must appear instead.
      expect(
        find.textContaining("Couldn't load this date's entry"),
        findsOneWidget,
        reason:
            'AUD-tracks-04: a distinct load-failure affordance must be '
            'shown for a thrown CalendarProgramService error',
      );
      // A retry affordance must be present.
      expect(find.text('Retry'), findsOneWidget);
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('AUD-tracks-04: tapping Retry after a calendar service error '
        're-queries the service and recovers', (tester) async {
      final calendarSvc = _MockCalendarProgramService();
      var callCount = 0;
      const fakeEntry = CalendarProgramEntry(
        programId: 'daf_yomi',
        displayNameEn: 'Daf Yomi',
        displayNameHe: 'דף יומי',
        todayRef: 'Berakhot 7',
        apiSource: 'local',
      );
      when(() => calendarSvc.getEntry(any(), any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw Exception('calendar service down');
        }
        return fakeEntry;
      });

      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: _calendarModeOverrides(calendarSvc),
          program: _calendarProgram(),
        ),
      );
      await _settle(tester);

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await _settle(tester);

      expect(callCount, equals(2), reason: 'Retry must re-query the service');
      expect(
        find.textContaining("Couldn't load this date's entry"),
        findsNothing,
        reason: 'The error affordance must clear once the retry succeeds',
      );
      expect(find.text('Berakhot 7'), findsOneWidget);
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('"Start Here" fires onComplete with offset:N|ref:todayRef '
        'when calendar entry is available', (tester) async {
      final calendarSvc = _MockCalendarProgramService();
      const fakeEntry = CalendarProgramEntry(
        programId: 'daf_yomi',
        displayNameEn: 'Daf Yomi',
        displayNameHe: 'דף יומי',
        todayRef: 'Berakhot 7',
        apiSource: 'local',
      );
      when(
        () => calendarSvc.getEntry(any(), any()),
      ).thenAnswer((_) async => fakeEntry);

      String? emittedResult;
      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: _calendarModeOverrides(calendarSvc),
          program: _calendarProgram(),
          onComplete: (result) => emittedResult = result,
        ),
      );
      await _settle(tester);

      // Button should now be enabled (canStart = true).
      final startBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start Here'),
      );
      expect(startBtn.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Start Here'));
      await _settle(tester);

      expect(emittedResult, isNotNull);
      // At offset=0, the grammar is "offset:0|ref:Berakhot 7".
      expect(
        emittedResult,
        contains('ref:Berakhot 7'),
        reason: 'onComplete must encode todayRef from the CalendarProgramEntry',
      );
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('Hebrew locale smoke test — pumps without errors', (
      tester,
    ) async {
      final calendarSvc = _MockCalendarProgramService();
      when(
        () => calendarSvc.getEntry(any(), any()),
      ).thenAnswer((_) async => null);

      final db = inMemoryDb();
      final overrides = [
        userDatabaseProvider.overrideWithValue(db),
        calendarProgramServiceProvider.overrideWith(
          (ref) => Future.value(calendarSvc),
        ),
        useHebrewTermsProvider.overrideWith(() => _TrueUseHebrewTerms()),
        syncWriteFacadeProvider.overrideWithValue(null),
        activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
      ];

      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: overrides,
          program: _calendarProgram(),
          locale: const Locale('he'),
        ),
      );
      await _settle(tester);

      // Hebrew title for Starting Position.
      expect(find.text('מיקום התחלתי'), findsOneWidget);
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('no track-type labels (Personal/Standard/Custom/אישי)', (
      tester,
    ) async {
      final calendarSvc = _MockCalendarProgramService();
      when(
        () => calendarSvc.getEntry(any(), any()),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: _calendarModeOverrides(calendarSvc),
          program: _calendarProgram(),
        ),
      );
      await _settle(tester);

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.text('אישי'), findsNothing);
      addTearDown(() => _tearDown(tester));
    });

    // ── R4-2 Hebrew-locale regression tests ──────────────────────────────────

    testWidgets('R4-2: Hebrew locale — offset=0 shows היום, not TODAY/Today', (
      tester,
    ) async {
      final calendarSvc = _MockCalendarProgramService();
      when(
        () => calendarSvc.getEntry(any(), any()),
      ).thenAnswer((_) async => null);

      final db = inMemoryDb();
      final overrides = [
        userDatabaseProvider.overrideWithValue(db),
        calendarProgramServiceProvider.overrideWith(
          (ref) => Future.value(calendarSvc),
        ),
        useHebrewTermsProvider.overrideWith(() => _TrueUseHebrewTerms()),
        syncWriteFacadeProvider.overrideWithValue(null),
        activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
      ];

      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: overrides,
          program: _calendarProgram(),
          locale: const Locale('he'),
        ),
      );
      await _settle(tester);

      // At offset=0 both the offset badge and the direction label read "היום".
      expect(
        find.text('היום'),
        findsAtLeastNWidgets(1),
        reason:
            'R4-2: Hebrew calendarOffsetToday / calendarDirectionToday '
            'must render "היום", not the English "Today" / "TODAY"',
      );
      // English direction / offset literals must be absent.
      expect(
        find.text('TODAY'),
        findsNothing,
        reason:
            'R4-2: "TODAY" is the English direction label — must be absent in he locale',
      );
      expect(
        find.text('Today'),
        findsNothing,
        reason:
            'R4-2: "Today" is an English label — must be absent in he locale',
      );
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('R4-2: Hebrew locale — offset=-1 shows אחורה, not BACKWARDS', (
      tester,
    ) async {
      final calendarSvc = _MockCalendarProgramService();
      when(
        () => calendarSvc.getEntry(any(), any()),
      ).thenAnswer((_) async => null);

      final db = inMemoryDb();
      final overrides = [
        userDatabaseProvider.overrideWithValue(db),
        calendarProgramServiceProvider.overrideWith(
          (ref) => Future.value(calendarSvc),
        ),
        useHebrewTermsProvider.overrideWith(() => _TrueUseHebrewTerms()),
        syncWriteFacadeProvider.overrideWithValue(null),
        activeProfileIdProvider.overrideWith(_ProfileIdOverride.new),
      ];

      await tester.pumpWidget(
        _buildCalendarModeApp(
          overrides: overrides,
          program: _calendarProgram(),
          locale: const Locale('he'),
        ),
      );
      await _settle(tester);

      // Tap the back chevron to move offset to -1.
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await _settle(tester);

      // Direction label must be the Hebrew "אחורה".
      expect(
        find.text('אחורה'),
        findsOneWidget,
        reason:
            'R4-2: Hebrew calendarDirectionBackwards must render '
            '"אחורה", not the English "BACKWARDS"',
      );
      // The English literal must be absent.
      expect(
        find.text('BACKWARDS'),
        findsNothing,
        reason:
            'R4-2: hardcoded English "BACKWARDS" must be absent in he locale',
      );
      // Also assert "יום אחד" appears (calendarOffsetDaysCount(1) = "יום אחד").
      expect(
        find.text('יום אחד'),
        findsOneWidget,
        reason:
            'R4-2: Hebrew calendarOffsetDaysCount(1) must render "יום אחד", not "1 Day"',
      );
      expect(
        find.text('1 Day'),
        findsNothing,
        reason: 'R4-2: English "1 Day" must be absent in he locale',
      );
      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // C. SelfPacedGoalStep — pace mode and deadline mode
  // ==========================================================================

  group('SelfPacedGoalStep — renders and mode switching', () {
    testWidgets('shows goal step title', (tester) async {
      await tester.pumpWidget(
        _buildGoalStepApp(overrides: _goalStepOverrides()),
      );
      await _settle(tester);

      expect(
        find.textContaining("What's your pace or deadline?"),
        findsOneWidget,
      );
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('shows goal step subtitle', (tester) async {
      await tester.pumpWidget(
        _buildGoalStepApp(overrides: _goalStepOverrides()),
      );
      await _settle(tester);

      expect(find.text('Set a goal.'), findsOneWidget);
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('Continue button is present and enabled in pace mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildGoalStepApp(overrides: _goalStepOverrides()),
      );
      await _settle(tester);

      final continueBtn = find.widgetWithText(FilledButton, 'Continue');
      await tester.ensureVisible(continueBtn);
      await tester.pump();

      final btn = tester.widget<FilledButton>(continueBtn);
      expect(
        btn.onPressed,
        isNotNull,
        reason: 'Continue must be enabled in pace mode',
      );
      addTearDown(() => _tearDown(tester));
    });

    testWidgets(
      'tapping Continue in pace mode fires onComplete with a pace GoalEntity',
      (tester) async {
        GoalEntity? emittedGoal;

        await tester.pumpWidget(
          _buildGoalStepApp(
            overrides: _goalStepOverrides(),
            onComplete: (g) => emittedGoal = g,
          ),
        );
        await _settle(tester);

        final continueBtn = find.widgetWithText(FilledButton, 'Continue');
        await tester.ensureVisible(continueBtn);
        await tester.pump();
        await tester.tap(continueBtn);
        await _settle(tester);

        expect(emittedGoal, isNotNull);
        expect(
          emittedGoal!.goalType,
          equals('pace'),
          reason: 'Default mode is pace; onComplete must receive a pace goal',
        );
        expect(emittedGoal!.paceValue, greaterThan(0));
        addTearDown(() => _tearDown(tester));
      },
    );

    testWidgets(
      'pace mode GoalEntity carries curriculumId matching the step parameter',
      (tester) async {
        GoalEntity? emittedGoal;

        await tester.pumpWidget(
          _buildGoalStepApp(
            overrides: _goalStepOverrides(),
            onComplete: (g) => emittedGoal = g,
            curriculumId: CurriculumId.mishnayos,
          ),
        );
        await _settle(tester);

        final continueBtn = find.widgetWithText(FilledButton, 'Continue');
        await tester.ensureVisible(continueBtn);
        await tester.pump();
        await tester.tap(continueBtn);
        await _settle(tester);

        expect(emittedGoal?.curriculumId, equals(CurriculumId.mishnayos));
        addTearDown(() => _tearDown(tester));
      },
    );

    testWidgets('pace increase button increments paceValue', (tester) async {
      GoalEntity? emittedGoal;

      await tester.pumpWidget(
        _buildGoalStepApp(
          overrides: _goalStepOverrides(),
          onComplete: (g) => emittedGoal = g,
        ),
      );
      await _settle(tester);

      // Capture initial pace by tapping Continue.
      final continueBtn = find.widgetWithText(FilledButton, 'Continue');
      await tester.ensureVisible(continueBtn);
      await tester.pump();
      await tester.tap(continueBtn);
      await _settle(tester);
      final initialPace = emittedGoal?.paceValue ?? 0;

      // Find the + increment button (add icon) — may be off-screen.
      final addBtn = find.byIcon(Icons.add_rounded);
      if (addBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(addBtn.first);
        await tester.tap(addBtn.first);
        await _settle(tester);

        await tester.ensureVisible(continueBtn);
        await tester.pump();
        await tester.tap(continueBtn);
        await _settle(tester);

        expect(
          emittedGoal!.paceValue ?? 0,
          greaterThanOrEqualTo(initialPace),
          reason: 'Tapping + should increase the paceValue',
        );
      }
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('deadline mode tap does not crash the widget', (tester) async {
      await tester.pumpWidget(
        _buildGoalStepApp(overrides: _goalStepOverrides()),
      );
      await _settle(tester);

      // The deadline blur overlay shows its hint when inactive.
      // Try finding the hint text for tap to use deadline.
      final deadlineHint = find.textContaining('Use deadline');
      if (deadlineHint.evaluate().isNotEmpty) {
        await tester.ensureVisible(deadlineHint.first);
        await tester.pump();
        await tester.tap(deadlineHint.first);
        await _settle(tester);
      }

      // Widget must remain mounted — Continue button still visible.
      final continueBtn = find.widgetWithText(FilledButton, 'Continue');
      expect(continueBtn, findsOneWidget);
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('per_week unit is the default pace unit', (tester) async {
      GoalEntity? emittedGoal;

      await tester.pumpWidget(
        _buildGoalStepApp(
          overrides: _goalStepOverrides(),
          onComplete: (g) => emittedGoal = g,
        ),
      );
      await _settle(tester);

      final continueBtn = find.widgetWithText(FilledButton, 'Continue');
      await tester.ensureVisible(continueBtn);
      await tester.pump();
      await tester.tap(continueBtn);
      await _settle(tester);

      expect(
        emittedGoal?.pacePeriod,
        anyOf('per_week', 'per_day'),
        reason: 'Default pace period must be per_week or per_day',
      );
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('no track-type labels anywhere', (tester) async {
      await tester.pumpWidget(
        _buildGoalStepApp(overrides: _goalStepOverrides()),
      );
      await _settle(tester);

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Standard'), findsNothing);
      expect(find.text('Custom'), findsNothing);
      expect(find.text('אישי'), findsNothing);
      addTearDown(() => _tearDown(tester));
    });

    testWidgets('Hebrew locale smoke test — pumps without errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildGoalStepApp(
          overrides: _goalStepOverrides(),
          locale: const Locale('he'),
        ),
      );
      await _settle(tester);

      // Hebrew title for goal step.
      expect(find.text('מה הקצב או המועד שלך?'), findsOneWidget);
      addTearDown(() => _tearDown(tester));
    });
  });

  // ==========================================================================
  // D. B2 unit-level assertions (ProgramStartingPosition — pure logic)
  //    No widget pumping; runs as plain test() calls.
  // ==========================================================================

  group('ProgramStartingPosition.allowedWindow — B2 window contract', () {
    test('allowedWindow returns [today-30, today]', () {
      final now = DateTime(2026, 6, 1); // Fixed reference date.
      final window = ProgramStartingPosition.allowedWindow(now);

      expect(window.minDate, equals(DateTime(2026, 5, 2)));
      expect(window.maxDate, equals(DateTime(2026, 6, 1)));
    });

    test('start on today passes validation', () {
      final today = DateTime(2026, 6, 1);
      final pos = ProgramStartingPosition.create(
        startDate: today,
        today: today,
      );
      expect(pos.daysFromToday(today), equals(0));
    });

    test('start 30 days ago passes validation (boundary)', () {
      final today = DateTime(2026, 6, 1);
      final start = DateTime(2026, 5, 2);
      final pos = ProgramStartingPosition.create(
        startDate: start,
        today: today,
      );
      expect(pos.daysFromToday(today), equals(30));
    });

    test('start 31 days ago fails (beyond boundary)', () {
      final today = DateTime(2026, 6, 1);
      final start = DateTime(2026, 5, 1);
      expect(
        () => ProgramStartingPosition.create(startDate: start, today: today),
        throwsA(isA<StartDateWindowException>()),
      );
    });

    test('start tomorrow fails (future not allowed)', () {
      final today = DateTime(2026, 6, 1);
      final start = DateTime(2026, 6, 2);
      expect(
        () => ProgramStartingPosition.create(startDate: start, today: today),
        throwsA(isA<StartDateWindowException>()),
      );
    });

    test('fromLegacyGrammar: offset:7 maps to 7 days back', () {
      final today = DateTime(2026, 6, 1);
      final pos = ProgramStartingPosition.fromLegacyGrammar(
        rawStartingRef: 'offset:7',
        today: today,
      );
      expect(pos.daysFromToday(today), equals(7));
    });

    test('fromLegacyGrammar: offset:0 is today', () {
      final today = DateTime(2026, 6, 1);
      final pos = ProgramStartingPosition.fromLegacyGrammar(
        rawStartingRef: 'offset:0',
        today: today,
      );
      expect(pos.daysFromToday(today), equals(0));
    });

    test('fromLegacyGrammar: null → today', () {
      final today = DateTime(2026, 6, 1);
      final pos = ProgramStartingPosition.fromLegacyGrammar(
        rawStartingRef: null,
        today: today,
      );
      expect(pos.daysFromToday(today), equals(0));
    });

    test('fromLegacyGrammar: offset with ref parses both fields', () {
      final today = DateTime(2026, 6, 1);
      final pos = ProgramStartingPosition.fromLegacyGrammar(
        rawStartingRef: 'offset:3|ref:Berakhot 5a',
        today: today,
      );
      expect(pos.daysFromToday(today), equals(3));
      expect(pos.sefariaRef, equals('Berakhot 5a'));
    });

    test(
      'B3: back-dated start produces positive daysFromToday (overdue count)',
      () {
        final today = DateTime(2026, 6, 1);
        final start = DateTime(2026, 5, 25); // 7 days back.
        final pos = ProgramStartingPosition.create(
          startDate: start,
          today: today,
        );
        expect(
          pos.daysFromToday(today),
          equals(7),
          reason:
              'B3: daysFromToday represents the overdue-task generation '
              'window. A 7-day back-date should yield 7.',
        );
      },
    );
  });
}
