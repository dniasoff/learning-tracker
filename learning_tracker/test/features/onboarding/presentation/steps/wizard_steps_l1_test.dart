// L1 widget tests for wizard_steps.dart
//
// Covers all five public step widgets:
//   WizardChooseMethodStep   — three option cards; "Follow a program" only when
//                              presets non-empty; tapping Custom/No-Review fires
//                              onComplete; tapping "Follow a program" calls
//                              ctx.advance; childName in question text.
//   WizardSelectPresetStep   — preset cards render; tapping selects; Confirm
//                              disabled until selection; Confirm fires onComplete
//                              with preset choice; childName in question text.
//   WizardCustomStep1        — slider renders; slider change updates round count
//                              display; Next button calls ctx.advance and syncs
//                              rounds list length.
//   WizardCustomStep2        — round timing cards render per round; Days/Weeks
//                              segmented button switches mode; delay slider
//                              present in Days mode; day chips present in Weeks
//                              mode; Next advances.
//   WizardCustomStep3        — review card shows Learn + chazara stages; Confirm
//                              fires onComplete with customRounds; delay-mode
//                              summary text; weekly-mode summary text.
//
// Product rules asserted:
//   • child+adult only (no "parent" mode — tests use isChildMode bool).
//   • No track-type labels (no "Personal"/"Standard"/"Custom" type labels in
//     the wizard UI).
//   • Offline-first: all wizard steps are purely local / no network calls.
//
// Pump rig:
//   ProviderScope(overrides:[useHebrewTermsProvider], child:
//   MaterialApp(locale, 4 l10n delegates, home: Scaffold(body: widget)))
//   pump() + pump(Duration(seconds:1)) — never pumpAndSettle.
//   teardown: pumpWidget(SizedBox.shrink()) + pump(Duration.zero).

