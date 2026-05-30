// Mixed tests: PendingLocalSignupStore (logic) + SignInModeCard (widget)
//
// PendingLocalSignupStore — covered behaviours:
//   A. Payload round-trip: write → read returns stored data
//   B. Payload clear: write → clear → read returns null
//   C. readPayload returns null on empty store
//   D. writePayload overwrites an existing payload
//   E. Email reservation: reserve new email → returns true
//   F. Email reservation: reserve duplicate email (case-insensitive) → false
//   G. Email reservation: case-insensitive comparison (mixed-case input)
//   H. Release email → allows re-reservation
//   I. Release unknown email is a no-op (no throw)
//   J. Multiple distinct emails reserved simultaneously
//   K. releaseEmail removes only the matching email, leaves others
//   L. tryReserveEmail strips whitespace from input
//   M. clearPayload is idempotent (clear on empty store does not throw)
//   N. PendingLocalRegistration.tryParse: null input → null
//   O. PendingLocalRegistration.tryParse: empty string → null
//   P. PendingLocalRegistration.tryParse: invalid JSON → null
//   Q. PendingLocalRegistration.tryParse: missing field (accountId) → null
//   R. PendingLocalRegistration.tryParse: all fields present → parses correctly
//   S. PendingLocalRegistration.toJson → tryParse round-trip preserves all fields
//   T. writePayload serialises displayName correctly (read back verifies it)
//
// SignInModeCard — covered behaviours:
//   1. mode=cloud renders cloud icon + cloud text
//   2. mode=cloud does NOT render warning icon or cloudOffline text
//   3. mode=cloudOffline renders cloud-off icon + offline text
//   4. mode=cloudOffline does NOT render cloud-done icon
//   5. mode=local renders warning icon + local title text
//   6. mode=local also renders the danger icon + local body text (two containers)
//   7. mode=unknown renders SizedBox.shrink (no visible content)
//   8. mode=cloud → mode=cloudOffline rebuild replaces cloud icon with cloud-off
//   9. Hebrew locale smoke: mode=cloud renders Hebrew l10n text without crash
//  10. Hebrew locale smoke: mode=local renders both Hebrew strings
//
// BUG LOG: None.

