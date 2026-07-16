import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/widgets/track_label_step.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  group('TrackLabelStep', () {
    // [TQ-3] pumps through the shared `pumpApp` helper (AUD-t-track_setup-02)
    // instead of hand-rolling the MaterialApp(localizationsDelegates: ...)
    // block — see test/helpers/pump_app.dart.
    Widget buildWidget({
      required String defaultLabel,
      required ValueChanged<String> onComplete,
      Locale locale = const Locale('en'),
    }) {
      return pumpApp(
        locale: locale,
        child: Scaffold(
          body: TrackLabelStep(
            defaultLabel: defaultLabel,
            onComplete: onComplete,
          ),
        ),
      );
    }

    testWidgets('pre-fills with default label', (tester) async {
      await tester.pumpWidget(
        buildWidget(defaultLabel: 'דף היומי', onComplete: (_) {}),
      );
      await tester.pumpAndSettle();

      final textField = tester.widget<TextFormField>(
        find.byType(TextFormField),
      );
      expect(textField.controller?.text, 'דף היומי');
    });

    testWidgets('calls onComplete with entered text', (tester) async {
      String? result;
      await tester.pumpWidget(
        buildWidget(defaultLabel: '', onComplete: (label) => result = label),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'My Track');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(result, 'My Track');
    });

    testWidgets('shows validation error for empty input', (tester) async {
      String? result;
      await tester.pumpWidget(
        buildWidget(defaultLabel: '', onComplete: (label) => result = label),
      );
      await tester.pumpAndSettle();

      // Clear any default and try to submit empty
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('Please enter a name'), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('accepts default without editing', (tester) async {
      String? result;
      await tester.pumpWidget(
        buildWidget(
          defaultLabel: 'משניות',
          onComplete: (label) => result = label,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(result, 'משניות');
    });

    // [AUD-t-track_setup-02] RTL smoke — this app is Hebrew-primary and this
    // step renders on a first-run, high-visibility flow, but was previously
    // only ever pumped under the implicit default (English/LTR) locale.
    testWidgets('renders under Locale(he) without overflow or errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          defaultLabel: 'דף היומי',
          onComplete: (_) {},
          locale: const Locale('he'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TrackLabelStep), findsOneWidget);
    });
  });
}
