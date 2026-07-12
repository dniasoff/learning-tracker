import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/hebrew_date_picker.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

Widget _buildTestApp({
  required ValueChanged<DateTime?> onResult,
  Locale? locale,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () async {
            final result = await HebrewDatePicker.show(context);
            onResult(result);
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  group('HebrewDatePicker', () {
    testWidgets('renders year, month, day selectors and action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp(onResult: (_) {}));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(HebrewDatePicker)),
      )!;

      expect(find.text(l10n.schedulerHebrewDatePickerTitle), findsOneWidget);
      expect(find.text(l10n.schedulerHebrewYearLabel), findsOneWidget);
      expect(find.text(l10n.schedulerHebrewMonthFieldLabel), findsOneWidget);
      expect(find.text(l10n.schedulerHebrewDayFieldLabel), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(2));
      expect(find.text(l10n.actionCancel), findsOneWidget);
      expect(find.text(l10n.schedulerSelectDate), findsOneWidget);
    });

    testWidgets(
      'renders Hebrew-localized labels under the Hebrew locale (AX-2)',
      (tester) async {
        // Before AX-2 was fixed, the dialog title/labels/English-date prefix
        // were hardcoded English literals — they rendered in English even
        // when the app locale was Hebrew. Driving the picker under the 'he'
        // locale and asserting the Hebrew-localized strings appear (and the
        // old hardcoded English literals do not) is the regression guard:
        // this fails against the pre-fix widget regardless of which literal
        // happens to coincide with the English ARB value.
        await tester.pumpWidget(
          _buildTestApp(onResult: (_) {}, locale: const Locale('he')),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(HebrewDatePicker)),
        )!;

        expect(find.text(l10n.schedulerHebrewDatePickerTitle), findsOneWidget);
        expect(find.text(l10n.schedulerHebrewYearLabel), findsOneWidget);
        expect(find.text(l10n.schedulerHebrewMonthFieldLabel), findsOneWidget);
        expect(find.text(l10n.schedulerHebrewDayFieldLabel), findsOneWidget);
        expect(
          find.textContaining(l10n.schedulerHebrewDateEnglishPreview('')),
          findsOneWidget,
        );

        // The hardcoded English literals must not leak into the Hebrew
        // locale build.
        expect(find.text('Select Hebrew date'), findsNothing);
        expect(find.text('Hebrew year'), findsNothing);
        expect(find.text('Month'), findsNothing);
        expect(find.text('Day'), findsNothing);
        expect(find.textContaining('English:'), findsNothing);
      },
    );

    testWidgets('displays English-calendar confirmation text', (tester) async {
      await tester.pumpWidget(_buildTestApp(onResult: (_) {}));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(HebrewDatePicker)),
      )!;

      // The ARB template is "English: {date}" — derive the localized prefix
      // (everything before the placeholder value) instead of asserting on
      // the literal English word, so a future non-English locale doesn't
      // silently re-hardcode it.
      final prefix = l10n.schedulerHebrewDateEnglishPreview('');
      expect(prefix.isNotEmpty, isTrue);
      expect(find.textContaining(prefix), findsOneWidget);
    });

    testWidgets('cancel returns null', (tester) async {
      DateTime? result;

      await tester.pumpWidget(_buildTestApp(onResult: (v) => result = v));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('select returns a DateTime', (tester) async {
      DateTime? result;

      await tester.pumpWidget(_buildTestApp(onResult: (v) => result = v));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result, isA<DateTime>());
    });

    testWidgets('year increment updates displayed year', (tester) async {
      await tester.pumpWidget(_buildTestApp(onResult: (_) {}));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Find the Hebrew year (should be > 5000)
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final yearText = textWidgets.firstWhere(
        (t) =>
            int.tryParse(t.data ?? '') != null &&
            (int.tryParse(t.data!) ?? 0) > 5000,
      );
      final initialYear = int.parse(yearText.data!);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('${initialYear + 1}'), findsOneWidget);
    });
  });
}