@Tags(['account', 'pending_signup', 'sign_in_mode_card'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/services/pending_local_signup.dart';
import 'package:learning_tracker/features/account/presentation/widgets/sign_in_mode_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

const _kRegA = PendingLocalRegistration(
  accountId: 'acc-a1',
  dbFileName: 'lt_a1.sqlite',
  email: 'alice@example.com',
  displayName: 'Alice Wonderland',
);

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
            return Center(child: SignInModeCard(mode: mode, l10n: l10n));
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
  // PendingLocalSignupStore — logic tests
  // ════════════════════════════════════════════════════════════════════════════

  group('PendingLocalSignupStore — payload', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    // A. write → read
    test('A. write then read returns stored registration', () async {
      await PendingLocalSignupStore.writePayload(prefs, _kRegA);
      final result = await PendingLocalSignupStore.readPayload(prefs);

      expect(result, isNotNull);
      expect(result!.accountId, _kRegA.accountId);
      expect(result.dbFileName, _kRegA.dbFileName);
      expect(result.email, _kRegA.email);
      expect(result.displayName, _kRegA.displayName);
    });

    // B. write → clear → read is null
    test('B. clear removes the payload', () async {
      await PendingLocalSignupStore.writePayload(prefs, _kRegA);
      await PendingLocalSignupStore.clearPayload(prefs);
      final result = await PendingLocalSignupStore.readPayload(prefs);

      expect(result, isNull);
    });

    // C. empty store → read is null
    test('C. readPayload on empty store returns null', () async {
      final result = await PendingLocalSignupStore.readPayload(prefs);
      expect(result, isNull);
    });

    // D. overwrite existing payload
    test('D. writePayload overwrites previous payload', () async {
      await PendingLocalSignupStore.writePayload(prefs, _kRegA);

      const regB = PendingLocalRegistration(
        accountId: 'acc-b2',
        dbFileName: 'lt_b2.sqlite',
        email: 'bob@example.com',
        displayName: 'Bob Builder',
      );
      await PendingLocalSignupStore.writePayload(prefs, regB);

      final result = await PendingLocalSignupStore.readPayload(prefs);
      expect(result!.accountId, 'acc-b2');
      expect(result.email, 'bob@example.com');
    });

    // M. clearPayload is idempotent on empty store
    test('M. clearPayload on empty store does not throw', () async {
      // No exception should be thrown.
      await PendingLocalSignupStore.clearPayload(prefs);
      final result = await PendingLocalSignupStore.readPayload(prefs);
      expect(result, isNull);
    });

    // T. displayName preserved through round-trip
    test('T. writePayload preserves displayName in stored JSON', () async {
      const reg = PendingLocalRegistration(
        accountId: 'acc-t',
        dbFileName: 'lt_t.sqlite',
        email: 'tova@example.com',
        displayName: 'Tova Ben-David',
      );
      await PendingLocalSignupStore.writePayload(prefs, reg);
      final result = await PendingLocalSignupStore.readPayload(prefs);
      expect(result!.displayName, 'Tova Ben-David');
    });
  });

  // ── Email reservation ──────────────────────────────────────────────────────

  group('PendingLocalSignupStore — email reservation', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    // E. reserve new email succeeds
    test('E. tryReserveEmail returns true for a new email', () async {
      final ok = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'eve@example.com',
      );
      expect(ok, isTrue);
    });

    // F. duplicate reservation fails (same case)
    test('F. tryReserveEmail returns false for already-reserved email', () async {
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'eve@example.com');
      final ok = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'eve@example.com',
      );
      expect(ok, isFalse);
    });

    // G. case-insensitive duplicate detection
    test('G. tryReserveEmail is case-insensitive', () async {
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'FRANK@EXAMPLE.COM');
      final ok = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'frank@example.com',
      );
      expect(ok, isFalse);
    });

    // H. release then re-reserve
    test('H. releaseEmail allows re-reservation', () async {
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'grace@example.com');
      await PendingLocalSignupStore.releaseEmail(prefs, 'grace@example.com');
      final ok = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'grace@example.com',
      );
      expect(ok, isTrue);
    });

    // I. release unknown email is a no-op
    test('I. releaseEmail for unknown email does not throw', () async {
      // Should complete without error.
      await PendingLocalSignupStore.releaseEmail(prefs, 'nobody@example.com');
    });

    // J. multiple distinct emails
    test('J. multiple distinct emails can be reserved simultaneously', () async {
      final ok1 = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'alice@x.com',
      );
      final ok2 = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'bob@x.com',
      );
      final dupA = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'alice@x.com',
      );
      expect(ok1, isTrue);
      expect(ok2, isTrue);
      expect(dupA, isFalse);
    });

    // K. release only removes the matching email, leaves others intact
    test('K. releaseEmail only removes the targeted email', () async {
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'alice@x.com');
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'bob@x.com');
      await PendingLocalSignupStore.releaseEmail(prefs, 'alice@x.com');

      // alice can be re-reserved
      final reAlice = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'alice@x.com',
      );
      expect(reAlice, isTrue);

      // bob is still reserved
      final reBob = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        'bob@x.com',
      );
      expect(reBob, isFalse);
    });

    // L. whitespace stripping in tryReserveEmail
    test('L. tryReserveEmail strips leading/trailing whitespace', () async {
      await PendingLocalSignupStore.tryReserveEmail(prefs, 'henry@x.com');
      final ok = await PendingLocalSignupStore.tryReserveEmail(
        prefs,
        '  henry@x.com  ',
      );
      expect(ok, isFalse, reason: 'Email with spaces should match trimmed version');
    });
  });

  // ── PendingLocalRegistration.tryParse ──────────────────────────────────────

  group('PendingLocalRegistration.tryParse', () {
    // N. null input
    test('N. null input returns null', () {
      expect(PendingLocalRegistration.tryParse(null), isNull);
    });

    // O. empty string
    test('O. empty string returns null', () {
      expect(PendingLocalRegistration.tryParse(''), isNull);
    });

    // P. invalid JSON
    test('P. invalid JSON returns null', () {
      expect(PendingLocalRegistration.tryParse('not-json-{{{'), isNull);
    });

    // Q. missing field: accountId
    test('Q. missing accountId field returns null', () {
      final json = jsonEncode({
        'dbFileName': 'db.sqlite',
        'email': 'a@b.com',
        'displayName': 'Alice',
      });
      expect(PendingLocalRegistration.tryParse(json), isNull);
    });

    // R. all fields present → parses correctly
    test('R. complete JSON parses into correct registration', () {
      final json = jsonEncode({
        'accountId': 'acc-xyz',
        'dbFileName': 'lt_xyz.sqlite',
        'email': 'zara@example.com',
        'displayName': 'Zara Doe',
      });

      final result = PendingLocalRegistration.tryParse(json);
      expect(result, isNotNull);
      expect(result!.accountId, 'acc-xyz');
      expect(result.dbFileName, 'lt_xyz.sqlite');
      expect(result.email, 'zara@example.com');
      expect(result.displayName, 'Zara Doe');
    });

    // S. toJson round-trip
    test('S. toJson → tryParse round-trip preserves all fields', () {
      const reg = PendingLocalRegistration(
        accountId: 'acc-round',
        dbFileName: 'lt_round.sqlite',
        email: 'roundtrip@example.com',
        displayName: 'Round Trip',
      );

      final json = jsonEncode(reg.toJson());
      final restored = PendingLocalRegistration.tryParse(json);

      expect(restored, isNotNull);
      expect(restored!.accountId, reg.accountId);
      expect(restored.dbFileName, reg.dbFileName);
      expect(restored.email, reg.email);
      expect(restored.displayName, reg.displayName);
    });
  });

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
    testWidgets(
      '2. cloud mode does not render warning or cloud-off icons',
      (tester) async {
        await tester.pumpWidget(_buildCard(SignInModeHint.cloud));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
        expect(find.byIcon(Icons.dangerous_rounded), findsNothing);

        await _tearDownWidget(tester);
      },
    );
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

  group('SignInModeCard — local mode', () {
    // 5. local mode shows warning icon + local title text
    testWidgets('5. local mode shows warning icon and local-title text', (
      tester,
    ) async {
      await tester.pumpWidget(_buildCard(SignInModeHint.local));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(
        find.textContaining('Local account'),
        findsWidgets,
        reason: 'local mode must display the local account title',
      );

      await _tearDownWidget(tester);
    });

    // 6. local mode shows danger icon + local body text (two containers)
    testWidgets(
      '6. local mode also renders danger icon and local body text',
      (tester) async {
        await tester.pumpWidget(_buildCard(SignInModeHint.local));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byIcon(Icons.dangerous_rounded), findsOneWidget);
        expect(
          find.textContaining('No cloud backup'),
          findsWidgets,
          reason: 'local mode must display the local body text',
        );

        await _tearDownWidget(tester);
      },
    );
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

    // 10. Hebrew + local mode renders both Hebrew strings
    testWidgets(
      '10. Hebrew locale + local mode renders both Hebrew local strings',
      (tester) async {
        await tester.pumpWidget(
          _buildCard(SignInModeHint.local, locale: const Locale('he')),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
        // Hebrew local title contains 'מקומי'
        expect(
          find.textContaining('מקומי'),
          findsWidgets,
          reason: 'Hebrew local mode must render local account title',
        );
        // Hebrew local body mentions device
        expect(
          find.textContaining('מכשיר'),
          findsWidgets,
          reason: 'Hebrew local mode must render local body text about device',
        );

        await _tearDownWidget(tester);
      },
    );
  });
}
