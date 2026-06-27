// Widget tests for SignInScreen connectivity-driven rendering.
//
// Regression coverage for the offline bug cluster:
//   • online  → cloud-blue mode card + tappable "Sign in with Google" button
//   • offline → coral local-warning card + NO Google button
//   • loading (probe in flight) → falls back to offline-until-proven-online,
//     so the cloud card / Google button never flash while the device is
//     genuinely offline.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/screens/sign_in_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

void main() {
  group('SignInScreen', () {
    setUp(debugResetLastKnownOnline);
    tearDown(debugResetLastKnownOnline);

    Widget buildTestWidget({Stream<bool>? connectivity}) {
      return ProviderScope(
        retry: (_, __) => null,
        overrides: [
          if (connectivity != null)
            connectivityStreamProvider.overrideWith((ref) => connectivity),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SignInScreen(),
        ),
      );
    }

    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(true)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byType(Scaffold), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(true)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Your Email'), findsOneWidget);
      expect(find.text('Secret Key'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('online: shows Sign In button and Google sign-in option', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(true)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('online: shows the cloud (backed-up) mode card', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(true)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('offline: hides the Google sign-in button', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(false)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(
        find.text('Sign in with Google'),
        findsNothing,
        reason: 'Google sign-in must be hidden offline',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'offline: shows the inline wifi-off hint (Fix #13 — no email typed)',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(connectivity: Stream.value(false)),
        );
        await tester.pump(const Duration(seconds: 2));

        // Fix #13: When offline and no confirmed local-born account is matched,
        // the screen now shows an inline wifi-off hint instead of the coral
        // "local account only" SignInModeCard. The cloud-blue "backed up" card
        // must still NOT appear.
        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
        expect(find.byIcon(Icons.cloud_done_rounded), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'loading (probe in flight): defaults to offline — no cloud card, '
      'no Google button (offline-until-proven-online)',
      (tester) async {
        // A never-emitting stream keeps the provider in its loading state so
        // we exercise the orElse fallback. lastKnownOnline defaults to false.
        await tester.pumpWidget(
          buildTestWidget(connectivity: const Stream<bool>.empty()),
        );
        await tester.pump(const Duration(seconds: 2));

        expect(
          find.text('Sign in with Google'),
          findsNothing,
          reason:
              'while the connectivity probe is in flight the screen must not '
              'optimistically render the online (Google) affordance',
        );
        expect(find.byIcon(Icons.cloud_done_rounded), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('shows password visibility toggle', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(connectivity: Stream.value(true)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
