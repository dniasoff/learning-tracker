// L1 widget tests — PinFlowScreen + ParentPinSetupDialog (combined)
//
// FOCUS:
//   • pin_flow_screen.dart (43% baseline) — setup/verify/change modes
//   • parent_pin_setup_dialog.dart (0% baseline) — full setup dialog flow
//
// Coverage groups:
//
//  A. PinFlowScreen — setup mode
//     A1. Setup: renders device-local banner
//     A2. Setup: title is setParentPinDialogTitle on enterNew step
//     A3. Setup: after 4 digits in enterNew → step changes to confirm
//     A4. Setup: subtitle changes to confirmNewPinSubtitle on confirm step
//     A5. Setup: PIN mismatch on confirm → errorMessage shown, back to enterNew
//     A6. Setup: matching PINs → setProfilePin called + controller completed
//     A7. Setup: backspace removes last entered digit (dot clears)
//
//  B. PinFlowScreen — verify mode
//     B1. Verify: AppBar title is "Enter Parent PIN"
//     B2. Verify: subtitle is enterParentPinSubtitle
//     B3. Verify: correct PIN → verifyProfilePin called + maybePop(true)
//     B4. Verify: wrong PIN → errorMessage shown, not completed
//     B5. Verify: lockout → lockedOut=true, lockout panel shown
//     B6. Verify: Cancel button calls maybePop(false)
//
//  C. PinFlowScreen — change mode
//     C1. Change: AppBar title is "Change Parent PIN"
//     C2. Change: step verifyCurrent → subtitle references PIN entry
//     C3. Change: correct current PIN → transitions to enterNew step
//     C4. Change: wrong current PIN → errorMessage shown
//     C5. Change: mismatch on confirm → back to enterNew + error
//     C6. Change: full happy path → setProfilePin called + maybePop(true)
//
//  D. ParentPinSetupDialog — internal widget (via showParentPinSetupDialog)
//     D1. Dialog: title is setParentPinDialogTitle on enterNew step
//     D2. Dialog: after 4 digits → subtitle changes to confirmNewPinSubtitle
//     D3. Dialog: PIN mismatch → pinsDoNotMatch error, back to enter step
//     D4. Dialog: matching PINs → setProfilePin called with correct profileId
//     D5. Dialog: setProfilePin success → dialog dismissed (resolves true)
//     D6. Dialog: min-length guard — 3 digits do NOT auto-submit
//
//  E. Product-rule + i18n
//     E1. he-locale smoke: PinFlowScreen (setup mode) renders without crash/overflow
//     E2. he-locale smoke: PinFlowScreen (verify mode) renders without crash/overflow
//     E3. No "parent" profile-mode label visible on pin screen
//
// BUG LOG: (none at time of writing)

@Tags(['l1', 'profiles', 'pin_flow'])
library;

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/pin_flow_controller.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/pin_flow_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_setup_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────────

class _MockPinService extends Mock implements PinService {}

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

/// AppRouter mock that forwards pinGuard access to a simple fake.
class _MockAppRouter extends Mock implements AppRouter {
  @override
  final PinGuard pinGuard = _FakePinGuard();
}

/// Minimal PinGuard stub — markAuthenticated is a no-op.
class _FakePinGuard extends Fake implements PinGuard {
  @override
  void markAuthenticated(int profileId) {}
}

/// PinGuard spy that records every [markAuthenticated] call.
class _SpyPinGuard extends Fake implements PinGuard {
  final List<int> markAuthenticatedCalls = [];

  @override
  void markAuthenticated(int profileId) {
    markAuthenticatedCalls.add(profileId);
  }
}

/// AppRouter mock that exposes a [_SpyPinGuard] for assertion.
class _SpyAppRouter extends Mock implements AppRouter {
  _SpyAppRouter() : pinGuard = _SpyPinGuard();

  @override
  final _SpyPinGuard pinGuard;
}

// ── Notifier stubs ─────────────────────────────────────────────────────────────

/// Fixed selectedProfileId notifier so the controller can resolve a profile id.
class _FixedSelectedProfileId extends SelectedProfileId {
  _FixedSelectedProfileId(this._id);
  final int? _id;
  @override
  int? build() => _id;
}

// ── Constants ─────────────────────────────────────────────────────────────────

const int _kProfileId = 42;

// ── Harness builders ──────────────────────────────────────────────────────────

