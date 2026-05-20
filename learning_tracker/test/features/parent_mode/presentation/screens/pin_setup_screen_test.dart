import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/pin_flow_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  group('PinFlowScreen (setup mode)', () {
    Widget wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

    testWidgets('renders without error', (tester) async {
      // Use a taller surface to accommodate the keypad layout.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrap(const PinFlowScreen(mode: PinFlowMode.setup)),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      // The setup screen shows the "Set Parent PIN" text.
      expect(find.text('Set Parent PIN'), findsWidgets);
    });
  });
}
