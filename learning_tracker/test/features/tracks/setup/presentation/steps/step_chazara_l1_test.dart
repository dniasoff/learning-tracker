@Tags(['tracks', 'steps', 'chazara', 'l1', 'i18n'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_chazara.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _delegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _app({Locale locale = const Locale('en'), List<int>? initialDelays}) =>
    ProviderScope(
      retry: (_, __) => null,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: _delegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 900,
            child: ChazaraInlineSetup(
              curriculumId: CurriculumId.mishnayos,
              headerTitle: 'Review Setup',
              headerSubtitle: 'Choose a schedule',
              initialDelays: initialDelays,
              onComplete: (_) {},
            ),
          ),
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('English locale shows quick-fill chips and labeled day fields', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _settle(tester);

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
    expect(find.text('Review interval 1'), findsOneWidget);
    expect(find.text('Review interval 2'), findsOneWidget);
    expect(find.text('Add interval'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Hebrew locale localizes chips and interval controls', (
    tester,
  ) async {
    await tester.pumpWidget(_app(locale: const Locale('he')));
    await _settle(tester);

    expect(find.text('לימוד בלבד'), findsOneWidget);
    expect(find.text('מרווח חזרה 1'), findsOneWidget);
    expect(find.text('הוסף מרווח'), findsOneWidget);
    expect(find.text('Review intervals'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('existing custom intervals remain visible and editable', (
    tester,
  ) async {
    await tester.pumpWidget(_app(initialDelays: [2, 9, 40]));
    await _settle(tester);

    expect(find.byType(TextField), findsNWidgets(3));
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      '2',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      '9',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text,
      '40',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('interval fields expose numeric keyboards and remove labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await _settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.keyboardType, TextInputType.number);
    expect(find.byTooltip('Remove review interval 1'), findsOneWidget);
    expect(find.text('Review interval 1'), findsOneWidget);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('positive whole numbers are required', (tester) async {
    await tester.pumpWidget(_app(initialDelays: [1]));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, '0');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('Enter a positive whole number of days.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '1.5');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('Enter a whole number of days.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
