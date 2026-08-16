// Dark-mode legibility sweep — content-and-learning burndown (OWNER DECISION
// #2). One shared file covering the three real dark-mode bugs found while
// auditing lib/features/content_browsing/presentation/ and
// lib/features/learning/presentation/, modelled on
// darkmode_sweep_contrast_test.dart's WCAG-helper + real-widget-pump style.
//
// Finding 1 (P1) — LearningScreen's "Daily Tasks" section header
// (`learning_screen.dart`'s `_DailyTasksSection`): the "View all" TextButton
// read a hardcoded `Color(0xFF354993)` foreground, sitting directly on the
// app canvas (`context.colors.surfaceF4`, which darkens in dark mode) — not
// a card. Measured (WCAG math from the resolved hexes): **1.85:1** in dark
// mode against a 4.5:1 AA floor (dark-navy link text stranded on a
// near-equally-dark canvas). Fixed with a new token,
// `AppPalette.brandBlueLinkInk`, which keeps the exact old hex in light mode
// and lightens to sky-blue in dark (6.10:1).
//
// Finding 2 (P1) — LearningScreen's overdue task card
// (`learning_screen.dart`'s `_LearnTaskCard`): the "OVERDUE" pill-badge text
// read a hardcoded `Color(0xFFC22840)`, paired with
// `context.colors.statusErrorSoft` (which darkens to a deep maroon in dark
// mode). Measured: **2.94:1** in dark against a 4.5:1 AA floor (mid-red text
// sinking into dark maroon). Fixed with a new token,
// `AppPalette.overdueBadgeInk`, exact old hex in light, `statusError`'s dark
// tone in dark (6.30:1).
//
// Finding 3 (P1) — TextDisplayScreen's "could not save" SnackBar
// (`text_display_screen.dart`'s `_CompletionSectionState._handleComplete`
// catch branch): `backgroundColor` was `context.colors.brandWarningDeep` — an
// INK role that deliberately LIGHTENS in dark mode for text-on-tint use —
// used as a FILL instead. The app's default `snackBarTheme.contentTextStyle`
// (near-white in both themes) then sat on a pale-cream fill in dark mode.
// Measured: **1.36:1** in dark against a 4.5:1 AA floor — the same
// hero-fill-vs-ink role mismatch as `goldOnColouredSurface`
// (split from `goldTrophy`), just with the ink/fill roles reversed. Fixed
// with a new token, `AppPalette.warningSnackbarFill`, pinned to the exact
// pre-fix light-mode hex in BOTH themes (5.43:1 in dark, 6.32:1 unchanged in
// light) — same "stays deep in both modes" pattern as the hero-fill tokens
// (`blueMedium`/`blueLight`/`blueMid`, `chazaraSelectedGradientStart/End`).
@Tags(['core_widgets', 'content_browsing', 'learning'])
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/content_browsing/domain/entities/text_content.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/screens/text_display_screen.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/mark_completion_use_case.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/learning/presentation/screens/learning_screen.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

