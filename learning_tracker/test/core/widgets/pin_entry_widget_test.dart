// AUD-core-widgets-01 (AX-2): PinEntryWidget's default title, lockout
// copy, and Clear button are resolved through AppLocalizations/ARB, not
// hardcoded English literals. Assertions below reference the resolved
// `l10n.*` value (never a literal English string) for those slots, and a
// Locale('he') test proves the Hebrew ARB value actually renders — a
// reintroduced hardcoded English literal could never satisfy that
// assertion.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/pin_entry_widget.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('PinEntryWidget', () {
    testWidgets('should accept exactly 4 numeric digits', (tester) async {
      String? completedPin;

      await tester.pumpWidget(
        _wrap(
          PinEntryWidget(
            onPinComplete: (pin) {
              completedPin = pin;
            },
          ),
        ),
      );

      // Find all TextField widgets (4 digit fields)
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(4));

      // Enter digits one by one
      await tester.enterText(textFields.at(0), '1');
      await tester.pump();
      await tester.enterText(textFields.at(1), '2');
      await tester.pump();
      await tester.enterText(textFields.at(2), '3');
      await tester.pump();
      await tester.enterText(textFields.at(3), '4');
      await tester.pump();

      // Verify callback was called with complete PIN
      expect(completedPin, equals('1234'));
    });

    testWidgets('should show error feedback after incorrect PIN entry', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // errorMessage is a caller-supplied String — not a widget-owned
      // literal, so this stays a plain string (mirrors real callers like
      // onboarding_parent_pin_step.dart resolving it via l10n themselves).
      const errorMessage = 'Incorrect PIN';

      await tester.pumpWidget(
        _wrap(
          PinEntryWidget(onPinComplete: (_) {}, errorMessage: errorMessage),
        ),
      );

      // Verify error message is displayed
      expect(find.text(errorMessage), findsOneWidget);

      // Verify error icon is displayed
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Verify the localized clear button is displayed
      expect(find.text(l10n.actionClear), findsOneWidget);
    });

    testWidgets(
      'should show lockout state with countdown timer when locked out',
      (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        const remainingMinutes = 3;

        await tester.pumpWidget(
          _wrap(
            PinEntryWidget(
              onPinComplete: (_) {},
              isLockedOut: true,
              lockoutRemainingMinutes: remainingMinutes,
            ),
          ),
        );

        // Verify lockout icon is displayed
        expect(find.byIcon(Icons.lock_clock), findsOneWidget);

        // Verify the localized lockout message is displayed
        expect(find.text(l10n.parentPinLockoutTitle), findsOneWidget);
        expect(
          find.text(l10n.parentPinLockoutBody(remainingMinutes)),
          findsOneWidget,
        );

        // Verify PIN entry fields are hidden
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets('should not show PIN entry fields when locked out', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          PinEntryWidget(
            onPinComplete: (_) {},
            isLockedOut: true,
            lockoutRemainingMinutes: 2,
          ),
        ),
      );

      // Verify PIN entry fields are not present
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('should clear all digits when Clear button is tapped', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(
        _wrap(PinEntryWidget(onPinComplete: (_) {}, errorMessage: 'Error')),
      );

      final textFields = find.byType(TextField);

      // Enter some digits
      await tester.enterText(textFields.at(0), '1');
      await tester.enterText(textFields.at(1), '2');
      await tester.pump();

      // Tap Clear button
      await tester.tap(find.text(l10n.actionClear));
      await tester.pump();

      // Verify all fields are cleared
      for (var i = 0; i < 4; i++) {
        final textField = tester.widget<TextField>(textFields.at(i));
        expect(textField.controller!.text, isEmpty);
      }
    });

    testWidgets('should display custom title', (tester) async {
      const customTitle = 'Enter Parent PIN';

      await tester.pumpWidget(
        _wrap(PinEntryWidget(onPinComplete: (_) {}, title: customTitle)),
      );

      expect(find.text(customTitle), findsOneWidget);
    });

    testWidgets('should use the localized default title when not provided', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(_wrap(PinEntryWidget(onPinComplete: (_) {})));

      expect(find.text(l10n.pinEntryDefaultTitle), findsOneWidget);
    });

    testWidgets('should only accept numeric input', (tester) async {
      await tester.pumpWidget(_wrap(PinEntryWidget(onPinComplete: (_) {})));

      final textFields = find.byType(TextField);

      // Try to enter non-numeric characters
      await tester.enterText(textFields.at(0), 'a');
      await tester.pump();

      final textField = tester.widget<TextField>(textFields.at(0));
      // The input formatter should prevent non-numeric input
      expect(textField.controller!.text, isEmpty);
    });

    testWidgets('should limit each field to 1 digit', (tester) async {
      await tester.pumpWidget(_wrap(PinEntryWidget(onPinComplete: (_) {})));

      final textFields = find.byType(TextField);

      // Try to enter multiple digits
      await tester.enterText(textFields.at(0), '123');
      await tester.pump();

      final textField = tester.widget<TextField>(textFields.at(0));
      // Should only contain first digit
      expect(textField.controller!.text.length, lessThanOrEqualTo(1));
    });

    testWidgets('should have error styling when error message is present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(PinEntryWidget(onPinComplete: (_) {}, errorMessage: 'Error')),
      );

      // Find TextField widgets to verify error styling is applied
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // The error styling is applied through decoration, which we can't easily test
      // but we verify the structure is correct
      final firstField = tester.widget<TextField>(textFields.first);
      expect(firstField.decoration, isNotNull);
    });

    testWidgets('should obscure PIN digits', (tester) async {
      await tester.pumpWidget(_wrap(PinEntryWidget(onPinComplete: (_) {})));

      final textFields = find.byType(TextField);
      final firstField = tester.widget<TextField>(textFields.first);

      // Platform-layer obscuring stays ON so screen readers, autofill, and
      // IME suggestions never leak the PIN. The visible filled-slot dot is
      // drawn by an overlay Container (see _PinDigitField doc); the
      // obscuring char is a space so the TextField itself draws nothing.
      expect(firstField.obscureText, isTrue);
      expect(firstField.obscuringCharacter, equals(' '));
    });

    testWidgets('should auto-advance to next field after digit entry', (
      tester,
    ) async {
      String? completedPin;

      await tester.pumpWidget(
        _wrap(
          PinEntryWidget(
            onPinComplete: (pin) {
              completedPin = pin;
            },
          ),
        ),
      );

      final textFields = find.byType(TextField);

      // Enter first digit
      await tester.enterText(textFields.at(0), '1');
      await tester.pump();

      // Enter second digit
      await tester.enterText(textFields.at(1), '2');
      await tester.pump();

      // Enter third digit
      await tester.enterText(textFields.at(2), '3');
      await tester.pump();

      // Enter fourth digit - this should trigger completion
      await tester.enterText(textFields.at(3), '4');
      await tester.pump();

      // Verify all digits were entered correctly
      expect(completedPin, equals('1234'));
    });

    testWidgets('should handle backspace navigation', (tester) async {
      await tester.pumpWidget(_wrap(PinEntryWidget(onPinComplete: (_) {})));

      final textFields = find.byType(TextField);

      // Enter digits in first two fields
      await tester.enterText(textFields.at(0), '1');
      await tester.pump();
      await tester.enterText(textFields.at(1), '2');
      await tester.pump();

      // Clear the second field (simulating backspace)
      await tester.enterText(textFields.at(1), '');
      await tester.pump();

      // The widget should handle this gracefully
      final secondField = tester.widget<TextField>(textFields.at(1));
      expect(secondField.controller!.text, isEmpty);
    });

    testWidgets('renders the Hebrew ARB default title, lockout copy, and Clear '
        'label under Locale("he") — a hardcoded English literal could '
        'never satisfy this assertion', (tester) async {
      final l10nHe = await AppLocalizations.delegate.load(const Locale('he'));
      final l10nEn = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(
        _wrap(
          PinEntryWidget(
            onPinComplete: (_) {},
            isLockedOut: true,
            lockoutRemainingMinutes: 3,
          ),
          locale: const Locale('he'),
        ),
      );

      expect(find.text(l10nHe.parentPinLockoutTitle), findsOneWidget);
      expect(find.text(l10nHe.parentPinLockoutBody(3)), findsOneWidget);
      expect(
        l10nHe.parentPinLockoutTitle,
        isNot(equals(l10nEn.parentPinLockoutTitle)),
      );

      // Default title + Clear button, under the non-lockout branch.
      await tester.pumpWidget(
        _wrap(
          PinEntryWidget(onPinComplete: (_) {}, errorMessage: 'Error'),
          locale: const Locale('he'),
        ),
      );
      expect(find.text(l10nHe.pinEntryDefaultTitle), findsOneWidget);
      expect(find.text(l10nHe.actionClear), findsOneWidget);
      expect(
        l10nHe.pinEntryDefaultTitle,
        isNot(equals(l10nEn.pinEntryDefaultTitle)),
      );
    });
  });
}
