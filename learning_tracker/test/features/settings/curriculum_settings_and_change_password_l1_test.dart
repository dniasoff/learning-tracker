// L1 widget tests — CurriculumSettingsScreen (error branch) +
//                   ChangePasswordDialog (0% → full coverage)
//
// WHY THIS FILE EXISTS:
//   The pre-existing curriculum_settings_screen_l1_test.dart covers loading,
//   data and structural branches.  This file covers the one MISSING branch
//   (error state) and provides full first-coverage of change_password_dialog.
//
// Coverage targets:
//
//  A. CurriculumSettingsScreen — error branch (uncovered in existing test)
//     A1. Error state: school icon present in error tile
//     A2. Error state: subtitle shows the fixed localized fallback, never
//         the raw exception (AUD-settings-07, EH-5/ST-4)
//     A3. Error state: "Program" title visible in error tile
//     A4. Error state: he-locale renders only ARB-sourced Hebrew text,
//         never the raw exception (AUD-settings-07)
//
//  B. ChangePasswordDialog — structure
//     B1. Dialog title is "Change Password" (l10n changePasswordDialogTitle)
//     B2. "New Password" field is present (obscured)
//     B3. "Confirm New Password" field is present (obscured)
//     B4. Cancel button is present
//     B5. "Change Password" submit button is present
//     B6. No error banner shown on initial render
//
//  C. ChangePasswordDialog — validation (min-length)
//     C1. Empty new-password → validator fires, dialog stays open
//     C2. Password < 6 chars → "at least 6 characters" error shown
//     C3. Valid password (≥6 chars) but mismatched confirm → mismatch error
//     C4. Mismatch error text: "Passwords do not match"
//
//  D. ChangePasswordDialog — submit path
//     D1. Matching valid passwords → changePassword called with the new password
//     D2. Successful changePassword → dialog closes (returns true)
//     D3. changePassword throws → error banner "Failed to change password" shown
//     D4. changePassword throws → dialog stays open (not popped)
//     D5. During loading, Cancel button is disabled
//     D6. During loading, submit button shows CircularProgressIndicator
//
//  E. ChangePasswordDialog — he-locale smoke
//     E1. Renders under Hebrew locale without crash
//     E2. Dialog title shows Hebrew translation "שנה סיסמה"
//     E3. Cancel button shows Hebrew "ביטול"

@Tags(['l1', 'settings', 'change_password'])
library;

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_profile_program_repository.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/settings/presentation/screens/curriculum_settings_screen.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/change_password_dialog.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/firestore_fake.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockAccountManagementService extends Mock
    implements AccountManagementService {}

/// A throwing stub for LearningProgramRepository.
///
/// [LearningProgramRepository] has a private constructor so we cannot
/// subclass or directly instantiate it, but we CAN create a mock that
/// satisfies its interface.  When overrideWithValue(throwingLPR) is used,
/// `_currentProgramProvider` calls getProgramById on this instance and it
/// throws, driving the error branch.
class _ThrowingLearningProgramRepository extends Mock
    implements LearningProgramRepository {
  @override
  LearningProgramData? getProgramById(int id) {
    throw Exception('test-forced LPR error');
  }
}

// ── Notifier stubs ─────────────────────────────────────────────────────────────

class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

class _HebrewTermsOn extends UseHebrewTerms {
  @override
  bool build() => true;
}

// ── Constants ──────────────────────────────────────────────────────────────────

const _curriculumKey = 'mishnayos';
const _profileUid = 'curriculum-settings-error-test-uid';
const _profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY7';

// ── Widget builders ────────────────────────────────────────────────────────────

/// Builds a [CurriculumSettingsScreen] app for testing.
///
/// Pass a [lprOverride] to substitute the [learningProgramRepositoryProvider]
/// — typically a [_ThrowingLearningProgramRepository] for the error-branch
/// tests.  The caller is responsible for seeding a profile_program row in
/// [db] so that the provider reaches the `getProgramById` call.
Widget _buildCurriculumApp({
  required FirestoreProfileProgramRepository profileProgramRepository,
  LearningProgramRepository? lprOverride,
  bool useHebrew = false,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      firestoreProfileProgramRepositoryProvider.overrideWith(
        (ref) async => profileProgramRepository,
      ),
      if (lprOverride != null)
        learningProgramRepositoryProvider.overrideWithValue(lprOverride),
      if (useHebrew)
        useHebrewTermsProvider.overrideWith(() => _HebrewTermsOn())
      else
        useHebrewTermsProvider.overrideWith(() => _HebrewTermsOff()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CurriculumSettingsScreen(curriculumId: _curriculumKey),
    ),
  );
}