/// WCAG relative luminance (sRGB), per w3.org/TR/WCAG21/#dfn-relative-luminance.
double _relativeLuminance(Color c) {
  double channel(double v) {
    final s = v / 255.0;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel((c.r * 255).roundToDouble()) +
      0.7152 * channel((c.g * 255).roundToDouble()) +
      0.0722 * channel((c.b * 255).roundToDouble());
}

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

// ─── LearningScreen harness (Findings 1 & 2) ─────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _FakeNoTutorSession extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

LearnerProfileEntity _adultProfile() {
  final now = DateTime.utc(2026, 1, 1);
  return LearnerProfileEntity(
    profileId: 'darkmode-profile-ulid',
    displayName: 'Dad',
    mode: ProfileMode.adult,
    avatar: '',
    createdAt: now,
    updatedAt: now,
  );
}

DailyTask _learnTask({
  DailyTaskPriority priority = DailyTaskPriority.newLearning,
  bool isOverdue = false,
}) => DailyTask(
  curriculumId: CurriculumId.mishnayos,
  contentItemSefariaRef: 'Mishnah_Berakhot_1.1',
  stageOrder: 1,
  priority: priority,
  isOverdue: isOverdue,
  reason: 'test',
  stageName: 'Learn',
  trackLabel: 'Test Track',
  estimatedEffortMinutes: 5,
);

/// Pumps [LearningScreen] with one populated daily task (matching
/// [learning_screen_l1_test.dart]'s `_buildScreen` shape), so both
/// `_DailyTasksSection`'s "View all" header and `_LearnTaskCard`'s badges
/// render.
Widget _pumpLearningScreen({required ThemeData theme, required bool overdue}) {
  final overrides = <Override>[
    useHebrewTermsProvider.overrideWith(_HebrewTermsOff.new),
    currentTransliterationVariantProvider.overrideWithValue(
      TransliterationVariant.ashkenazi,
    ),
    dashboardActiveCurriculaStreamProvider.overrideWith(
      (ref) => Stream.value(const [CurriculumId.mishnayos]),
    ),
    dashboardStreakProvider.overrideWith(
      (ref) => Stream.value((currentStreak: 3, maxStreak: 5)),
    ),
    allDailyTasksProvider.overrideWith(
      (ref) => Future.value([_learnTask(isOverdue: overdue)]),
    ),
    selectedProfileProvider.overrideWith(
      (ref) => Future.value(_adultProfile()),
    ),
    activeTutoredProfileSelectionProvider.overrideWith(_FakeNoTutorSession.new),
    coarsePacedTrackIdsProvider.overrideWith(
      (ref) => Future.value(const <CurriculumId>{}),
    ),
    contentIndexProvider.overrideWith(
      (ref) => Future.value(ContentIndex.fromCurricula(const {})),
    ),
  ];

  return pumpApp(
    theme: theme,
    overrides: overrides,
    child: const Scaffold(body: LearningScreen()),
  );
}

// ─── TextDisplayScreen harness (Finding 3) ───────────────────────────────────

const _kRef = 'Mishnah Berakhot 1:1';

DailyTask _readerTask() => const DailyTask(
  curriculumId: CurriculumId.mishnayos,
  contentItemSefariaRef: _kRef,
  stageOrder: 1,
  priority: DailyTaskPriority.newLearning,
  isOverdue: false,
  reason: 'test',
  stageName: 'Learn',
  trackLabel: 'Test Track',
  estimatedEffortMinutes: 5,
);

TextContent _readerContent() => TextContent.single(
  sefariaRef: _kRef,
  hebrewText: 'מֵאֵימָתַי קוֹרִין',
  englishText: 'From when may one recite',
);

/// Orchestrator whose `markComplete` always throws — drives
/// `_CompletionSectionState._handleComplete`'s `catch (Exception e, st)`
/// branch (the real production path that shows the "could not save"
/// SnackBar) without needing a real completion write to succeed. Mocks
/// `CompletionOrchestrator` (not `CompletionRepository`) because
/// `MarkCompletionUseCase` goes through the orchestrator now — see
/// `docs/firestore-rewrite-map.md`, owner decision 1.
class _ThrowingCompletionOrchestrator extends Mock
    implements CompletionOrchestrator {}

class _FakeFontSizeNotifier extends FontSizeNotifier {
  @override
  // ignore: prefer_const_declarations
  FontSize build() => FontSize.medium;
}

class _FakeShowNikudNotifier extends ShowNikud {
  @override
  bool build() => true;
}

class _FakeCompletionCommitted extends CompletionCommitted {
  @override
  int build() => 0;
}

class _FakeTransliterationVariant extends CurrentTransliterationVariant {
  @override
  TransliterationVariant build() => TransliterationVariant.ashkenazi;
}

class _FakeActiveTutoredProfileSelection extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

ContentIndex _readerContentIndex() {
  const item = ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Fake Chapter',
    level4: 'Item 0',
    displayNameHe: _kRef,
    displayNameEn: _kRef,
    sefariaRef: _kRef,
    sortOrder: 0,
    isLeaf: true,
  );
  return ContentIndex.fromCurricula({
    CurriculumId.mishnayos: [item],
  });
}

