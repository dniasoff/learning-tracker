import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

GoalEntity _makeGoal() => GoalEntity(
  curriculumId: CurriculumId.mishnayos,
  targetPercent: 80.0,
  targetDate: DateTime.utc(2027, 1, 1),
  description: 'Test goal',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Widget _makeApp({required Widget home, List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

/// Builds the goal screen at a specific [locale] + [textScale], used to prove
/// the pace-input label/helper never truncate (R1v2-(5)).
Widget _makeLocalizedApp({
  required Widget home,
  required Locale locale,
  required double textScale,
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: home,
      ),
    ),
  ),
);

/// Asserts that NO [RenderParagraph] rendered inside the pace [TextFormField]'s
/// InputDecorator (its label + helper) is ellipsis-truncated. Under the old
/// layout the field shared a Row with the per-day/week SegmentedButton, which
/// squeezed it so the long label/helper clipped — worse at font scale 1.3.
void _expectPaceLabelsNotTruncated(WidgetTester tester) {
  final field = find.byType(TextFormField);
  expect(field, findsOneWidget);
  final paragraphs = find.descendant(
    of: field,
    matching: find.byType(RichText),
  );
  expect(paragraphs, findsWidgets);
  for (final element in paragraphs.evaluate()) {
    final rp = element.renderObject! as RenderParagraph;
    expect(
      rp.didExceedMaxLines,
      isFalse,
      reason:
          'Pace-input label/helper is ellipsis-truncated — give the field room '
          'so the label and helper wrap (R1v2-(5)). Offending text: '
          '"${rp.text.toPlainText()}"',
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GoalSetupScreen', () {
    testWidgets('renders form with target percentage slider and date picker', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(curriculumId: CurriculumId.mishnayos),
        ),
      );

      expect(find.text('New Goal'), findsOneWidget);
      expect(find.textContaining('100%'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Create Goal'), findsOneWidget);
    });

    testWidgets('goal type toggle shows Deadline and Pace options', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(curriculumId: CurriculumId.mishnayos),
        ),
      );

      expect(find.text('Deadline'), findsOneWidget);
      expect(find.text('Pace'), findsOneWidget);
      expect(find.text('No deadline'), findsOneWidget);
    });

    testWidgets('slider changes target percentage', (tester) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(curriculumId: CurriculumId.mishnayos),
        ),
      );

      expect(find.textContaining('100%'), findsOneWidget);

      final slider = find.byType(Slider);
      final sliderCenter = tester.getCenter(slider);
      await tester.dragFrom(sliderCenter, const Offset(-100, 0));
      await tester.pump();

      expect(find.textContaining('100%'), findsNothing);
    });

    testWidgets('shows mode toggle with deadline and pace options', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            totalItems: 2711,
          ),
        ),
      );

      expect(find.text('Deadline'), findsOneWidget);
      expect(find.text('Pace'), findsOneWidget);
    });

    testWidgets('switching to pace mode shows pace inputs', (tester) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            totalItems: 2711,
          ),
        ),
      );

      // Switch to pace mode
      await tester.tap(find.text('Pace'));
      await tester.pump();

      // Pace inputs visible
      expect(find.text('Per day'), findsOneWidget);
      expect(find.text('Per week'), findsOneWidget);
      // Projected completion card visible
      expect(find.textContaining('Projected completion'), findsOneWidget);
    });

    testWidgets('switching back to deadline mode hides pace inputs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          home: const GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            totalItems: 2711,
          ),
        ),
      );

      // Switch to pace, then back to deadline
      await tester.tap(find.text('Pace'));
      await tester.pump();
      await tester.tap(find.text('Deadline'));
      await tester.pump();

      // Pace inputs hidden
      expect(find.textContaining('Projected completion'), findsNothing);
    });

    testWidgets('pace mode shows curriculum-appropriate unit label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          // Pin English terms so the assertion is deterministic — Hebrew Terms
          // defaults to ON, under which the unit word renders as "עמודים".
          overrides: [useHebrewTermsProvider.overrideWithValue(false)],
          home: const GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            totalItems: 2711,
          ),
        ),
      );

      await tester.tap(find.text('Pace'));
      await tester.pump();

      // Bavli deepest level is "Amud" — appears in input label and projection card
      expect(find.textContaining('Amud'), findsAtLeast(1));
    });

    // Reads the labelText of the pace-input TextFormField. This is the
    // term-aware unit label produced by `_unitDisplayLabel`. The unit-picker
    // SegmentedButton pills are now also term/nusach-aware (they route through
    // the same `CurriculumLabels` library), so they honour the Hebrew Terms
    // toggle and the Ashkenazi/Sefardi nusach rather than the app-locale
    // l10n keys.
    String paceInputLabel(WidgetTester tester) {
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TextFormField),
          matching: find.byType(TextField),
        ),
      );
      return field.decoration!.labelText!;
    }

    testWidgets('pace unit label renders Hebrew term when Hebrew Terms is on '
        '(no hardcoded English)', (tester) async {
      await tester.pumpWidget(
        _makeApp(
          overrides: [useHebrewTermsProvider.overrideWithValue(true)],
          home: const GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            totalItems: 2711,
          ),
        ),
      );

      await tester.tap(find.text('Pace'));
      await tester.pump();

      // Bavli default pace granularity is Amud → Hebrew plural "עמודים".
      // The previous implementation hardcoded English "Amudim"; with the
      // shared-control fix the Hebrew Terms toggle must flip the unit word.
      final label = paceInputLabel(tester);
      expect(label, contains('עמודים'));
      expect(label, isNot(contains('Amudim')));
    });

    testWidgets(
      'pace unit label renders Sephardi nusach (Dapim, not Dafim) for daf '
      'granularity',
      (tester) async {
        await tester.pumpWidget(
          _makeApp(
            overrides: [
              useHebrewTermsProvider.overrideWithValue(false),
              currentTransliterationVariantProvider.overrideWithValue(
                TransliterationVariant.sephardi,
              ),
            ],
            home: const GoalSetupScreen(
              curriculumId: CurriculumId.yerushalmi,
              totalItems: 1554,
            ),
          ),
        );

        await tester.tap(find.text('Pace'));
        await tester.pump();

        // Yerushalmi pace unit is Daf; Sephardi nusach renders "Dapim", and
        // the Ashkenazi "Dafim" must NOT appear in the term-aware input label.
        final label = paceInputLabel(tester);
        expect(label, contains('Dapim'));
        expect(label, isNot(contains('Dafim')));
      },
    );

    // The Daf unit-picker pill must respect the Ashkenazi/Sefardi nusach and
    // the Hebrew Terms toggle. Bavli surfaces both Amud + Daf pills; the Daf
    // word only appears on its pill (default selection/projection is Amud), so
    // matching the Daf form reliably targets the pill itself.
    testWidgets('daf unit pill renders Dafim under Ashkenazi nusach', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          overrides: [
            useHebrewTermsProvider.overrideWithValue(false),
            currentTransliterationVariantProvider.overrideWithValue(
              TransliterationVariant.ashkenazi,
            ),
          ],
          home: const GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            totalItems: 2711,
          ),
        ),
      );

      await tester.tap(find.text('Pace'));
      await tester.pump();

      expect(find.text('Dafim'), findsOneWidget);
      expect(find.text('Dapim'), findsNothing);
      expect(find.text('דפים'), findsNothing);
    });

    testWidgets('daf-paced goal shows the count in dapim, not amudim', (
      tester,
    ) async {
      // FR fix: the "X of Y" count + projection use the SELECTED unit. For a
      // daf goal they must read in dapim (coarse count), not amudim (leaf).
      final dafGoal = GoalEntity(
        curriculumId: CurriculumId.bavli,
        goalType: 'pace',
        paceValue: 7,
        pacePeriod: 'per_week',
        paceGranularity: PaceGranularity.daf,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await tester.pumpWidget(
        _makeApp(
          overrides: [
            useHebrewTermsProvider.overrideWithValue(false),
            currentTransliterationVariantProvider.overrideWithValue(
              TransliterationVariant.ashkenazi,
            ),
            // 5422 amudim collapse to 2711 dapim.
            scopedCoarseUnitCountProvider(
              CurriculumId.bavli,
            ).overrideWith((ref) async => 2711),
          ],
          home: GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            existingGoal: dafGoal,
            totalItems: 5422,
          ),
        ),
      );
      // Let the coarse-count FutureProvider resolve.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The material count reads dapim (2711), never the amud total (5422).
      expect(find.textContaining('2711'), findsWidgets);
      expect(find.textContaining('5422'), findsNothing);
    });

    testWidgets('editing a daf-paced goal pre-selects Daf (not Amud)', (
      tester,
    ) async {
      // Regression: GoalSetupForm.initState used _defaultUnit ('amud' for Bavli)
      // regardless of the saved goal, so editing a daf-paced track wrongly
      // showed amudim. It must restore the saved paceGranularity (daf).
      final dafGoal = GoalEntity(
        curriculumId: CurriculumId.bavli,
        goalType: 'pace',
        paceValue: 7,
        pacePeriod: 'per_week',
        paceGranularity: PaceGranularity.daf,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await tester.pumpWidget(
        _makeApp(
          overrides: [
            useHebrewTermsProvider.overrideWithValue(false),
            currentTransliterationVariantProvider.overrideWithValue(
              TransliterationVariant.ashkenazi,
            ),
            scopedCoarseUnitCountProvider(
              CurriculumId.bavli,
            ).overrideWith((ref) async => 2711),
          ],
          home: GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            existingGoal: dafGoal,
            totalItems: 2711,
          ),
        ),
      );

      await tester.tap(find.text('Pace'));
      await tester.pump();

      // The unit SegmentedButton (segments amud/daf) must have 'daf' selected.
      final unitPicker = tester
          .widgetList<SegmentedButton<String>>(
            find.byType(SegmentedButton<String>),
          )
          .firstWhere((s) => s.segments.any((seg) => seg.value == 'daf'));
      expect(unitPicker.selected, {'daf'});
    });

    testWidgets('daf unit pill renders Dapim under Sefardi nusach', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          overrides: [
            useHebrewTermsProvider.overrideWithValue(false),
            currentTransliterationVariantProvider.overrideWithValue(
              TransliterationVariant.sephardi,
            ),
          ],
          home: const GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            totalItems: 2711,
          ),
        ),
      );

      await tester.tap(find.text('Pace'));
      await tester.pump();

      // Sefardi maps the Ashkenazi "Dafim" to "Dapim" — the wrong spelling
      // ("Dafim") must NOT appear anywhere on the pill.
      expect(find.text('Dapim'), findsOneWidget);
      expect(find.text('Dafim'), findsNothing);
    });

    testWidgets('daf unit pill renders Hebrew דפים when Hebrew Terms is on', (
      tester,
    ) async {
      await tester.pumpWidget(
        _makeApp(
          overrides: [useHebrewTermsProvider.overrideWithValue(true)],
          home: const GoalSetupScreen(
            curriculumId: CurriculumId.bavli,
            totalItems: 2711,
          ),
        ),
      );

      await tester.tap(find.text('Pace'));
      await tester.pump();

      expect(find.text('דפים'), findsOneWidget);
      expect(find.text('Dafim'), findsNothing);
      expect(find.text('Dapim'), findsNothing);
    });

    testWidgets('edit mode shows Update Goal button', (tester) async {
      await tester.pumpWidget(
        _makeApp(
          home: GoalSetupScreen(
            curriculumId: CurriculumId.mishnayos,
            existingGoal: _makeGoal(),
          ),
        ),
      );

      expect(find.text('Edit Goal'), findsOneWidget);
      expect(find.text('Update Goal'), findsOneWidget);
    });

    // R1v2-(5): the pace-input labelText ("<unit> <per>") and helperText
    // ("How many <unit> …?") must never clip/ellipsize at default font OR
    // font scale 1.3, in en + he. Reproduced by rendering the pace section
    // and asserting no label/helper RenderParagraph exceeds its max lines.
    for (final locale in const [Locale('en'), Locale('he')]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('pace input label + helper are not truncated '
            '(${locale.languageCode} @ ${scale}x)', (tester) async {
          // Bavli surfaces the longest unit words (Amudim/Dafim, עמודים/דפים)
          // and exercises the per-day/per-week selector that previously
          // squeezed the field.
          tester.view.physicalSize = const Size(412, 915);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            _makeLocalizedApp(
              locale: locale,
              textScale: scale,
              home: const GoalSetupScreen(
                curriculumId: CurriculumId.bavli,
                totalItems: 2711,
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Switch to pace mode via the speed-icon segment (locale-agnostic).
          await tester.tap(find.byIcon(Icons.speed));
          await tester.pumpAndSettle();

          _expectPaceLabelsNotTruncated(tester);
        });
      }
    }
  });
}
