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
  supportedLocales: const [Locale('en'), Locale('he')],
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => showLearningAppDatePicker(
          context: context,
          initialDate: DateTime(2026, 1, 2),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        ),
        child: const Text('Open date picker'),
      ),
    ),
  ),
);

void main() {
  for (final locale in const [Locale('en'), Locale('he')]) {
    testWidgets('$locale opens the localized calendar without text input', (
      tester,
    ) async {
      await tester.pumpWidget(_app(locale));
      await tester.tap(find.text('Open date picker'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(CalendarDatePicker), findsOneWidget);

      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.initialDate, DateTime(2026, 1, 2));
      expect(dialog.initialEntryMode, DatePickerEntryMode.calendar);
      final pickerContext = tester.element(find.byType(DatePickerDialog));
      final pickerLocalizations = MaterialLocalizations.of(pickerContext);
      expect(
        Localizations.localeOf(pickerContext).languageCode,
        locale.languageCode,
      );
      expect(
        find.text(pickerLocalizations.formatMediumDate(DateTime(2026, 1, 2))),
        findsOneWidget,
      );
    });
  }
}