/// Pumps the real [TextDisplayScreen], wired so tapping "Mark complete"
/// drives the real `_handleComplete` catch branch and shows the real
/// "could not save" SnackBar.
Widget _pumpTextDisplayScreen({
  required ThemeData theme,
  required StackRouter router,
}) {
  final orchestrator = _ThrowingCompletionOrchestrator();
  when(
    () => orchestrator.markComplete(
      any(),
      awardGamificationPoints: any(named: 'awardGamificationPoints'),
      creditsAchievement: any(named: 'creditsAchievement'),
    ),
  ).thenThrow(Exception('simulated write failure'));

  final overrides = <Override>[
    textContentProvider(
      _kRef,
    ).overrideWith((ref) => Future.value(_readerContent())),
    fontSizeProvider.overrideWith(_FakeFontSizeNotifier.new),
    showNikudProvider.overrideWith(_FakeShowNikudNotifier.new),
    renderedDisplayForRefProvider(_kRef).overrideWith((ref) async => _kRef),
    contentIndexProvider.overrideWith((ref) async => _readerContentIndex()),
    currentTransliterationVariantProvider.overrideWith(
      _FakeTransliterationVariant.new,
    ),
    allDailyTasksProvider.overrideWith((ref) => Future.value([_readerTask()])),
    trackStorageKeyForTrackIdProvider.overrideWith(
      (ref, trackId) async => 'personal',
    ),
    isStageCompletedProvider.overrideWith((ref, params) async => false),
    completionCommittedProvider.overrideWith(_FakeCompletionCommitted.new),
    dashboardUserModeProvider.overrideWith((ref) async => ProfileMode.adult),
    activeTutoredProfileSelectionProvider.overrideWith(
      _FakeActiveTutoredProfileSelection.new,
    ),
    useHebrewTermsProvider.overrideWith(_HebrewTermsOff.new),
    markCompletionUseCaseProvider.overrideWithValue(
      MarkCompletionUseCase(orchestrator),
    ),
  ];

  return pumpApp(
    theme: theme,
    overrides: overrides,
    child: StackRouterScope(
      controller: router,
      stateHash: 0,
      child: const MediaQuery(
        data: MediaQueryData(size: Size(800, 1200)),
        child: TextDisplayScreen(sefariaRef: _kRef),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(_FakePageRouteInfo());
    registerFallbackValue(
      const CompletionRequest(
        curriculumId: 'mishnayos',
        sefariaRef: _kRef,
        stageId: 1,
        trackType: 'personal',
      ),
    );
  });

  group(
    'Finding 1 — LearningScreen "View all" link ink (_DailyTasksSection)',
    () {
      test('brandBlueLinkInk clears WCAG 4.5:1 on surfaceF4 in dark mode '
          '(measured 1.85:1 on the pre-fix Color(0xFF354993) literal)', () {
        const palette = AppPalette.dark;
        final oldLiteralRatio = _contrast(
          const Color(0xFF354993),
          palette.surfaceF4,
        );
        final fixedRatio = _contrast(
          palette.brandBlueLinkInk,
          palette.surfaceF4,
        );

        expect(
          oldLiteralRatio,
          lessThan(4.5),
          reason:
              'demonstrates the pre-fix bug: the raw literal never '
              'adapted, so it fails against the darkened canvas',
        );
        expect(
          fixedRatio,
          greaterThanOrEqualTo(4.5),
          reason:
              'the "View all" link sits directly on surfaceF4 (the app '
              'canvas), which darkens in dark mode; the old literal '
              '0xFF354993 never adapted',
        );
      });

      test('light mode is unchanged — brandBlueLinkInk equals the exact old '
          'Color(0xFF354993) literal', () {
        const light = AppPalette.light;

        expect(light.brandBlueLinkInk, const Color(0xFF354993));
        expect(
          _contrast(light.brandBlueLinkInk, light.surfaceF4),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets(
        'the real "View all" TextButton reads brandBlueLinkInk (not the old '
        'literal) in dark mode',
        (tester) async {
          await tester.pumpWidget(
            _pumpLearningScreen(theme: AppTheme.darkTheme(), overdue: false),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          final button = tester.widget<TextButton>(find.byType(TextButton));
          final resolved = button.style?.foregroundColor?.resolve(
            <WidgetState>{},
          );

          expect(resolved, AppPalette.dark.brandBlueLinkInk);
          expect(resolved, isNot(const Color(0xFF354993)));

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(Duration.zero);
        },
      );

      testWidgets(
        'the real "View all" TextButton keeps the exact old literal in '
        'light mode (no regression)',
        (tester) async {
          await tester.pumpWidget(
            _pumpLearningScreen(theme: AppTheme.lightTheme(), overdue: false),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          final button = tester.widget<TextButton>(find.byType(TextButton));
          final resolved = button.style?.foregroundColor?.resolve(
            <WidgetState>{},
          );

          expect(resolved, const Color(0xFF354993));

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(Duration.zero);
        },
      );
    },
  );

  group('Finding 2 — LearningScreen overdue badge ink (_LearnTaskCard)', () {
    test('overdueBadgeInk clears WCAG 4.5:1 on statusErrorSoft in dark mode '
        '(measured 2.94:1 on the pre-fix Color(0xFFC22840) literal)', () {
      const palette = AppPalette.dark;
      final oldLiteralRatio = _contrast(
        const Color(0xFFC22840),
        palette.statusErrorSoft,
      );
      final fixedRatio = _contrast(
        palette.overdueBadgeInk,
        palette.statusErrorSoft,
      );

      expect(
        oldLiteralRatio,
        lessThan(4.5),
        reason:
            'demonstrates the pre-fix bug against the deep-maroon dark badge',
      );
      expect(
        fixedRatio,
        greaterThanOrEqualTo(4.5),
        reason:
            'the "OVERDUE" badge text sits on statusErrorSoft, which '
            'darkens to a deep maroon in dark mode; the old literal '
            '0xFFC22840 never adapted',
      );
    });

    test('light mode is unchanged — overdueBadgeInk equals the exact old '
        'Color(0xFFC22840) literal', () {
      const light = AppPalette.light;

      expect(light.overdueBadgeInk, const Color(0xFFC22840));
      expect(
        _contrast(light.overdueBadgeInk, light.statusErrorSoft),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'the real "OVERDUE" badge reads overdueBadgeInk (not the old literal) '
      'in dark mode',
      (tester) async {
        await tester.pumpWidget(
          _pumpLearningScreen(theme: AppTheme.darkTheme(), overdue: true),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final text = tester.widget<Text>(find.text('OVERDUE'));

        expect(text.style?.color, AppPalette.dark.overdueBadgeInk);
        expect(text.style?.color, isNot(const Color(0xFFC22840)));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'the real "OVERDUE" badge keeps the exact old literal in light mode '
      '(no regression)',
      (tester) async {
        await tester.pumpWidget(
          _pumpLearningScreen(theme: AppTheme.lightTheme(), overdue: true),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final text = tester.widget<Text>(find.text('OVERDUE'));

        expect(text.style?.color, const Color(0xFFC22840));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  group('Finding 3 — TextDisplayScreen "could not save" SnackBar fill '
      '(_CompletionSectionState)', () {
    test('warningSnackbarFill stays legible for the default (near-white) '
        'SnackBar content text in dark mode (measured 1.36:1 with the '
        'pre-fix brandWarningDeep-as-fill bug)', () {
      const palette = AppPalette.dark;
      // The theme's default SnackBar content text colour in dark mode
      // (app_theme.dart: `contentTextStyle: color: isDark ? c.brandInk : …`).
      final defaultContentText = palette.brandInk;

      final oldBugRatio = _contrast(
        defaultContentText,
        palette.brandWarningDeep,
      );
      final fixedRatio = _contrast(
        defaultContentText,
        palette.warningSnackbarFill,
      );

      expect(
        oldBugRatio,
        lessThan(4.5),
        reason:
            'brandWarningDeep is an INK role that LIGHTENS in dark mode '
            'for text-on-tint use; used as a SnackBar FILL it washes '
            'out to pale cream, dropping the default near-white content '
            'text far below AA',
      );
      expect(
        fixedRatio,
        greaterThanOrEqualTo(4.5),
        reason:
            'warningSnackbarFill stays deep in both themes so the '
            'default SnackBar content text remains legible',
      );
    });

    test('light mode is unchanged — warningSnackbarFill equals the exact old '
        'brandWarningDeep light-mode hex', () {
      const light = AppPalette.light;

      expect(light.warningSnackbarFill, light.brandWarningDeep);
      expect(
        _contrast(const Color(0xFFFFFFFF), light.warningSnackbarFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets(
      'tapping Mark Complete on a write failure shows the real "could not '
      'save" SnackBar with warningSnackbarFill (not brandWarningDeep) in '
      'dark mode',
      (tester) async {
        final router = _MockStackRouter();
        when(() => router.maybePop<Object?>()).thenAnswer((_) async => true);
        when(() => router.canPop()).thenReturn(false);
        when(() => router.currentPath).thenReturn('/reader');

        await tester.pumpWidget(
          _pumpTextDisplayScreen(theme: AppTheme.darkTheme(), router: router),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        // The completion section's own provider chain (trackStorageKey ->
        // isStageCompleted x2) resolves a frame later than the outer
        // textContent/dailyTasks futures — one more pump settles it from
        // its interim CircularProgressIndicator to the real button.
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Mark complete'), findsOneWidget);
        await tester.tap(find.text('Mark complete'));
        // Let the async catch block run and the SnackBar animate in.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));

        expect(snackBar.backgroundColor, AppPalette.dark.warningSnackbarFill);
        expect(
          snackBar.backgroundColor,
          isNot(AppPalette.dark.brandWarningDeep),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 6));
      },
    );

    testWidgets('tapping Mark Complete on a write failure keeps the exact old '
        'background in light mode (no regression)', (tester) async {
      final router = _MockStackRouter();
      when(() => router.maybePop<Object?>()).thenAnswer((_) async => true);
      when(() => router.canPop()).thenReturn(false);
      when(() => router.currentPath).thenReturn('/reader');

      await tester.pumpWidget(
        _pumpTextDisplayScreen(theme: AppTheme.lightTheme(), router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Mark complete'), findsOneWidget);
      await tester.tap(find.text('Mark complete'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));

      expect(snackBar.backgroundColor, const Color(0xFF8A5306));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
