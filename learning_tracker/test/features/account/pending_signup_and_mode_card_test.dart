// SignInModeCard widget tests
//
// SignInModeCard — covered behaviours:
//   1. mode=cloud renders cloud icon + cloud text
//   2. mode=cloud does NOT render warning icon or cloudOffline text
//   3. mode=cloudOffline renders cloud-off icon + offline text
//   4. mode=cloudOffline does NOT render cloud-done icon
//   7. mode=unknown renders SizedBox.shrink (no visible content)
//   8. mode=cloud → mode=cloudOffline rebuild replaces cloud icon with cloud-off
//   9. Hebrew locale smoke: mode=cloud renders Hebrew l10n text without crash
//  10. Hebrew locale smoke: mode=cloudOffline renders the Hebrew offline notice
//
// BUG LOG: None.

@Tags(['account', 'sign_in_mode_card'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/presentation/widgets/sign_in_mode_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

/// Builds a [SignInModeCard] wrapped in a minimal ProviderScope + MaterialApp
/// with the 4 required localisation delegates.
Widget _buildCard(SignInModeHint mode, {Locale locale = const Locale('en')}) {
  return ProviderScope(
    retry: (_, __) => null,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return Center(
              child: SignInModeCard(mode: mode, l10n: l10n),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _tearDownWidget(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ════════════════════════════════════════════════════════════════════════════
  // SignInModeCard — widget tests
  // ════════════════════════════════════════════════════════════════════════════

  group('SignInModeCard — cloud mode', () {
    // 1. cloud mode renders cloud icon + cloud text
    testWidgets('1. cloud mode shows cloud-done icon and cloud text', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard(SignInModeHint.cloud));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
      expect(
        find.textContaining('Cloud account'),
        findsWidgets,
        reason: 'Cloud mode must display the cloud account text',
      );

      await _tearDownWidget(tester);
    });

    // 2. cloud mode does NOT show warning or offline icons
    testWidgets('2. cloud mode does not render warning or cloud-off icons', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard(SignInModeHint.cloud));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byIcon(Icons.dangerous_rounded), findsNothing);

      await _tearDownWidget(tester);
    });
  });

  group('SignInModeCard — cloudOffline mode', () {
    // 3. cloudOffline shows cloud-off icon + offline text
    testWidgets('3. cloudOffline mode shows cloud-off icon and offline text', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard(SignInModeHint.cloudOffline));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(
        find.textContaining('offline'),
        findsWidgets,
        reason: 'cloudOffline mode must display the offline text',
      );

      await _tearDownWidget(tester);
    });

    // 4. cloudOffline does NOT show cloud-done icon
    testWidgets('4. cloudOffline mode does not render cloud-done icon', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard(SignInModeHint.cloudOffline));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.cloud_done_rounded), findsNothing);

      await _tearDownWidget(tester);
    });
  });

  group('SignInModeCard — unknown mode', () {
    // 7. unknown mode renders nothing visible
    testWidgets('7. unknown mode renders SizedBox.shrink with no text', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard(SignInModeHint.unknown));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // No icons from other modes
      expect(find.byIcon(Icons.cloud_done_rounded), findsNothing);
      expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byIcon(Icons.dangerous_rounded), findsNothing);

      // SizedBox.shrink is present
      expect(find.byType(SizedBox), findsWidgets);

      await _tearDownWidget(tester);
    });
  });

  group('SignInModeCard — mode transitions', () {
    // 8. rebuild with new mode: cloud → cloudOffline swaps icons
    testWidgets(
      '8. rebuilding from cloud to cloudOffline replaces cloud-done with cloud-off',
      (tester) async {
        // Start in cloud mode
        await tester.pumpWidget(_buildCard(SignInModeHint.cloud));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
        expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);

        // Transition to cloudOffline
        await tester.pumpWidget(_buildCard(SignInModeHint.cloudOffline));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
        expect(find.byIcon(Icons.cloud_done_rounded), findsNothing);

        await _tearDownWidget(tester);
      },
    );
  });

  group('SignInModeCard — Hebrew locale smoke', () {
    // 9. Hebrew + cloud mode renders Hebrew text without crash
    testWidgets(
      '9. Hebrew locale + cloud mode renders Hebrew cloud text without crash',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(SignInModeHint.cloud, locale: const Locale('he')),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
        // Hebrew cloud text contains 'ענן'
        expect(
          find.textContaining('ענן'),
          findsWidgets,
          reason: 'Hebrew cloud mode must render Hebrew l10n text',
        );

        await _tearDownWidget(tester);
      },
    );

    // 10. Hebrew + cloudOffline mode renders the Hebrew offline notice
    testWidgets(
      '10. Hebrew locale + cloudOffline mode renders the Hebrew offline notice',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(SignInModeHint.cloudOffline, locale: const Locale('he')),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
        // Hebrew cloudOffline text contains 'לא מקוון'
        expect(
          find.textContaining('לא מקוון'),
          findsOneWidget,
          reason: 'Hebrew cloudOffline mode must render the offline notice',
        );

        await _tearDownWidget(tester);
      },
    );
  });
}
