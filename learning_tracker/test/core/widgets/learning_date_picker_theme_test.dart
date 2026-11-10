import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/learning_date_picker_theme.dart';

Widget _app(Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en', 'US'), Locale('en', 'GB')],
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => showLearningAppDatePicker(
          context: context,
          initialDate: DateTime(2026, 1, 2),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialEntryMode: DatePickerEntryMode.input,
        ),
        child: const Text('Open date picker'),
      ),
    ),
  ),
);

void main() {
  for (final testCase in const [
    (locale: Locale('en', 'GB'), hint: 'dd/mm/yyyy'),
    (locale: Locale('en', 'US'), hint: 'mm/dd/yyyy'),
  ]) {
    testWidgets(
      'date input uses text keyboard and ${testCase.locale} date order',
      (tester) async {
        await tester.pumpWidget(_app(testCase.locale));
        await tester.tap(find.text('Open date picker'));
        await tester.pumpAndSettle();

        final field = tester.widget<TextField>(find.byType(TextField).first);
        expect(field.keyboardType, TextInputType.text);
        expect(field.decoration!.hintText, testCase.hint);
      },
    );
  }
}