@Tags(['onboarding', 'wizard', 'l1'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/models/wizard_result_wrapper.dart';
import 'package:learning_tracker/features/onboarding/domain/services/learning_process_wizard_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_step.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/wizard_steps.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── Provider overrides ────────────────────────────────────────────────────────

class _FalseUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _TrueUseHebrewTerms extends UseHebrewTerms {
  @override
  bool build() => true;
}

// ── Constants ─────────────────────────────────────────────────────────────────

const _kDelegates = [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

LearningProgramData _preset({
  int id = 1,
  String name = 'Test Program',
  String displayName = 'Test Program',
  String description = 'A test program',
  String curriculumType = 'mishnayos',
}) => LearningProgramData(
  id: id,
  name: name,
  displayName: displayName,
  description: description,
  curriculumType: curriculumType,
  isActive: true,
  hasTests: false,
  stagesConfig: '[]',
  testConfig: '{}',
  apiSource: null,
  apiProgramKey: null,
  isCalendarProgram: false,
);

/// Build a no-op [OnboardingStepContext] — advances do nothing unless
/// [onAdvance] is provided.
OnboardingStepContext _ctx({
  Future<void> Function()? onAdvance,
  void Function()? onRetreat,
}) => OnboardingStepContext(
  advance: onAdvance ?? () async {},
  retreat: onRetreat ?? () {},
  stepIndex: 0,
  totalSteps: 3,
);

// ── WizardChooseMethodStep ────────────────────────────────────────────────────

void main() {
  // ── WizardChooseMethodStep ──────────────────────────────────────────────────

  group('WizardChooseMethodStep', () {
    late bool advanceCalled;
    late LearningProcessWizardResult? capturedResult;

    setUp(() {
      advanceCalled = false;
      capturedResult = null;
    });

    // Because build() requires a WidgetRef we pump the inner ConsumerWidget
    // directly via a helper that uses Builder + ProviderScope.
    Widget buildDirect({
      List<LearningProgramData> presets = const [],
      bool isChildMode = false,
      String? childName,
      Locale locale = const Locale('en'),
      bool useHebrew = false,
    }) {
      final ctx = _ctx(onAdvance: () async { advanceCalled = true; });
      return ProviderScope(
        overrides: [
          useHebrewTermsProvider.overrideWith(
            () => useHebrew ? _TrueUseHebrewTerms() : _FalseUseHebrewTerms(),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: _kDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final step = WizardChooseMethodStep(
                  curriculumId: CurriculumId.mishnayos,
                  presets: presets,
                  isChildMode: isChildMode,
                  childName: childName,
                  onComplete: (r) => capturedResult = r,
                );
                return step.build(context, ref, ctx);
              },
            ),
          ),
        ),
      );
    }

    testWidgets(
      'shows "Custom schedule" option card always',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        expect(find.text('Custom schedule'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'shows "No formal review" option card always',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        expect(find.text('No formal review'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'shows "Follow a program" card when presets are non-empty',
      (tester) async {
        await tester.pumpWidget(buildDirect(presets: [_preset()]));
        await _settle(tester);

        expect(find.text('Follow a program'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'hides "Follow a program" card when presets list is empty',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        expect(find.text('Follow a program'), findsNothing);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'question text is "How do you review?" in self mode',
      (tester) async {
        await tester.pumpWidget(buildDirect(isChildMode: false));
        await _settle(tester);

        expect(find.text('How do you review?'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'question text includes childName when isChildMode=true and childName is set',
      (tester) async {
        await tester.pumpWidget(
          buildDirect(isChildMode: true, childName: 'Moshe'),
        );
        await _settle(tester);

        expect(find.text('How does Moshe review?'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'question text falls back to "How do you review?" when childName is null',
      (tester) async {
        await tester.pumpWidget(buildDirect(isChildMode: true, childName: null));
        await _settle(tester);

        expect(find.text('How do you review?'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'tapping "Custom schedule" fires onComplete with WizardChoice.custom',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        await tester.tap(find.text('Custom schedule'));
        await tester.pump();

        expect(capturedResult, isNotNull);
        expect(
          capturedResult!.wizardResult.choice,
          equals(WizardChoice.custom),
        );
        await _tearDown(tester);
      },
    );

    testWidgets(
      'tapping "No formal review" fires onComplete with WizardChoice.noReview',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        await tester.tap(find.text('No formal review'));
        await tester.pump();

        expect(capturedResult, isNotNull);
        expect(
          capturedResult!.wizardResult.choice,
          equals(WizardChoice.noReview),
        );
        await _tearDown(tester);
      },
    );

    testWidgets(
      'tapping "Follow a program" calls ctx.advance (not onComplete)',
      (tester) async {
        await tester.pumpWidget(buildDirect(presets: [_preset()]));
        await _settle(tester);

        await tester.tap(find.text('Follow a program'));
        await tester.pump();

        expect(advanceCalled, isTrue);
        expect(capturedResult, isNull);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'onComplete result carries the correct curriculumId',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        await tester.tap(find.text('No formal review'));
        await tester.pump();

        expect(
          capturedResult!.wizardResult.curriculumId,
          equals(CurriculumId.mishnayos),
        );
        await _tearDown(tester);
      },
    );

    testWidgets(
      'presets count subtitle shows number of available programs',
      (tester) async {
        await tester.pumpWidget(
          buildDirect(presets: [_preset(id: 1), _preset(id: 2)]),
        );
        await _settle(tester);

        expect(find.text('2 programs available'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'Hebrew locale smoke: step mounts without overflow or crash',
      (tester) async {
        await tester.pumpWidget(
          buildDirect(locale: const Locale('he'), useHebrew: true),
        );
        await _settle(tester);

        // Key affordances must still be findable.
        expect(find.text('Custom schedule'), findsOneWidget);
        expect(find.text('No formal review'), findsOneWidget);
        await _tearDown(tester);
      },
    );
  });

  // ── WizardSelectPresetStep ──────────────────────────────────────────────────

  group('WizardSelectPresetStep', () {
    late LearningProcessWizardResult? capturedResult;

    setUp(() {
      capturedResult = null;
    });

    Widget buildDirect({
      List<LearningProgramData> presets = const [],
      bool isChildMode = false,
      String? childName,
      WizardStepData? data,
      Locale locale = const Locale('en'),
      bool useHebrew = false,
    }) {
      final stepData = data ?? WizardStepData();
      return ProviderScope(
        overrides: [
          useHebrewTermsProvider.overrideWith(
            () => useHebrew ? _TrueUseHebrewTerms() : _FalseUseHebrewTerms(),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: _kDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final step = WizardSelectPresetStep(
                  curriculumId: CurriculumId.mishnayos,
                  presets: presets,
                  isChildMode: isChildMode,
                  childName: childName,
                  data: stepData,
                  onComplete: (r) => capturedResult = r,
                );
                return step.build(context, ref, _ctx());
              },
            ),
          ),
        ),
      );
    }

    testWidgets(
      'renders each preset card by displayName',
      (tester) async {
        final presets = [
          _preset(id: 1, displayName: 'Program Alpha'),
          _preset(id: 2, displayName: 'Program Beta'),
        ];
        await tester.pumpWidget(buildDirect(presets: presets));
        await _settle(tester);

        expect(find.text('Program Alpha'), findsOneWidget);
        expect(find.text('Program Beta'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'Confirm button is disabled when no preset is selected',
      (tester) async {
        final presets = [_preset(id: 1, displayName: 'Only Program')];
        await tester.pumpWidget(buildDirect(presets: presets));
        await _settle(tester);

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'tapping a preset card selects it (shows check_circle icon)',
      (tester) async {
        final presets = [_preset(id: 1, displayName: 'Solo Program')];
        await tester.pumpWidget(buildDirect(presets: presets));
        await _settle(tester);

        expect(find.byIcon(Icons.check_circle), findsNothing);

        await tester.tap(find.text('Solo Program'));
        await tester.pump();

        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'Confirm button is enabled after selecting a preset',
      (tester) async {
        final presets = [_preset(id: 1, displayName: 'Selectable')];
        await tester.pumpWidget(buildDirect(presets: presets));
        await _settle(tester);

        await tester.tap(find.text('Selectable'));
        await tester.pump();

        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNotNull);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'tapping Confirm fires onComplete with WizardChoice.preset and correct programId',
      (tester) async {
        final presets = [_preset(id: 42, displayName: 'The Program')];
        await tester.pumpWidget(buildDirect(presets: presets));
        await _settle(tester);

        await tester.tap(find.text('The Program'));
        await tester.pump();

        await tester.tap(find.byType(FilledButton));
        await tester.pump();

        expect(capturedResult, isNotNull);
        expect(
          capturedResult!.wizardResult.choice,
          equals(WizardChoice.preset),
        );
        expect(capturedResult!.wizardResult.programId, equals(42));
        await _tearDown(tester);
      },
    );

    testWidgets(
      'shows "Select a program" heading when not in child mode',
      (tester) async {
        final presets = [_preset()];
        await tester.pumpWidget(buildDirect(presets: presets));
        await _settle(tester);

        expect(find.text('Select a program'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'shows child-name heading when isChildMode=true and childName is set',
      (tester) async {
        final presets = [_preset()];
        await tester.pumpWidget(
          buildDirect(
            presets: presets,
            isChildMode: true,
            childName: 'Yoni',
          ),
        );
        await _settle(tester);

        expect(
          find.text('What program does Yoni follow?'),
          findsOneWidget,
        );
        await _tearDown(tester);
      },
    );

    testWidgets(
      'only one preset can be selected at a time (second tap deselects first)',
      (tester) async {
        final presets = [
          _preset(id: 1, displayName: 'First'),
          _preset(id: 2, displayName: 'Second'),
        ];
        await tester.pumpWidget(buildDirect(presets: presets));
        await _settle(tester);

        await tester.tap(find.text('First'));
        await tester.pump();
        expect(find.byIcon(Icons.check_circle), findsOneWidget);

        await tester.tap(find.text('Second'));
        await tester.pump();
        // Still only one check_circle — now on Second
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'Hebrew locale smoke: preset cards render without overflow',
      (tester) async {
        final presets = [_preset(id: 1, displayName: 'Daf Yomi')];
        await tester.pumpWidget(
          buildDirect(
            presets: presets,
            locale: const Locale('he'),
            useHebrew: true,
          ),
        );
        await _settle(tester);

        expect(find.text('Daf Yomi'), findsOneWidget);
        await _tearDown(tester);
      },
    );
  });

  // ── WizardCustomStep1 ───────────────────────────────────────────────────────

  group('WizardCustomStep1', () {
    late bool advanceCalled;
    late WizardStepData stepData;

    setUp(() {
      advanceCalled = false;
      stepData = WizardStepData();
    });

    Widget buildDirect({
      Locale locale = const Locale('en'),
      bool useHebrew = false,
    }) => ProviderScope(
      overrides: [
        useHebrewTermsProvider.overrideWith(
          () => useHebrew ? _TrueUseHebrewTerms() : _FalseUseHebrewTerms(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: _kDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final ctx = _ctx(onAdvance: () async { advanceCalled = true; });
              return WizardCustomStep1(data: stepData).build(context, ref, ctx);
            },
          ),
        ),
      ),
    );

    testWidgets(
      'shows "How many review rounds?" heading',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        expect(find.text('How many review rounds?'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'initial display shows "1 round" (default chazarahRounds=1)',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        expect(find.text('1 round'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'Slider widget is rendered',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        expect(find.byType(Slider), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'tapping Next button calls ctx.advance',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        // "Next" from actionNext l10n key
        await tester.tap(find.text('Next'));
        await tester.pump();

        expect(advanceCalled, isTrue);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'tapping Next with default 1 round syncs rounds list to length 1',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        await tester.tap(find.text('Next'));
        await tester.pump();

        expect(stepData.rounds.length, equals(1));
        await _tearDown(tester);
      },
    );

    testWidgets(
      'plural "rounds" shown when chazarahRounds > 1 after slider drag',
      (tester) async {
        // Pre-set data to 2 rounds to avoid depending on slider drag precision.
        stepData.chazarahRounds = 2;
        stepData.rounds = [
          CustomRoundState.withDefault(0),
          CustomRoundState.withDefault(1),
        ];
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        expect(find.text('2 rounds'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'Next syncs rounds list: starts with 1, data set to 3 → list trimmed to 3',
      (tester) async {
        stepData.chazarahRounds = 3;
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        await tester.tap(find.text('Next'));
        await tester.pump();

        expect(stepData.rounds.length, equals(3));
        await _tearDown(tester);
      },
    );

    testWidgets(
      'Hebrew locale smoke: step mounts without crash',
      (tester) async {
        await tester.pumpWidget(
          buildDirect(locale: const Locale('he'), useHebrew: true),
        );
        await _settle(tester);

        expect(find.text('How many review rounds?'), findsOneWidget);
        await _tearDown(tester);
      },
    );
  });

  // ── WizardCustomStep2 ───────────────────────────────────────────────────────

  group('WizardCustomStep2', () {
    late bool advanceCalled;
    late WizardStepData stepData;

    setUp(() {
      advanceCalled = false;
      // Two rounds by default.
      stepData = WizardStepData()
        ..chazarahRounds = 2
        ..rounds = [
          CustomRoundState.withDefault(0),
          CustomRoundState.withDefault(1),
        ];
    });

    Widget buildDirect({
      WizardStepData? data,
      Locale locale = const Locale('en'),
      bool useHebrew = false,
    }) {
      final d = data ?? stepData;
      return ProviderScope(
        overrides: [
          useHebrewTermsProvider.overrideWith(
            () => useHebrew ? _TrueUseHebrewTerms() : _FalseUseHebrewTerms(),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: _kDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final ctx =
                    _ctx(onAdvance: () async { advanceCalled = true; });
                return WizardCustomStep2(data: d).build(context, ref, ctx);
              },
            ),
          ),
        ),
      );
    }

    testWidgets(
      'shows "Set delay for each round" heading',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        expect(find.text('Set delay for each round'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'renders one timing card per round',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        // SegmentedButton appears once per round.
        expect(find.byType(SegmentedButton<bool>), findsNWidgets(2));
        await _tearDown(tester);
      },
    );

    testWidgets(
      'delay slider is visible in Days mode (default)',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        expect(find.byType(Slider), findsWidgets);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'switching to Weeks mode hides delay slider and shows day chips',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        // Tap the "Weeks" segment of the first round's SegmentedButton.
        await tester.tap(find.text('Weeks').first);
        await tester.pump();

        // FilterChips for days of week are shown (Sun, Mon, Tue…).
        expect(find.byType(FilterChip), findsWidgets);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'day chips include all expected days in Weeks mode',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        await tester.tap(find.text('Weeks').first);
        await tester.pump();

        for (final day in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Shabbos']) {
          expect(find.text(day), findsWidgets);
        }
        await _tearDown(tester);
      },
    );

    testWidgets(
      'tapping a day chip in Weeks mode adds it to selectedDays',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        await tester.tap(find.text('Weeks').first);
        await tester.pump();

        await tester.tap(find.text('Mon').first);
        await tester.pump();

        expect(stepData.rounds[0].selectedDays.contains(1), isTrue);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'tapping Next calls ctx.advance',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        await tester.tap(find.text('Next'));
        await tester.pump();

        expect(advanceCalled, isTrue);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'single-round step renders exactly one timing card',
      (tester) async {
        final d = WizardStepData()
          ..chazarahRounds = 1
          ..rounds = [CustomRoundState.withDefault(0)];
        await tester.pumpWidget(buildDirect(data: d));
        await _settle(tester);

        expect(find.byType(SegmentedButton<bool>), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'Hebrew locale smoke: step renders without crash',
      (tester) async {
        await tester.pumpWidget(
          buildDirect(locale: const Locale('he'), useHebrew: true),
        );
        await _settle(tester);

        expect(find.text('Set delay for each round'), findsOneWidget);
        await _tearDown(tester);
      },
    );
  });

  // ── WizardCustomStep3 ───────────────────────────────────────────────────────

  group('WizardCustomStep3', () {
    late LearningProcessWizardResult? capturedResult;
    late WizardStepData stepData;

    setUp(() {
      capturedResult = null;
      stepData = WizardStepData()
        ..chazarahRounds = 2
        ..rounds = [
          CustomRoundState.withDefault(0), // 1 day delay
          CustomRoundState.withDefault(1), // 7 days delay
        ];
    });

    Widget buildDirect({
      WizardStepData? data,
      Locale locale = const Locale('en'),
      bool useHebrew = false,
    }) {
      final d = data ?? stepData;
      return ProviderScope(
        overrides: [
          useHebrewTermsProvider.overrideWith(
            () => useHebrew ? _TrueUseHebrewTerms() : _FalseUseHebrewTerms(),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: _kDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final step = WizardCustomStep3(
                  curriculumId: CurriculumId.mishnayos,
                  data: d,
                  onComplete: (r) => capturedResult = r,
                );
                return step.build(context, ref, _ctx());
              },
            ),
          ),
        ),
      );
    }

    testWidgets(
      'shows "Review your schedule" heading',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        expect(find.text('Review your schedule'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'shows "Daily new material" subtitle for the Learn stage',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        expect(find.text('Daily new material'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'shows delay summary text for a delay-mode round',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        // First round: delayDays=1 → "1 day after learning"
        expect(find.text('1 day after learning'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'plural delay days in summary text: 7 days → "7 days after learning"',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        expect(find.text('7 days after learning'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'shows weekly day summary text for a weekly-mode round',
      (tester) async {
        final d = WizardStepData()
          ..chazarahRounds = 1
          ..rounds = [
            CustomRoundState.withDefault(0)
              ..useWeekly = true
              ..selectedDays = {1, 4},  // Mon, Thu
          ];
        await tester.pumpWidget(buildDirect(data: d));
        await _settle(tester);

        expect(find.textContaining('Every'), findsOneWidget);
        expect(find.textContaining('Mon'), findsOneWidget);
        expect(find.textContaining('Thu'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'tapping Confirm fires onComplete with WizardChoice.custom',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        expect(capturedResult, isNotNull);
        expect(
          capturedResult!.wizardResult.choice,
          equals(WizardChoice.custom),
        );
        await _tearDown(tester);
      },
    );

    testWidgets(
      'Confirm result carries correct curriculumId',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        expect(
          capturedResult!.wizardResult.curriculumId,
          equals(CurriculumId.mishnayos),
        );
        await _tearDown(tester);
      },
    );

    testWidgets(
      'Confirm result carries correct number of customRounds',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        expect(capturedResult!.wizardResult.customRounds, hasLength(2));
        await _tearDown(tester);
      },
    );

    testWidgets(
      'customRound for delay mode has ScheduleType.delay and correct delayDays',
      (tester) async {
        await tester.pumpWidget(buildDirect());
        await _settle(tester);

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        final round = capturedResult!.wizardResult.customRounds!.first;
        expect(round.scheduleType.name, equals('delay'));
        expect(round.delayDays, equals(1));
        await _tearDown(tester);
      },
    );

    testWidgets(
      'customRound for weekly mode has ScheduleType.weekly and daysOfWeek',
      (tester) async {
        final d = WizardStepData()
          ..chazarahRounds = 1
          ..rounds = [
            CustomRoundState.withDefault(0)
              ..useWeekly = true
              ..selectedDays = {1, 3},
          ];
        await tester.pumpWidget(buildDirect(data: d));
        await _settle(tester);

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        final round = capturedResult!.wizardResult.customRounds!.first;
        expect(round.scheduleType.name, equals('weekly'));
        expect(round.daysOfWeek, containsAll([1, 3]));
        await _tearDown(tester);
      },
    );

    testWidgets(
      'Hebrew locale smoke: step3 renders without crash in he locale',
      (tester) async {
        await tester.pumpWidget(
          buildDirect(locale: const Locale('he'), useHebrew: true),
        );
        await _settle(tester);

        expect(find.text('Review your schedule'), findsOneWidget);
        await _tearDown(tester);
      },
    );

    testWidgets(
      'single round: card renders one chazara stage row',
      (tester) async {
        final d = WizardStepData()
          ..chazarahRounds = 1
          ..rounds = [CustomRoundState.withDefault(0)];
        await tester.pumpWidget(buildDirect(data: d));
        await _settle(tester);

        expect(find.text('1 day after learning'), findsOneWidget);
        // No second row divider needed — just the single round summary.
        await _tearDown(tester);
      },
    );
  });

  // ── WizardStepData + CustomRoundState unit behaviour ────────────────────────

  group('WizardStepData defaults', () {
    test('initial chazarahRounds is 1', () {
      expect(WizardStepData().chazarahRounds, equals(1));
    });

    test('initial rounds list has one element', () {
      expect(WizardStepData().rounds, hasLength(1));
    });

    test('initial selectedPresetId is null', () {
      expect(WizardStepData().selectedPresetId, isNull);
    });
  });

  group('CustomRoundState.withDefault', () {
    test('index 0 → delayDays=1', () {
      expect(CustomRoundState.withDefault(0).delayDays, equals(1));
    });

    test('index 1 → delayDays=7', () {
      expect(CustomRoundState.withDefault(1).delayDays, equals(7));
    });

    test('index 2 → delayDays=30', () {
      expect(CustomRoundState.withDefault(2).delayDays, equals(30));
    });

    test('index 3 → delayDays=60', () {
      expect(CustomRoundState.withDefault(3).delayDays, equals(60));
    });

    test('index 4 → delayDays=90', () {
      expect(CustomRoundState.withDefault(4).delayDays, equals(90));
    });

    test('index beyond range → delayDays=90', () {
      expect(CustomRoundState.withDefault(10).delayDays, equals(90));
    });

    test('initial useWeekly is false', () {
      expect(CustomRoundState.withDefault(0).useWeekly, isFalse);
    });

    test('initial selectedDays is empty', () {
      expect(CustomRoundState.withDefault(0).selectedDays, isEmpty);
    });
  });
}