/// Builds a bare [MaterialApp] that shows the change-password dialog via a
/// button tap. The dialog is shown with [showChangePasswordDialog].
///
/// The button key is [Key('show_dialog')] so tester can tap it.
Widget _buildDialogApp({
  required AccountManagementService service,
  Locale locale = const Locale('en'),
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
            key: const Key('show_dialog'),
            onPressed: () =>
                showChangePasswordDialog(context: context, service: service),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

// ── Helpers ────────────────────────────────────────────────────────────────────

Future<void> _pumpAndSettle1s(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// Opens the change-password dialog by tapping the scaffold button.
Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('show_dialog')));
  await tester.pump();
}

// ── Main ───────────────────────────────────────────────────────────────────────

void main() {
  // ════════════════════════════════════════════════════════════════════════════
  // A. CurriculumSettingsScreen — error branch
  // ════════════════════════════════════════════════════════════════════════════

  group('CurriculumSettingsScreen — error branch', () {
    // Strategy: seed a real Firestore profile_program document so the provider
    // reaches getProgramById, then override the catalog repository with a stub
    // that throws. This drives the .error(...) branch of programInfo.when().
    late FakeFirebaseFirestore firestore;
    late FirestoreProfileProgramRepository profileProgramRepository;
    late _ThrowingLearningProgramRepository throwingLpr;

    setUp(() async {
      firestore = createFakeFirestore(authenticatedUid: _profileUid);
      profileProgramRepository = FirestoreProfileProgramRepository(
        firestore: firestore,
        uid: _profileUid,
        profileId: _profileId,
      );
      await profileProgramRepository.setProgram(
        curriculumId: CurriculumId.mishnayos,
        programId: 999,
      );
      throwingLpr = _ThrowingLearningProgramRepository();
    });

    testWidgets('A1: school icon present in error tile', (tester) async {
      await _pumpAndSettle1s(
        tester,
        _buildCurriculumApp(
          profileProgramRepository: profileProgramRepository,
          lprOverride: throwingLpr,
        ),
      );

      // The error branch renders Icon(Icons.school) + title "Program".
      expect(find.byIcon(Icons.school), findsWidgets);

      await _teardown(tester);
    });

    testWidgets(
      'A2: error subtitle shows the localized friendly fallback, never the '
      'raw exception (AUD-settings-07, EH-5/ST-4)',
      (tester) async {
        await _pumpAndSettle1s(
          tester,
          _buildCurriculumApp(
            profileProgramRepository: profileProgramRepository,
            lprOverride: throwingLpr,
          ),
        );

        // l10n: curriculumSettingsProgramError is now a fixed,
        // already-localized fallback (no {error} placeholder) — the raw
        // exception must never reach the widget tree.
        expect(
          find.text("Couldn't load the program. Please try again."),
          findsOneWidget,
        );
        expect(
          find.textContaining('test-forced LPR error'),
          findsNothing,
          reason:
              'AUD-settings-07 (EH-5): the caught exception\'s raw message '
              'must never reach the widget tree — only ARB-sourced text may '
              'render.',
        );

        await _teardown(tester);
      },
    );

    testWidgets('A3: "Program" title visible in error tile', (tester) async {
      await _pumpAndSettle1s(
        tester,
        _buildCurriculumApp(
          profileProgramRepository: profileProgramRepository,
          lprOverride: throwingLpr,
        ),
      );

      // l10n: curriculumSettingsProgramTitle → "Program"
      expect(find.text('Program'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('A4: error branch under Hebrew locale renders only ARB-sourced '
        'Hebrew text, never the raw exception (AUD-settings-07)', (
      tester,
    ) async {
      await _pumpAndSettle1s(
        tester,
        _buildCurriculumApp(
          profileProgramRepository: profileProgramRepository,
          lprOverride: throwingLpr,
          useHebrew: true,
          locale: const Locale('he'),
        ),
      );

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byIcon(Icons.school), findsWidgets);
      // l10n: curriculumSettingsProgramError (he) is a fixed fallback —
      // the raw (untranslated, English) exception text must never render.
      expect(find.text('טעינת התוכנית נכשלה. נסו שוב.'), findsOneWidget);
      expect(find.textContaining('test-forced LPR error'), findsNothing);

      await _teardown(tester);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // B. ChangePasswordDialog — structure
  // ════════════════════════════════════════════════════════════════════════════

  group('ChangePasswordDialog — structure', () {
    late _MockAccountManagementService service;

    setUp(() {
      service = _MockAccountManagementService();
    });

    testWidgets('B1: dialog title is "Change Password"', (tester) async {
      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      // changePasswordDialogTitle l10n → "Change Password"
      // Title appears in the AlertDialog title widget.
      expect(find.text('Change Password'), findsWidgets);

      await _teardown(tester);
    });

    testWidgets('B2: "New Password" field is present', (tester) async {
      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      expect(
        find.widgetWithText(TextFormField, 'New Password'),
        findsOneWidget,
      );

      await _teardown(tester);
    });

    testWidgets('B3: "Confirm New Password" field is present', (tester) async {
      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      expect(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        findsOneWidget,
      );

      await _teardown(tester);
    });

    testWidgets('B4: Cancel button is present', (tester) async {
      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      // l10n actionCancel → "Cancel"
      expect(find.text('Cancel'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('B5: submit button is present with "Change Password" label', (
      tester,
    ) async {
      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      // The dialog has TWO TextButtons: Cancel + Change Password.
      // "Change Password" appears in both the title AND the button.
      expect(find.byType(TextButton), findsNWidgets(2));

      await _teardown(tester);
    });

    testWidgets('B6: no error banner on initial render', (tester) async {
      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      // The error Text is shown only when _error != null.
      expect(
        find.text('Failed to change password. Please try again.'),
        findsNothing,
      );

      await _teardown(tester);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // C. ChangePasswordDialog — validation
  // ════════════════════════════════════════════════════════════════════════════

  group('ChangePasswordDialog — validation', () {
    late _MockAccountManagementService service;

    setUp(() {
      service = _MockAccountManagementService();
    });

    testWidgets('C1: submitting with empty password shows validation error', (
      tester,
    ) async {
      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      // Tap the Change Password submit button without filling any field.
      // Find the TextButton whose child is Text("Change Password") — it's
      // the second TextButton (Cancel is first).
      final submitBtn = find.byType(TextButton).last;
      await tester.tap(submitBtn);
      await tester.pump();

      // Validator fires: password must be at least 6 characters.
      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
      // changePassword must NOT have been called (form invalid).
      verifyNever(() => service.changePassword(any<String>()));

      await _teardown(tester);
    });

    testWidgets('C2: password shorter than 6 chars shows min-length error', (
      tester,
    ) async {
      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      // Enter a 5-character password.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        'abc12',
      );
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();

      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
      verifyNever(() => service.changePassword(any<String>()));

      await _teardown(tester);
    });

    testWidgets(
      'C3: valid new password but mismatched confirm triggers error',
      (tester) async {
        await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
        await _openDialog(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'New Password'),
          'password123',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm New Password'),
          'differentpassword',
        );
        await tester.tap(find.byType(TextButton).last);
        await tester.pump();

        // C4: mismatch error text check (split across C3/C4 intentionally)
        expect(find.text('Passwords do not match'), findsOneWidget);
        verifyNever(() => service.changePassword(any<String>()));

        await _teardown(tester);
      },
    );

    testWidgets('C4: "Passwords do not match" message is shown on mismatch', (
      tester,
    ) async {
      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        'goodpass1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        'goodpass2',
      );
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);

      await _teardown(tester);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // D. ChangePasswordDialog — submit path
  // ════════════════════════════════════════════════════════════════════════════

  group('ChangePasswordDialog — submit path', () {
    late _MockAccountManagementService service;

    setUp(() {
      service = _MockAccountManagementService();
    });

    testWidgets(
      'D1: valid matching passwords → changePassword called with new password',
      (tester) async {
        const newPass = 'correct123';
        // changePassword succeeds immediately.
        when(() => service.changePassword(newPass)).thenAnswer((_) async {});

        await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
        await _openDialog(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'New Password'),
          newPass,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm New Password'),
          newPass,
        );
        await tester.tap(find.byType(TextButton).last);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        verify(() => service.changePassword(newPass)).called(1);

        await _teardown(tester);
      },
    );

    testWidgets('D2: successful changePassword → dialog closes', (
      tester,
    ) async {
      const newPass = 'success99';
      when(() => service.changePassword(newPass)).thenAnswer((_) async {});

      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        newPass,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        newPass,
      );
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // After success the dialog is popped; the AlertDialog must be gone.
      expect(find.byType(Form), findsNothing);

      await _teardown(tester);
    });

    testWidgets('D3: changePassword throws → error banner is shown', (
      tester,
    ) async {
      const newPass = 'failing1';
      when(
        () => service.changePassword(newPass),
      ).thenThrow(Exception('auth/network-request-failed'));

      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        newPass,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        newPass,
      );
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Failed to change password. Please try again.'),
        findsOneWidget,
      );

      await _teardown(tester);
    });

    testWidgets('D4: changePassword throws → dialog stays open', (
      tester,
    ) async {
      const newPass = 'failopen1';
      when(() => service.changePassword(newPass)).thenThrow(Exception('fail'));

      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        newPass,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        newPass,
      );
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Dialog must remain open after failure.
      expect(find.byType(Form), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('D5: while loading, Cancel button is disabled', (tester) async {
      // Use a Completer so we can freeze the service call mid-flight.
      final completer = Completer<void>();
      const newPass = 'loading99';
      when(
        () => service.changePassword(newPass),
      ).thenAnswer((_) => completer.future);

      await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
      await _openDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'New Password'),
        newPass,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm New Password'),
        newPass,
      );

      // Tap submit — the service call is now in-flight.
      await tester.tap(find.byType(TextButton).last);
      await tester.pump();

      // While loading: Cancel onPressed is null → button is disabled.
      final cancelBtn = find.widgetWithText(TextButton, 'Cancel');
      final cancelWidget = tester.widget<TextButton>(cancelBtn);
      expect(cancelWidget.onPressed, isNull);

      // Resolve so the dialog can close cleanly.
      completer.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await _teardown(tester);
    });

    testWidgets(
      'D6: while loading, submit button shows CircularProgressIndicator',
      (tester) async {
        final completer = Completer<void>();
        const newPass = 'loading88';
        when(
          () => service.changePassword(newPass),
        ).thenAnswer((_) => completer.future);

        await _pumpAndSettle1s(tester, _buildDialogApp(service: service));
        await _openDialog(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'New Password'),
          newPass,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm New Password'),
          newPass,
        );

        await tester.tap(find.byType(TextButton).last);
        await tester.pump();

        // While loading the submit button renders CircularProgressIndicator.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Resolve so no pending timer leaks.
        completer.complete();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await _teardown(tester);
      },
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // E. ChangePasswordDialog — he-locale smoke
  // ════════════════════════════════════════════════════════════════════════════

  group('ChangePasswordDialog — he-locale smoke', () {
    late _MockAccountManagementService service;

    setUp(() {
      service = _MockAccountManagementService();
    });

    testWidgets('E1: renders under Hebrew locale without crash', (
      tester,
    ) async {
      await _pumpAndSettle1s(
        tester,
        _buildDialogApp(service: service, locale: const Locale('he')),
      );
      await _openDialog(tester);

      expect(find.byType(Form), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('E2: dialog title shows Hebrew "שנה סיסמה"', (tester) async {
      await _pumpAndSettle1s(
        tester,
        _buildDialogApp(service: service, locale: const Locale('he')),
      );
      await _openDialog(tester);

      // changePasswordDialogTitle he → "שנה סיסמה"
      expect(find.text('שנה סיסמה'), findsWidgets);

      await _teardown(tester);
    });

    testWidgets('E3: Cancel button shows Hebrew "ביטול"', (tester) async {
      await _pumpAndSettle1s(
        tester,
        _buildDialogApp(service: service, locale: const Locale('he')),
      );
      await _openDialog(tester);

      // actionCancel he → "ביטול"
      expect(find.text('ביטול'), findsOneWidget);

      await _teardown(tester);
    });
  });
}
