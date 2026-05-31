// Regression tests for R7 (bug-hunt-round2-findings-2026-05-31.md):
// change_password_dialog.dart and reauthenticate_dialog.dart previously leaked
// hardcoded English field labels and error messages.  These tests prove that
// the dialogs render Hebrew strings under `locale: Locale('he')`, confirming
// the localised keys are used.
//
// Assertions:
//   R7-A. ChangePasswordDialog — Hebrew locale shows:
//     R7-A1. newPasswordLabel          → 'סיסמה חדשה'
//     R7-A2. confirmNewPasswordLabel   → 'אישור סיסמה חדשה'
//     R7-A3. no hardcoded 'New Password' label
//     R7-A4. no hardcoded 'Confirm New Password' label
//   R7-B. ReauthenticateDialog — Hebrew locale shows:
//     R7-B1. currentPasswordLabel      → 'סיסמה נוכחית'
//     R7-B2. no hardcoded 'Current Password' label

@Tags(['l1', 'settings', 'l10n', 'r7'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/reauthenticate_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockAccountManagementService extends Mock
    implements AccountManagementService {}

// ── Widget builders ────────────────────────────────────────────────────────────

Widget _changePasswordApp({
  required AccountManagementService service,
  Locale locale = const Locale('he'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('open_change_pw'),
            onPressed: () =>
                showChangePasswordDialog(context: context, service: service),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

Widget _reauthApp({
  required AccountManagementService service,
  Locale locale = const Locale('he'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('open_reauth'),
            onPressed: () => showReauthenticateDialog(
              context: context,
              email: 'user@example.com',
              service: service,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pump();
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  late _MockAccountManagementService service;

  setUp(() {
    service = _MockAccountManagementService();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // R7-A. ChangePasswordDialog — Hebrew labels
  // ════════════════════════════════════════════════════════════════════════════

  group('ChangePasswordDialog — Hebrew l10n (R7-A)', () {
    testWidgets('R7-A1: newPasswordLabel shows Hebrew "סיסמה חדשה"', (
      tester,
    ) async {
      await _pump(tester, _changePasswordApp(service: service));
      await tester.tap(find.byKey(const Key('open_change_pw')));
      await tester.pump();

      expect(find.text('סיסמה חדשה'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets(
      'R7-A2: confirmNewPasswordLabel shows Hebrew "אישור סיסמה חדשה"',
      (tester) async {
        await _pump(tester, _changePasswordApp(service: service));
        await tester.tap(find.byKey(const Key('open_change_pw')));
        await tester.pump();

        expect(find.text('אישור סיסמה חדשה'), findsOneWidget);

        await _teardown(tester);
      },
    );

    testWidgets(
      'R7-A3: no hardcoded English "New Password" label in Hebrew locale',
      (tester) async {
        await _pump(tester, _changePasswordApp(service: service));
        await tester.tap(find.byKey(const Key('open_change_pw')));
        await tester.pump();

        expect(find.text('New Password'), findsNothing);

        await _teardown(tester);
      },
    );

    testWidgets(
      'R7-A4: no hardcoded English "Confirm New Password" label in Hebrew locale',
      (tester) async {
        await _pump(tester, _changePasswordApp(service: service));
        await tester.tap(find.byKey(const Key('open_change_pw')));
        await tester.pump();

        expect(find.text('Confirm New Password'), findsNothing);

        await _teardown(tester);
      },
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // R7-B. ReauthenticateDialog — Hebrew labels
  // ════════════════════════════════════════════════════════════════════════════

  group('ReauthenticateDialog — Hebrew l10n (R7-B)', () {
    testWidgets('R7-B1: currentPasswordLabel shows Hebrew "סיסמה נוכחית"', (
      tester,
    ) async {
      await _pump(tester, _reauthApp(service: service));
      await tester.tap(find.byKey(const Key('open_reauth')));
      await tester.pump();

      expect(find.text('סיסמה נוכחית'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets(
      'R7-B2: no hardcoded English "Current Password" label in Hebrew locale',
      (tester) async {
        await _pump(tester, _reauthApp(service: service));
        await tester.tap(find.byKey(const Key('open_reauth')));
        await tester.pump();

        expect(find.text('Current Password'), findsNothing);

        await _teardown(tester);
      },
    );
  });
}