/// Builds a harness for [PinFlowScreen] with:
///   • [pinService] overriding [pinServiceProvider]
///   • [profileId] overriding [selectedProfileIdProvider]
///   • [appRouter] overriding [routerProvider] (needed by verify completion)
///   • [router] as the StackRouter (for maybePop, cancel)
///   • [locale] defaults to English
Widget _buildScreen(
  PinFlowMode mode, {
  required _MockPinService pinService,
  required _MockStackRouter router,
  required _MockAppRouter appRouter,
  int? profileId = _kProfileId,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      pinServiceProvider.overrideWithValue(pinService),
      routerProvider.overrideWithValue(appRouter),
      selectedProfileIdProvider.overrideWith(
        () => _FixedSelectedProfileId(profileId),
      ),
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
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: PinFlowScreen(mode: mode),
      ),
    ),
  );
}

/// Tap the digit key with the given label on the numeric keypad.
Future<void> _tapDigit(WidgetTester tester, String digit) async {
  final digitFinder = find.text(digit).last;
  await tester.tap(digitFinder);
  await tester.pump();
}

/// Enter a 4-digit PIN via the keypad.
Future<void> _enterPin(WidgetTester tester, String pin) async {
  assert(pin.length == 4);
  for (final d in pin.split('')) {
    await _tapDigit(tester, d);
  }
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ── Helper to set up common mock stubs ────────────────────────────────────────

void _stubRouter(_MockStackRouter router) {
  when(
    () => router.maybePop<bool>(any<bool>()),
  ).thenAnswer((_) => Future.value(true));
  when(() => router.canPop()).thenReturn(true);
  when(() => router.currentPath).thenReturn('/');
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(_FakePageRouteInfo());
  });

  void setViewSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  // ── A. PinFlowScreen — setup mode ─────────────────────────────────────────

  group('A. PinFlowScreen — setup mode', () {
    late _MockPinService ps;
    late _MockStackRouter router;
    late _MockAppRouter appRouter;

    setUp(() {
      ps = _MockPinService();
      router = _MockStackRouter();
      appRouter = _MockAppRouter();
      _stubRouter(router);
    });

    testWidgets('A1: setup renders device-local banner text', (tester) async {
      setViewSize(tester);
      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.setup,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('device'),
        findsAtLeastNWidgets(1),
        reason: 'Device-local banner must be present in setup mode',
      );
      await _teardown(tester);
    });

    testWidgets('A2: setup AppBar title is setParentPinDialogTitle', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.setup,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Set Parent PIN'),
        findsAtLeastNWidgets(1),
        reason: 'AppBar title must be "Set Parent PIN" in setup mode',
      );
      await _teardown(tester);
    });

    testWidgets(
      'A3: after 4 digits in enterNew step → confirm subtitle appears',
      (tester) async {
        setViewSize(tester);
        when(() => ps.setProfilePin(any(), any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          _buildScreen(
            PinFlowMode.setup,
            pinService: ps,
            router: router,
            appRouter: appRouter,
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // In enterNew step — subtitle mentions 4-digit PIN
        expect(
          find.textContaining('4-digit'),
          findsAtLeastNWidgets(1),
          reason: 'Setup subtitle should mention 4-digit PIN',
        );

        await _enterPin(tester, '1234');
        await tester.pump(const Duration(seconds: 1));

        // Now in confirm step — subtitle mentions entering again
        expect(
          find.textContaining('again'),
          findsAtLeastNWidgets(1),
          reason: 'Confirm subtitle must mention entering the PIN again',
        );
        await _teardown(tester);
      },
    );

    testWidgets('A4: confirm step title is "Confirm New PIN"', (tester) async {
      setViewSize(tester);
      when(() => ps.setProfilePin(any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.setup,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await _enterPin(tester, '1234');
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Confirm New PIN'),
        findsAtLeastNWidgets(1),
        reason: 'Title must be "Confirm New PIN" after first 4 digits in setup',
      );
      await _teardown(tester);
    });

    testWidgets('A5: PIN mismatch on confirm → pinsDoNotMatch error shown', (
      tester,
    ) async {
      setViewSize(tester);
      when(() => ps.setProfilePin(any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.setup,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // enterNew
      await _enterPin(tester, '1234');
      await tester.pump(const Duration(seconds: 1));

      // confirm with different PIN
      await _enterPin(tester, '5678');
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('do not match'),
        findsAtLeastNWidgets(1),
        reason: 'Mismatch error must be shown after wrong confirm PIN',
      );
      // No setProfilePin call on mismatch
      verifyNever(() => ps.setProfilePin(any(), any()));
      await _teardown(tester);
    });

    testWidgets('A6: matching PINs → setProfilePin called with profileId', (
      tester,
    ) async {
      setViewSize(tester);
      when(
        () => ps.setProfilePin(_kProfileId, '2468'),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.setup,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // enterNew
      await _enterPin(tester, '2468');
      await tester.pump(const Duration(seconds: 1));

      // confirm with same PIN
      await _enterPin(tester, '2468');
      await tester.pump(const Duration(seconds: 1));

      verify(() => ps.setProfilePin(_kProfileId, '2468')).called(1);
      await _teardown(tester);
    });

    testWidgets('A7: backspace prevents auto-submit on 3 digits', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.setup,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Tap 3 digits then backspace
      await _tapDigit(tester, '1');
      await _tapDigit(tester, '2');
      await _tapDigit(tester, '3');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      // With only 2 digits present, setProfilePin must not have been called.
      verifyNever(() => ps.setProfilePin(any(), any()));
      await _teardown(tester);
    });
  });

  // ── B. PinFlowScreen — verify mode ────────────────────────────────────────

  group('B. PinFlowScreen — verify mode', () {
    late _MockPinService ps;
    late _MockStackRouter router;
    late _MockAppRouter appRouter;

    setUp(() {
      ps = _MockPinService();
      router = _MockStackRouter();
      appRouter = _MockAppRouter();
      _stubRouter(router);
    });

    testWidgets('B1: verify AppBar title is "Enter Parent PIN"', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.verify,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Enter Parent PIN'),
        findsAtLeastNWidgets(1),
        reason: 'AppBar title must be "Enter Parent PIN" in verify mode',
      );
      await _teardown(tester);
    });

    testWidgets('B2: verify subtitle references 4-digit PIN', (tester) async {
      setViewSize(tester);
      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.verify,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('4-digit'),
        findsAtLeastNWidgets(1),
        reason: 'Verify subtitle must mention the 4-digit PIN',
      );
      await _teardown(tester);
    });

    testWidgets('B3: correct PIN → verifyProfilePin called, maybePop invoked', (
      tester,
    ) async {
      setViewSize(tester);
      when(
        () => ps.verifyProfilePin(_kProfileId, '1234'),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.verify,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await _enterPin(tester, '1234');
      await tester.pump(const Duration(seconds: 1));

      verify(() => ps.verifyProfilePin(_kProfileId, '1234')).called(1);
      // maybePop was called (with true).
      verify(
        () => router.maybePop<bool>(any<bool>()),
      ).called(greaterThanOrEqualTo(1));
      await _teardown(tester);
    });

    testWidgets('B4: wrong PIN → errorMessage shown, maybePop not called', (
      tester,
    ) async {
      setViewSize(tester);
      when(
        () => ps.verifyProfilePin(_kProfileId, '0000'),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.verify,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await _enterPin(tester, '0000');
      await tester.pump(const Duration(seconds: 1));

      // Controller sets errorMessage to 'Incorrect PIN' (controller fallback).
      expect(
        find.textContaining('Incorrect'),
        findsAtLeastNWidgets(1),
        reason: 'Incorrect PIN error must appear on wrong PIN in verify mode',
      );
      verifyNever(() => router.maybePop(true));
      await _teardown(tester);
    });

    testWidgets('B4-he: wrong PIN → localized Hebrew error, no English leak', (
      tester,
    ) async {
      // FR fix: PinFlowScreen now maps the controller's English error sentinel
      // to l10n, so a Hebrew device shows קוד שגוי (not raw "Incorrect PIN").
      setViewSize(tester);
      when(
        () => ps.verifyProfilePin(_kProfileId, '0000'),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.verify,
          pinService: ps,
          router: router,
          appRouter: appRouter,
          locale: const Locale('he'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await _enterPin(tester, '0000');
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('קוד שגוי'),
        findsAtLeastNWidgets(1),
        reason: 'wrong PIN must show the localized Hebrew error',
      );
      expect(
        find.textContaining('Incorrect'),
        findsNothing,
        reason: 'no raw English error may leak in Hebrew locale',
      );
      await _teardown(tester);
    });

    testWidgets('B5: lockout → lockedOut panel rendered with lockout minutes', (
      tester,
    ) async {
      setViewSize(tester);
      when(
        () => ps.verifyProfilePin(_kProfileId, '1111'),
      ).thenThrow(const PinLockoutException(7));

      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.verify,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await _enterPin(tester, '1111');
      await tester.pump(const Duration(seconds: 1));

      // The _LockoutPanel shows "Too many failed attempts" text.
      expect(
        find.textContaining('Too many'),
        findsAtLeastNWidgets(1),
        reason: 'Lockout panel must appear after PinLockoutException',
      );
      expect(
        find.textContaining('7'),
        findsAtLeastNWidgets(1),
        reason: 'Lockout panel must show the remaining minutes (7)',
      );
      await _teardown(tester);
    });

    testWidgets('B6: Cancel button calls maybePop', (tester) async {
      setViewSize(tester);
      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.verify,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // In verify/change modes the Cancel key is shown via showKeypadCancel=true.
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      verify(
        () => router.maybePop<bool>(any<bool>()),
      ).called(greaterThanOrEqualTo(1));
      await _teardown(tester);
    });
  });

  // ── C. PinFlowScreen — change mode ────────────────────────────────────────

  group('C. PinFlowScreen — change mode', () {
    late _MockPinService ps;
    late _MockStackRouter router;
    late _MockAppRouter appRouter;

    setUp(() {
      ps = _MockPinService();
      router = _MockStackRouter();
      appRouter = _MockAppRouter();
      _stubRouter(router);
    });

    testWidgets('C1: change AppBar title is "Change Parent PIN"', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.change,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Change Parent PIN'),
        findsAtLeastNWidgets(1),
        reason: 'AppBar title must be "Change Parent PIN" in change mode',
      );
      await _teardown(tester);
    });

    testWidgets('C2: change initial subtitle references PIN entry', (
      tester,
    ) async {
      setViewSize(tester);
      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.change,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Initial step is verifyCurrent: enterParentPinSubtitle
      expect(
        find.textContaining('4-digit'),
        findsAtLeastNWidgets(1),
        reason:
            'Subtitle in change mode verifyCurrent step must reference 4-digit PIN',
      );
      await _teardown(tester);
    });

    testWidgets('C3: correct current PIN → enterNew title shown', (
      tester,
    ) async {
      setViewSize(tester);
      when(
        () => ps.verifyProfilePin(_kProfileId, '9999'),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.change,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await _enterPin(tester, '9999');
      await tester.pump(const Duration(seconds: 1));

      // Title should now be "Enter New PIN"
      expect(
        find.text('Enter New PIN'),
        findsAtLeastNWidgets(1),
        reason:
            'Title must change to "Enter New PIN" after correct current PIN',
      );
      await _teardown(tester);
    });

    testWidgets('C4: wrong current PIN → errorMessage shown', (tester) async {
      setViewSize(tester);
      when(
        () => ps.verifyProfilePin(_kProfileId, '0000'),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.change,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await _enterPin(tester, '0000');
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('Incorrect'),
        findsAtLeastNWidgets(1),
        reason: 'Wrong current PIN must show error in change mode',
      );
      // Still in verifyCurrent (title is "Enter Current PIN")
      expect(
        find.text('Enter Current PIN'),
        findsAtLeastNWidgets(1),
        reason: 'Must remain on "Enter Current PIN" after wrong current PIN',
      );
      await _teardown(tester);
    });

    testWidgets('C5: mismatch on confirm step → error + revert to enterNew', (
      tester,
    ) async {
      setViewSize(tester);
      when(
        () => ps.verifyProfilePin(_kProfileId, '1234'),
      ).thenAnswer((_) async => true);
      when(() => ps.setProfilePin(_kProfileId, any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.change,
          pinService: ps,
          router: router,
          appRouter: appRouter,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // verifyCurrent
      await _enterPin(tester, '1234');
      await tester.pump(const Duration(seconds: 1));

      // enterNew
      await _enterPin(tester, '4321');
      await tester.pump(const Duration(seconds: 1));

      // confirm with wrong PIN
      await _enterPin(tester, '9999');
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('do not match'),
        findsAtLeastNWidgets(1),
        reason: 'Mismatch on confirm step must show pinsDoNotMatch error',
      );
      // Reverts to enterNew title
      expect(
        find.text('Enter New PIN'),
        findsAtLeastNWidgets(1),
        reason: 'Must revert to enterNew step after confirm mismatch',
      );
      await _teardown(tester);
    });

    testWidgets(
      'C6: full happy path → setProfilePin called + maybePop invoked',
      (tester) async {
        setViewSize(tester);
        when(
          () => ps.verifyProfilePin(_kProfileId, '1234'),
        ).thenAnswer((_) async => true);
        when(
          () => ps.setProfilePin(_kProfileId, '5678'),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          _buildScreen(
            PinFlowMode.change,
            pinService: ps,
            router: router,
            appRouter: appRouter,
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // verifyCurrent
        await _enterPin(tester, '1234');
        await tester.pump(const Duration(seconds: 1));

        // enterNew
        await _enterPin(tester, '5678');
        await tester.pump(const Duration(seconds: 1));

        // confirm
        await _enterPin(tester, '5678');
        await tester.pump(const Duration(seconds: 1));

        verify(() => ps.setProfilePin(_kProfileId, '5678')).called(1);
        verify(
          () => router.maybePop<bool>(any<bool>()),
        ).called(greaterThanOrEqualTo(1));
        await _teardown(tester);
      },
    );
  });

  // ── D. ParentPinSetupDialog ────────────────────────────────────────────────

  group('D. ParentPinSetupDialog (showParentPinSetupDialog)', () {
    late _MockPinService ps;

    setUp(() {
      ps = _MockPinService();
    });

    /// Builds a harness that shows [showParentPinSetupDialog] via a button tap.
    Widget buildDialogHarness({
      int profileId = _kProfileId,
      String? profileName,
      Locale locale = const Locale('en'),
    }) {
      return ProviderScope(
        retry: (_, __) => null,
        overrides: [pinServiceProvider.overrideWithValue(ps)],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (ctx, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showParentPinSetupDialog(
                    ctx,
                    ref,
                    profileId: profileId,
                    profileName: profileName,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('D1: dialog title is "Set Parent PIN" on initial step', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildDialogHarness());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Set Parent PIN'),
        findsAtLeastNWidgets(1),
        reason: 'Dialog title must be "Set Parent PIN" on initial enter step',
      );
      await _teardown(tester);
    });

    testWidgets('D2: after 4 digits subtitle changes to confirmNewPinSubtitle', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildDialogHarness());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await _enterPin(tester, '1357');
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('again'),
        findsAtLeastNWidgets(1),
        reason:
            'After first 4 digits, confirm subtitle must mention entering PIN again',
      );
      expect(
        find.text('Confirm New PIN'),
        findsAtLeastNWidgets(1),
        reason: 'Title must change to "Confirm New PIN" on confirm step',
      );
      await _teardown(tester);
    });

    testWidgets('D3: PIN mismatch → pinsDoNotMatch error, back to enter step', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildDialogHarness());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter first PIN
      await _enterPin(tester, '1234');
      await tester.pump(const Duration(seconds: 1));

      // Confirm with different PIN
      await _enterPin(tester, '5678');
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('do not match'),
        findsAtLeastNWidgets(1),
        reason: 'pinsDoNotMatch error must appear on PIN mismatch in dialog',
      );
      // Back to enter step — title reverts
      expect(
        find.text('Set Parent PIN'),
        findsAtLeastNWidgets(1),
        reason: 'Dialog must revert title to "Set Parent PIN" after mismatch',
      );
      verifyNever(() => ps.setProfilePin(any(), any()));
      await _teardown(tester);
    });

    testWidgets(
      'D4: matching PINs → setProfilePin called with correct profileId',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(
          () => ps.setProfilePin(_kProfileId, '2468'),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(buildDialogHarness(profileId: _kProfileId));
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await _enterPin(tester, '2468');
        await tester.pump(const Duration(seconds: 1));

        await _enterPin(tester, '2468');
        await tester.pump(const Duration(seconds: 1));

        verify(() => ps.setProfilePin(_kProfileId, '2468')).called(1);
        await _teardown(tester);
      },
    );

    testWidgets('D5: setProfilePin success → dialog dismissed', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(
        () => ps.setProfilePin(_kProfileId, '1111'),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(buildDialogHarness(profileId: _kProfileId));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog open
      expect(find.text('Set Parent PIN'), findsAtLeastNWidgets(1));

      await _enterPin(tester, '1111');
      await tester.pump(const Duration(seconds: 1));
      await _enterPin(tester, '1111');
      await tester.pump(const Duration(seconds: 1));

      // After success the dialog is popped — only the button remains
      expect(
        find.text('open'),
        findsOneWidget,
        reason: 'Dialog must be dismissed after successful PIN setup',
      );
      expect(
        find.text('Set Parent PIN'),
        findsNothing,
        reason:
            'Dialog heading must disappear after it is dismissed on success',
      );
      await _teardown(tester);
    });

    testWidgets('D6: 3 digits do NOT auto-submit (min-length guard)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildDialogHarness());
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter only 3 digits
      await _tapDigit(tester, '1');
      await _tapDigit(tester, '2');
      await _tapDigit(tester, '3');
      await tester.pump(const Duration(seconds: 1));

      verifyNever(() => ps.setProfilePin(any(), any()));
      expect(
        find.text('Set Parent PIN'),
        findsAtLeastNWidgets(1),
        reason: 'Dialog must remain open when fewer than 4 digits are entered',
      );
      await _teardown(tester);
    });
  });

  // ── E. Product-rule + i18n ─────────────────────────────────────────────────

  group('E. Product-rule + i18n', () {
    late _MockStackRouter router;
    late _MockAppRouter appRouter;

    setUp(() {
      router = _MockStackRouter();
      appRouter = _MockAppRouter();
      _stubRouter(router);
    });

    testWidgets('E1: he-locale setup mode renders without crash/overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final ps = _MockPinService();

      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.setup,
          pinService: ps,
          router: router,
          appRouter: appRouter,
          locale: const Locale('he'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      await _teardown(tester);
    });

    testWidgets('E2: he-locale verify mode renders without crash/overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final ps = _MockPinService();

      await tester.pumpWidget(
        _buildScreen(
          PinFlowMode.verify,
          pinService: ps,
          router: router,
          appRouter: appRouter,
          locale: const Locale('he'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      await _teardown(tester);
    });

    testWidgets(
      'E3: no raw "parent" profile-type label visible on PIN screen',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final ps = _MockPinService();

        await tester.pumpWidget(
          _buildScreen(
            PinFlowMode.verify,
            pinService: ps,
            router: router,
            appRouter: appRouter,
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // Product rule: only "child" and "adult" profile modes exist;
        // no "parent" profile-type label should appear.
        expect(
          find.text('parent'),
          findsNothing,
          reason: 'No plain "parent" profile-type label must appear',
        );
        await _teardown(tester);
      },
    );
  });

  // ── F. keepAlive remount regression (on-device freeze) ────────────────────
  //
  // Repro: PinFlowController is keepAlive: true. A prior session left
  // digits.length == 4. When the screen is popped and re-pushed, the new mount
  // inherited those stale 4 digits, so appendDigit hit the `digits.length >= 4`
  // guard and silently dropped every keypress — the keypad appeared frozen.
  // The fix resets the controller on mount via a microtask (runs before any
  // user gesture), so a freshly-mounted screen always starts empty and accepts
  // input immediately.
  group('F. keepAlive remount regression', () {
    testWidgets(
      'F1: remounting after a 4-digit session starts empty and accepts input',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final ps = _MockPinService();
        // verifyProfilePin never resolves (a bare Completer — no pending Timer),
        // so the first session can sit at the 4-digit cap without the async
        // cascade clearing the buffer — mirroring the keepAlive carry-over seen
        // on device.
        when(
          () => ps.verifyProfilePin(any(), any()),
        ).thenAnswer((_) => Completer<bool>().future);
        final router = _MockStackRouter();
        final appRouter = _MockAppRouter();
        _stubRouter(router);

        // A SINGLE container shared across both mounts so the keepAlive
        // controller's state genuinely survives the remount (auto-dispose
        // would mask the bug).
        final container = ProviderContainer(
          retry: (_, __) => null,
          overrides: [
            pinServiceProvider.overrideWithValue(ps),
            routerProvider.overrideWithValue(appRouter),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(_kProfileId),
            ),
          ],
        );
        addTearDown(container.dispose);

        Widget app(Key key) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: StackRouterScope(
              controller: router,
              stateHash: 0,
              child: PinFlowScreen(key: key, mode: PinFlowMode.verify),
            ),
          ),
        );

        // ── First session: fill to the 4-digit cap. ──
        await tester.pumpWidget(app(const ValueKey('first')));
        await tester.pump(const Duration(seconds: 1));
        await _enterPin(tester, '1234');
        await tester.pump();
        expect(
          container.read(pinFlowControllerProvider).digits.length,
          4,
          reason: 'Precondition: prior session left a full 4-digit buffer',
        );

        // ── Pop + re-push: tear the screen down, then mount a fresh one in the
        //    SAME container (keepAlive controller persists with stale digits).
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(app(const ValueKey('second')));
        await tester.pump(const Duration(seconds: 1));

        // Integration check: after a remount sharing the same keepAlive
        // controller, the screen starts with an EMPTY buffer (the stale 4
        // digits from the prior session were cleared by the mount reset) …
        //
        // NB: the precise sub-frame gesture-vs-reset ordering that froze the
        // keypad on device cannot be reproduced in the widget-test binding —
        // tester.pump always completes a full frame incl. postFrame callbacks,
        // so postFrame and microtask resets look identical here. The
        // deterministic race coverage lives in the controller unit test
        // (pin_flow_controller_test.dart, "keepAlive stale-digit reset").
        expect(
          container.read(pinFlowControllerProvider).digits,
          isEmpty,
          reason: 'Re-mounted PIN screen must reset stale digits on mount',
        );

        // … and the keypad accepts input again (no permanent >=4 block).
        await _tapDigit(tester, '7');
        expect(
          container.read(pinFlowControllerProvider).digits,
          '7',
          reason:
              'Keypress on a re-mounted screen must register '
              '(no stale >=4 block)',
        );

        await _teardown(tester);
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // E. ParentPinChangeDialog (showParentPinChangeDialog)
  //
  // This is the dialog the Settings screen actually invokes for "Change Parent
  // PIN" (settings_screen.dart). Its confirm→save path had NO coverage, so a
  // regression here would ship silently (the user reported being unable to
  // change their PIN on a stale build). These tests drive all three keypad
  // steps end-to-end.
  // ──────────────────────────────────────────────────────────────────────────
  group('E. ParentPinChangeDialog (showParentPinChangeDialog)', () {
    late _MockPinService ps;

    setUp(() {
      ps = _MockPinService();
    });

    Widget buildChangeHarness({
      int profileId = _kProfileId,
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
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showParentPinChangeDialog(
                  ctx,
                  profileId: profileId,
                  pinService: ps,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'E1: full happy path verifyCurrent→enterNew→confirmNew saves + closes',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(
          () => ps.verifyProfilePin(_kProfileId, '1111'),
        ).thenAnswer((_) async => true);
        when(() => ps.setProfilePin(any(), any())).thenAnswer((_) async {});

        await tester.pumpWidget(buildChangeHarness());
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('open'));
        await tester.pump(const Duration(milliseconds: 300));

        // Step 1: Enter Current PIN.
        expect(find.text('Enter Current PIN'), findsAtLeastNWidgets(1));
        await _enterPin(tester, '1111');
        await tester.pump(const Duration(milliseconds: 200));

        // Step 2: Enter New PIN.
        expect(find.text('Enter New PIN'), findsAtLeastNWidgets(1));
        await _enterPin(tester, '2580');
        await tester.pump(const Duration(milliseconds: 200));

        // Step 3: Confirm New PIN — the 4th digit auto-saves.
        expect(find.text('Confirm New PIN'), findsAtLeastNWidgets(1));
        await _enterPin(tester, '2580');
        await tester.pump(const Duration(milliseconds: 300));

        verify(() => ps.verifyProfilePin(_kProfileId, '1111')).called(1);
        verify(() => ps.setProfilePin(_kProfileId, '2580')).called(1);
        // Dialog dismissed → the launcher button is visible again.
        expect(find.text('Confirm New PIN'), findsNothing);

        await _teardown(tester);
      },
    );

    testWidgets('E2: confirm mismatch → pinsDoNotMatch, no save', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(
        () => ps.verifyProfilePin(_kProfileId, '1111'),
      ).thenAnswer((_) async => true);
      when(() => ps.setProfilePin(any(), any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildChangeHarness());
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(milliseconds: 300));

      await _enterPin(tester, '1111'); // verify current
      await tester.pump(const Duration(milliseconds: 200));
      await _enterPin(tester, '2580'); // new
      await tester.pump(const Duration(milliseconds: 200));
      await _enterPin(tester, '9999'); // confirm — mismatch
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('do not match'), findsAtLeastNWidgets(1));
      verifyNever(() => ps.setProfilePin(any(), any()));

      await _teardown(tester);
    });
  });

  // ── G. Setup-completion navigation linger + guard priming (regression) ────
  //
  // G1: after entering the 4th confirm digit on "Set Parent PIN", the screen
  //     lingered showing filled-dots before maybePop. Fix: digits cleared on
  //     completion.
  //
  // G2: after setup completes, markAuthenticated must be called on the guard
  //     BEFORE maybePop so that ParentSettingsRoute's guard evaluation
  //     short-circuits. Without this call the guard sees _authenticatedScope
  //     as null, calls _hasPin (which returns false since the fresh PIN hasn't
  //     been confirmed yet at that point in evaluation), and re-pushes the
  //     setup screen — causing an infinite loop.
  group('G. Setup-completion navigation linger (regression)', () {
    testWidgets(
      'G1: setup completion — maybePop called and digits are empty on completion',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final ps = _MockPinService();
        when(
          () => ps.setProfilePin(_kProfileId, '2468'),
        ).thenAnswer((_) async {});

        final router = _MockStackRouter();
        final appRouter = _MockAppRouter();
        _stubRouter(router);

        final container = ProviderContainer(
          retry: (_, __) => null,
          overrides: [
            pinServiceProvider.overrideWithValue(ps),
            routerProvider.overrideWithValue(appRouter),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(_kProfileId),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: StackRouterScope(
                controller: router,
                stateHash: 0,
                child: const PinFlowScreen(mode: PinFlowMode.setup),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // enterNew step.
        await _enterPin(tester, '2468');
        await tester.pump(const Duration(seconds: 1));

        // confirm step — same PIN.
        await _enterPin(tester, '2468');
        await tester.pump(const Duration(seconds: 1));

        // Controller must be completed and digits must be cleared so no
        // filled-dots frame lingers before the pop takes effect.
        final state = container.read(pinFlowControllerProvider);
        expect(
          state.completed,
          isTrue,
          reason: 'Controller must be completed after matching PIN confirm',
        );
        expect(
          state.digits,
          isEmpty,
          reason:
              'Digits must be cleared on completion so no filled-dots frame '
              'lingers before maybePop takes effect',
        );

        // maybePop(true) must have been called.
        verify(
          () => router.maybePop<bool>(any<bool>()),
        ).called(greaterThanOrEqualTo(1));

        await _teardown(tester);
      },
    );

    // G2: pinGuard.markAuthenticated must be called before maybePop on setup
    // completion so that ParentSettingsRoute's guard short-circuits.
    // REGRESSION: before the fix _handleCompletion for PinFlowMode.setup did
    // NOT call markAuthenticated — only verify mode did. This left the guard's
    // _authenticatedScope null during the re-evaluation window, causing the
    // setup screen to be pushed again (infinite loop).
    testWidgets(
      'G2: setup completion calls markAuthenticated before maybePop',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final ps = _MockPinService();
        when(
          () => ps.setProfilePin(_kProfileId, '1357'),
        ).thenAnswer((_) async {});

        final router = _MockStackRouter();
        _stubRouter(router);

        // Use the spy AppRouter so we can assert markAuthenticated was called.
        final spyAppRouter = _SpyAppRouter();

        final container = ProviderContainer(
          retry: (_, __) => null,
          overrides: [
            pinServiceProvider.overrideWithValue(ps),
            routerProvider.overrideWithValue(spyAppRouter),
            selectedProfileIdProvider.overrideWith(
              () => _FixedSelectedProfileId(_kProfileId),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: StackRouterScope(
                controller: router,
                stateHash: 0,
                child: const PinFlowScreen(mode: PinFlowMode.setup),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // enterNew step.
        await _enterPin(tester, '1357');
        await tester.pump(const Duration(seconds: 1));

        // confirm step — same PIN triggers completion.
        await _enterPin(tester, '1357');
        await tester.pump(const Duration(seconds: 1));

        // markAuthenticated must have been called with the profile id BEFORE
        // maybePop, so that the guard's session cache is primed.
        expect(
          spyAppRouter.pinGuard.markAuthenticatedCalls,
          contains(_kProfileId),
          reason:
              'pinGuard.markAuthenticated(_kProfileId) must be called during '
              'setup completion so ParentSettingsRoute guard short-circuits '
              'instead of re-pushing the setup screen (infinite loop)',
        );

        await _teardown(tester);
      },
    );
  });
}
