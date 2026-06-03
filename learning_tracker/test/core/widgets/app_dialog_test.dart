// Tests for the shared, overflow-safe dialog component (app_dialog.dart).
//
// Proves:
//   (a) showAppConfirmDialog renders the title/message/actions and returns
//       true on confirm, false on cancel.
//   (b) CRITICAL — at a tiny screen (320x480) with textScaleFactor 2.0 and a
//       very long message, the dialog does NOT overflow (takeException() is
//       null) and its content is scrollable (a Scrollable is present). This is
//       the overflow-safe-by-construction proof.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/widgets/app_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Wraps a launcher button that opens a confirm dialog, capturing its result.
Widget _confirmHarness({
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  required void Function(bool result) onResult,
  Size? surfaceSize,
  double textScaleFactor = 1.0,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        Widget scaffold = Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () async {
                final result = await showAppConfirmDialog(
                  context: context,
                  title: title,
                  message: message,
                  confirmLabel: confirmLabel,
                  cancelLabel: cancelLabel,
                  destructive: destructive,
                );
                onResult(result);
              },
              child: const Text('Open'),
            ),
          ),
        );
        if (surfaceSize != null || textScaleFactor != 1.0) {
          final media = MediaQuery.of(context);
          scaffold = MediaQuery(
            data: media.copyWith(
              size: surfaceSize ?? media.size,
              textScaler: TextScaler.linear(textScaleFactor),
            ),
            child: scaffold,
          );
        }
        return scaffold;
      },
    ),
  );
}

void main() {
  group('showAppConfirmDialog', () {
    testWidgets('renders title, message and both actions', (tester) async {
      await tester.pumpWidget(
        _confirmHarness(
          title: 'Exit Track Setup?',
          message: 'Are you sure you want to exit?',
          confirmLabel: 'Exit',
          cancelLabel: 'Cancel',
          onResult: (_) {},
        ),
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(find.text('Exit Track Setup?'), findsOneWidget);
      expect(find.text('Are you sure you want to exit?'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Exit'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    });

    testWidgets('returns true when confirm is tapped', (tester) async {
      bool? captured;
      await tester.pumpWidget(
        _confirmHarness(
          title: 'Confirm?',
          message: 'Proceed with the action.',
          confirmLabel: 'Yes',
          cancelLabel: 'No',
          onResult: (r) => captured = r,
        ),
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Yes'));
      await tester.pumpAndSettle();

      expect(captured, isTrue);
    });

    testWidgets('returns false when cancel is tapped', (tester) async {
      bool? captured;
      await tester.pumpWidget(
        _confirmHarness(
          title: 'Confirm?',
          message: 'Proceed with the action.',
          confirmLabel: 'Yes',
          cancelLabel: 'No',
          onResult: (r) => captured = r,
        ),
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'No'));
      await tester.pumpAndSettle();

      expect(captured, isFalse);
    });

    testWidgets('falls back to localized confirm/cancel labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        _confirmHarness(
          title: 'No labels',
          message: 'Uses defaults.',
          onResult: (_) {},
        ),
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      // Default English l10n: actionConfirm = 'Confirm', actionCancel = 'Cancel'.
      expect(find.widgetWithText(FilledButton, 'Confirm'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    });
  });

  group('overflow safety (by construction)', () {
    testWidgets('tiny 320x480 screen + textScaleFactor 2.0 + long message: '
        'no overflow and content scrolls', (tester) async {
      // Force the physical test surface to the tiny screen so the dialog
      // really is height-constrained, not just logically.
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const longMessage =
          'Are you sure you want to exit this flow right now? '
          'Your setup progress will be permanently lost and cannot be '
          'recovered. You will have to start the entire track setup process '
          'over again from the very beginning, re-selecting your curriculum, '
          'your schedule, your goals, and re-entering every detail you have '
          'carefully entered so far during this session. Please confirm that '
          'this is truly what you intend to do before continuing.';

      await tester.pumpWidget(
        _confirmHarness(
          title: 'Exit Track Setup With A Very Long Title That Wraps?',
          message: longMessage,
          confirmLabel: 'Exit Now And Discard All Progress',
          cancelLabel: 'Cancel And Keep Editing',
          destructive: true,
          surfaceSize: const Size(320, 480),
          textScaleFactor: 2.0,
          onResult: (_) {},
        ),
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      // CRITICAL ASSERTION: no RenderFlex / constraint overflow exceptions.
      expect(tester.takeException(), isNull);

      // The dialog is open and its content is scrollable.
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(find.byType(Scrollable), findsWidgets);

      // The title is still rendered (content present, just scrollable).
      expect(
        find.text('Exit Track Setup With A Very Long Title That Wraps?'),
        findsOneWidget,
      );
    });

    testWidgets('open keyboard (viewInsets) does not cause overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 380);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        _confirmHarness(
          title: 'Keyboard Open Title That Is Reasonably Long',
          message:
              'This dialog should remain entirely scrollable and never '
              'overflow even when the on-screen keyboard occupies most of the '
              'available vertical space below it. The body shrinks and scrolls.',
          confirmLabel: 'Confirm',
          cancelLabel: 'Cancel',
          textScaleFactor: 1.8,
          onResult: (_) {},
        ),
      );

      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
    });
  });
}
