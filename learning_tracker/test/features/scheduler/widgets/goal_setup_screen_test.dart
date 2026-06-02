import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/presentation/screens/goal_setup_screen.dart';
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
    // term-aware unit label produced by `_unitDisplayLabel` — distinct from
    // the unit-picker SegmentedButton, whose labels come from the app-locale
    // l10n keys (always English in these tests).
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
  });
}
