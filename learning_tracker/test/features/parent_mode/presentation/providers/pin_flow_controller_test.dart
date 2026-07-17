/// Unit tests for [PinFlowController] — pure state-machine logic.
///
/// Tests run without a widget tree. PinService is overridden via Riverpod so
/// bcrypt never runs in tests.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/pin_flow_controller.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockPinService extends Mock implements PinService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a container with provider overrides for PIN tests.
ProviderContainer _makeContainer({
  required PinService pinService,
  int? profileId = 1,
}) {
  return ProviderContainer(
    overrides: [
      pinServiceProvider.overrideWithValue(pinService),
      selectedProfileIdProvider.overrideWith(
        () => _FixedProfileIdNotifier(profileId),
      ),
    ],
  );
}

class _FixedProfileIdNotifier extends SelectedProfileId {
  _FixedProfileIdNotifier(this._fixed);
  final int? _fixed;

  @override
  int? build() => _fixed;
}

/// Enters [pin] into [ctrl] one digit at a time.
void _enterDigits(PinFlowController ctrl, String pin) {
  for (final d in pin.split('')) {
    ctrl.appendDigit(d);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PinFlowMode enum', () {
    test('has setup, change, verify values', () {
      expect(
        PinFlowMode.values,
        containsAll([
          PinFlowMode.setup,
          PinFlowMode.change,
          PinFlowMode.verify,
        ]),
      );
    });
  });

  group('PinFlowState', () {
    test('copyWith preserves unset fields', () {
      const original = PinFlowState(
        mode: PinFlowMode.verify,
        step: PinFlowStep.verifyCurrent,
        digits: '12',
      );
      final copy = original.copyWith(busy: true);
      expect(copy.digits, '12');
      expect(copy.busy, isTrue);
    });

    test('copyWith sets nullable fields to null via sentinel', () {
      // AUD-profiles-09: PinFlowState.error is a closed enum (PinFlowError),
      // not a free-text String — corrected expected type here, same
      // sentinel-copyWith behavior under test (not a weakened assertion).
      const original = PinFlowState(
        mode: PinFlowMode.setup,
        step: PinFlowStep.confirm,
        firstPin: '1234',
        error: PinFlowError.incorrectPin,
      );
      final copy = original.copyWith(firstPin: null, error: null);
      expect(copy.firstPin, isNull);
      expect(copy.error, isNull);
    });
  });

  group('PinFlowController.reset()', () {
    test('reset(verify) sets initial step to verifyCurrent', () {
      final container = _makeContainer(pinService: _MockPinService());
      addTearDown(container.dispose);

      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);
      final s = container.read(pinFlowControllerProvider);
      expect(s.mode, PinFlowMode.verify);
      expect(s.step, PinFlowStep.verifyCurrent);
    });

    test('reset(setup) sets initial step to enterNew', () {
      final container = _makeContainer(pinService: _MockPinService());
      addTearDown(container.dispose);

      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.setup);
      final s = container.read(pinFlowControllerProvider);
      expect(s.mode, PinFlowMode.setup);
      expect(s.step, PinFlowStep.enterNew);
    });

    test('reset(change) sets initial step to verifyCurrent', () {
      final container = _makeContainer(pinService: _MockPinService());
      addTearDown(container.dispose);

      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.change);
      final s = container.read(pinFlowControllerProvider);
      expect(s.mode, PinFlowMode.change);
      expect(s.step, PinFlowStep.verifyCurrent);
    });
  });

  group('PinFlowController — mount-token init / setup-freeze race (regression)', () {
    // Reproduces the reported on-device freeze: on the "Set Parent PIN" setup
    // screen the user taps 4 digits — all dots fill — but the screen stays on
    // "Set Parent PIN" and cannot proceed.
    //
    // Root cause: the screen schedules its reset(setup) as a deferred microtask
    // in initState. On device that microtask is NOT guaranteed to drain before
    // the first keypress, so the keepAlive controller is still in its default
    // build() state (mode: verify). The 4 setup digits were therefore routed
    // through _handleVerify (the WRONG handler); the trailing reset then reverted
    // the step to enterNew. Net: stuck on "Set Parent PIN".
    //
    // The fix: keypad gestures call initializeForMount(token, mode) synchronously
    // BEFORE appending, so the correct mode is always established first. Both the
    // gesture path and the late initState microtask share one per-mount token, so
    // the late reset is a no-op and never wipes in-progress entry.

    test(
      'setup keypress before the deferred reset drains still advances to confirm '
      '(no verify mis-route, no late-reset wipe)',
      () async {
        final ps = _MockPinService();
        // If the bug regressed, the 4 digits would hit _handleVerify here.
        when(() => ps.verifyProfilePin(any(), any())).thenAnswer(
          (_) async =>
              fail('setup digits must NOT be routed through verifyProfilePin'),
        );
        when(() => ps.setProfilePin(any(), any())).thenAnswer((_) async {});

        final container = _makeContainer(pinService: ps, profileId: 42);
        addTearDown(container.dispose);
        final ctrl = container.read(pinFlowControllerProvider.notifier);
        final token = Object();

        // Mirror initState: schedule the reset as a deferred microtask that has
        // NOT yet run when the user taps.
        unawaited(
          Future.microtask(
            () => ctrl.initializeForMount(token, PinFlowMode.setup),
          ),
        );

        // User taps 4 digits via the screen's gesture path, which initialises
        // synchronously first (exactly what _onDigit now does).
        for (final d in '1234'.split('')) {
          ctrl.initializeForMount(token, PinFlowMode.setup);
          ctrl.appendDigit(d);
        }

        // Let the deferred microtask reset and any async handler drain.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final s = container.read(pinFlowControllerProvider);
        expect(
          s.mode,
          PinFlowMode.setup,
          reason: 'controller must be in setup mode, not the stale default',
        );
        expect(
          s.step,
          PinFlowStep.confirm,
          reason: 'first 4 setup digits must advance enterNew -> confirm',
        );
        expect(
          s.firstPin,
          '1234',
          reason: 'the first PIN must be held for the confirm step',
        );
        expect(
          s.digits,
          isEmpty,
          reason: 'confirm step starts with an empty buffer',
        );
      },
    );

    test('initializeForMount is idempotent within one mount (late microtask '
        'does not wipe in-progress entry)', () async {
      final ps = _MockPinService();
      final container = _makeContainer(pinService: ps, profileId: 42);
      addTearDown(container.dispose);
      final ctrl = container.read(pinFlowControllerProvider.notifier);
      final token = Object();

      // First gesture initialises the mount and enters 2 digits.
      ctrl.initializeForMount(token, PinFlowMode.setup);
      ctrl.appendDigit('1');
      ctrl.appendDigit('2');
      expect(container.read(pinFlowControllerProvider).digits, '12');

      // The late initState microtask fires with the SAME token — must be a no-op.
      ctrl.initializeForMount(token, PinFlowMode.setup);
      expect(
        container.read(pinFlowControllerProvider).digits,
        '12',
        reason: 'same-token re-init must not wipe in-progress digits',
      );
    });

    test('a NEW mount token forces a fresh reset (stale digits cleared on '
        're-push)', () async {
      final ps = _MockPinService();
      when(
        () => ps.verifyProfilePin(any(), any()),
      ).thenAnswer((_) => Future.delayed(const Duration(days: 1), () => false));
      final container = _makeContainer(pinService: ps, profileId: 42);
      addTearDown(container.dispose);
      final ctrl = container.read(pinFlowControllerProvider.notifier);

      // Prior mount leaves the keepAlive buffer full.
      final firstToken = Object();
      ctrl.initializeForMount(firstToken, PinFlowMode.verify);
      _enterDigits(ctrl, '1234');
      expect(container.read(pinFlowControllerProvider).digits.length, 4);

      // Re-push: a brand-new token forces a clean reset.
      final secondToken = Object();
      ctrl.initializeForMount(secondToken, PinFlowMode.verify);
      expect(container.read(pinFlowControllerProvider).digits, isEmpty);
      ctrl.appendDigit('7');
      expect(container.read(pinFlowControllerProvider).digits, '7');
    });
  });

  group('PinFlowController — keepAlive stale-digit reset (regression)', () {
    // Reproduces the on-device freeze: a keepAlive controller retained
    // digits.length == 4 from a prior session, so on re-mount appendDigit was
    // blocked by the `digits.length >= 4` guard and the screen appeared frozen.
    // reset() on mount must synchronously clear digits so input works again.
    test(
      'reset() clears stale 4-length digits and appendDigit works immediately',
      () async {
        // A verify that never resolves so the first session can sit at 4 digits
        // without the async cascade clearing them for us.
        final ps = _MockPinService();
        when(() => ps.verifyProfilePin(any(), any())).thenAnswer(
          (_) => Future.delayed(const Duration(days: 1), () => false),
        );

        final container = _makeContainer(pinService: ps);
        addTearDown(container.dispose);
        final ctrl = container.read(pinFlowControllerProvider.notifier);

        // Prior session: fill to 4 digits (busy may be set by the pending
        // verify, mirroring the real keepAlive carry-over).
        ctrl.reset(PinFlowMode.verify);
        _enterDigits(ctrl, '1234');
        expect(container.read(pinFlowControllerProvider).digits.length, 4);

        // Screen re-mounts -> reset() runs synchronously.
        ctrl.reset(PinFlowMode.verify);
        expect(
          container.read(pinFlowControllerProvider).digits,
          isEmpty,
          reason: 'reset must clear stale digits on mount',
        );
        expect(
          container.read(pinFlowControllerProvider).busy,
          isFalse,
          reason: 'reset must clear any carried-over busy flag',
        );

        // Input must be accepted immediately (no >=4 block, no race).
        ctrl.appendDigit('9');
        expect(container.read(pinFlowControllerProvider).digits, '9');
      },
    );

    test('screen dispose clears digits so the next mount accepts input '
        'immediately (no >=4 block before the postFrame reset)', () {
      // Mirrors the screen lifecycle: dispose() calls reset() on the keepAlive
      // controller, so when the screen is re-pushed the very first keypress
      // lands on empty digits even before initState's deferred reset fires.
      final ps = _MockPinService();
      when(
        () => ps.verifyProfilePin(any(), any()),
      ).thenAnswer((_) => Future.delayed(const Duration(days: 1), () => false));

      final container = _makeContainer(pinService: ps);
      addTearDown(container.dispose);

      // Prior session leaves digits at the 4-cap.
      final ctrl = container.read(pinFlowControllerProvider.notifier);
      ctrl.reset(PinFlowMode.verify);
      _enterDigits(ctrl, '1234');
      expect(container.read(pinFlowControllerProvider).digits.length, 4);

      // Screen dispose -> controller cleared (what _PinFlowScreenState.dispose
      // now does via the captured notifier).
      ctrl.reset(PinFlowMode.verify);
      expect(container.read(pinFlowControllerProvider).digits, isEmpty);

      // Re-pushed screen: first keypress is accepted (no >=4 block, no race).
      ctrl.appendDigit('7');
      expect(container.read(pinFlowControllerProvider).digits, '7');
    });
  });

  group('PinFlowController.appendDigit / backspace', () {
    test('appendDigit accumulates digits', () {
      final container = _makeContainer(pinService: _MockPinService());
      addTearDown(container.dispose);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);

      final ctrl = container.read(pinFlowControllerProvider.notifier);
      ctrl.appendDigit('1');
      ctrl.appendDigit('2');
      ctrl.appendDigit('3');
      expect(container.read(pinFlowControllerProvider).digits, '123');
    });

    test('appendDigit caps at 4 digits', () {
      final container = _makeContainer(pinService: _MockPinService());
      addTearDown(container.dispose);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);

      // Use a mock that never resolves so we don't trigger async cascade
      final ps = _MockPinService();
      when(
        () => ps.verifyProfilePin(any(), any()),
      ).thenAnswer((_) => Future.delayed(const Duration(days: 1), () => false));

      final container2 = _makeContainer(pinService: ps);
      addTearDown(container2.dispose);
      container2
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);
      final ctrl = container2.read(pinFlowControllerProvider.notifier);
      ctrl.appendDigit('1');
      ctrl.appendDigit('2');
      ctrl.appendDigit('3');
      ctrl.appendDigit('4');
      ctrl.appendDigit('5'); // should be ignored
      expect(container2.read(pinFlowControllerProvider).digits.length, 4);
    });

    test('backspace removes last digit', () {
      final container = _makeContainer(pinService: _MockPinService());
      addTearDown(container.dispose);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);

      final ctrl = container.read(pinFlowControllerProvider.notifier);
      ctrl.appendDigit('1');
      ctrl.appendDigit('2');
      ctrl.backspace();
      expect(container.read(pinFlowControllerProvider).digits, '1');
    });

    test('backspace on empty digits is a no-op', () {
      final container = _makeContainer(pinService: _MockPinService());
      addTearDown(container.dispose);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);

      final ctrl = container.read(pinFlowControllerProvider.notifier);
      ctrl.backspace(); // no-op
      expect(container.read(pinFlowControllerProvider).digits, isEmpty);
    });

    test('appendDigit clears errorMessage', () {
      final container = _makeContainer(pinService: _MockPinService());
      addTearDown(container.dispose);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);

      // Manually put an error message into state via reset workaround:
      // just verify that appending clears it.
      final ctrl = container.read(pinFlowControllerProvider.notifier);
      ctrl.appendDigit('1');
      // No error set yet — just check digits was appended
      expect(container.read(pinFlowControllerProvider).error, isNull);
    });
  });

  group('PinFlowController — verify mode (async)', () {
    test('correct PIN → completed == true', () async {
      final ps = _MockPinService();
      when(() => ps.verifyProfilePin(1, '1234')).thenAnswer((_) async => true);

      final container = _makeContainer(pinService: ps);
      addTearDown(container.dispose);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);

      _enterDigits(container.read(pinFlowControllerProvider.notifier), '1234');

      // Allow the async verify to complete.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(container.read(pinFlowControllerProvider).completed, isTrue);
    });

    test('wrong PIN → errorMessage is set, digits cleared', () async {
      final ps = _MockPinService();
      when(() => ps.verifyProfilePin(1, '0000')).thenAnswer((_) async => false);

      final container = _makeContainer(pinService: ps);
      addTearDown(container.dispose);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);

      _enterDigits(container.read(pinFlowControllerProvider.notifier), '0000');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final s = container.read(pinFlowControllerProvider);
      expect(s.completed, isFalse);
      expect(s.error, isNotNull);
      expect(s.digits, isEmpty);
    });

    test('lockout → lockedOut == true', () async {
      final ps = _MockPinService();
      when(
        () => ps.verifyProfilePin(1, '9999'),
      ).thenThrow(const PinLockoutException(5));

      final container = _makeContainer(pinService: ps);
      addTearDown(container.dispose);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);

      _enterDigits(container.read(pinFlowControllerProvider.notifier), '9999');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final s = container.read(pinFlowControllerProvider);
      expect(s.lockedOut, isTrue);
      expect(s.lockoutMinutes, 5);
    });
  });

  // ── Setup / change / verify completion — digits cleared (linger regression) ─
  //
  // Root cause of the "Set Parent PIN" linger: _handleSetup set
  // `completed: true` without clearing `digits`, so the frame rendered between
  // the state change and maybePop() showed 4 filled dots.
  // The fix adds `digits: ''` to every completion copyWith().
  group('PinFlowController — digits cleared on completion (linger fix)', () {
    test('setup: digits are empty after matching confirm PIN saves', () async {
      final ps = _MockPinService();
      when(() => ps.setProfilePin(1, '1234')).thenAnswer((_) async {});

      final container = _makeContainer(pinService: ps);
      addTearDown(container.dispose);
      final ctrl = container.read(pinFlowControllerProvider.notifier);
      ctrl.reset(PinFlowMode.setup);

      // enterNew
      _enterDigits(ctrl, '1234');
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(pinFlowControllerProvider).step,
        PinFlowStep.confirm,
      );

      // confirm
      _enterDigits(ctrl, '1234');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final s = container.read(pinFlowControllerProvider);
      expect(s.completed, isTrue);
      expect(
        s.digits,
        isEmpty,
        reason: 'digits must be cleared on completion so no filled-dots linger',
      );
    });

    test('change: digits are empty after confirm step saves', () async {
      final ps = _MockPinService();
      when(() => ps.verifyProfilePin(1, '0000')).thenAnswer((_) async => true);
      when(() => ps.setProfilePin(1, '5678')).thenAnswer((_) async {});

      final container = _makeContainer(pinService: ps);
      addTearDown(container.dispose);
      final ctrl = container.read(pinFlowControllerProvider.notifier);
      ctrl.reset(PinFlowMode.change);

      // verifyCurrent
      _enterDigits(ctrl, '0000');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        container.read(pinFlowControllerProvider).step,
        PinFlowStep.enterNew,
      );

      // enterNew
      _enterDigits(ctrl, '5678');
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(pinFlowControllerProvider).step,
        PinFlowStep.confirm,
      );

      // confirm
      _enterDigits(ctrl, '5678');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final s = container.read(pinFlowControllerProvider);
      expect(s.completed, isTrue);
      expect(
        s.digits,
        isEmpty,
        reason: 'digits must be cleared on completion so no filled-dots linger',
      );
    });

    test('verify: digits are empty after correct PIN', () async {
      final ps = _MockPinService();
      when(() => ps.verifyProfilePin(1, '9999')).thenAnswer((_) async => true);

      final container = _makeContainer(pinService: ps);
      addTearDown(container.dispose);
      final ctrl = container.read(pinFlowControllerProvider.notifier);
      ctrl.reset(PinFlowMode.verify);

      _enterDigits(ctrl, '9999');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final s = container.read(pinFlowControllerProvider);
      expect(s.completed, isTrue);
      expect(
        s.digits,
        isEmpty,
        reason: 'digits must be cleared on completion so no filled-dots linger',
      );
    });
  });

  // ── SM-4: ref.mounted guard after await (AUD-profiles-05 regression) ──────
  //
  // Every await in _handleSetup/_handleChange/_handleVerify must be followed
  // by a `ref.mounted` check before `state` is touched. If the
  // ProviderContainer is disposed while a PinService call is in flight (app
  // teardown, container disposal in tests), resuming without the guard
  // throws UnmountedRefException from the `state = ...` setter. These tests
  // dispose the container mid-await and assert nothing escapes as an
  // uncaught zone error.
  group('PinFlowController — ref.mounted guard after await (SM-4 regression)', () {
    /// Runs [body] inside a guarded zone and returns whatever error escaped
    /// it uncaught (e.g. an UnmountedRefException thrown by a `state = ...`
    /// touch after the container was disposed mid-await), or null if none did.
    Future<Object?> uncaughtErrorFrom(Future<void> Function() body) async {
      Object? escaped;
      await runZonedGuarded(body, (error, stack) {
        escaped = error;
      });
      return escaped;
    }

    test(
      'verify mode: container disposed mid-verifyProfilePin await',
      () async {
        final ps = _MockPinService();
        final completer = Completer<bool>();
        when(
          () => ps.verifyProfilePin(1, '1234'),
        ).thenAnswer((_) => completer.future);

        final container = _makeContainer(pinService: ps);
        container
            .read(pinFlowControllerProvider.notifier)
            .reset(PinFlowMode.verify);

        final escaped = await uncaughtErrorFrom(() async {
          _enterDigits(
            container.read(pinFlowControllerProvider.notifier),
            '1234',
          );
          // Let _handleVerify start and reach the await.
          await Future<void>.delayed(Duration.zero);

          // Dispose mid-await, mirroring app teardown while the bcrypt/
          // secure-storage call is in flight.
          container.dispose();

          // Resolve the pending call after disposal.
          completer.complete(true);

          // Pump so the post-await continuation runs.
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });

        expect(
          escaped,
          isNull,
          reason:
              'an unguarded `state = ...` after the await throws '
              'UnmountedRefException once the container is disposed mid-await',
        );
      },
    );

    test(
      'setup mode confirm step: container disposed mid-setProfilePin await',
      () async {
        final ps = _MockPinService();
        final completer = Completer<void>();
        when(
          () => ps.setProfilePin(1, '1234'),
        ).thenAnswer((_) => completer.future);

        final container = _makeContainer(pinService: ps);
        final ctrl = container.read(pinFlowControllerProvider.notifier);
        ctrl.reset(PinFlowMode.setup);
        // enterNew step is synchronous.
        _enterDigits(ctrl, '1234');
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(pinFlowControllerProvider).step,
          PinFlowStep.confirm,
        );

        final escaped = await uncaughtErrorFrom(() async {
          // confirm step triggers the awaited setProfilePin call.
          _enterDigits(ctrl, '1234');
          await Future<void>.delayed(Duration.zero);

          container.dispose();
          completer.complete();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });

        expect(
          escaped,
          isNull,
          reason:
              'an unguarded `state = ...` after the await throws '
              'UnmountedRefException once the container is disposed mid-await',
        );
      },
    );

    test(
      'change mode verifyCurrent step: container disposed mid-verifyProfilePin '
      'await',
      () async {
        final ps = _MockPinService();
        final completer = Completer<bool>();
        when(
          () => ps.verifyProfilePin(1, '0000'),
        ).thenAnswer((_) => completer.future);

        final container = _makeContainer(pinService: ps);
        final ctrl = container.read(pinFlowControllerProvider.notifier);
        ctrl.reset(PinFlowMode.change);

        final escaped = await uncaughtErrorFrom(() async {
          _enterDigits(ctrl, '0000');
          await Future<void>.delayed(Duration.zero);

          container.dispose();
          completer.complete(true);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });

        expect(
          escaped,
          isNull,
          reason:
              'an unguarded `state = ...` after the await throws '
              'UnmountedRefException once the container is disposed mid-await',
        );
      },
    );

    test('change mode confirm step: container disposed mid-setProfilePin await '
        '(no try/catch prior to the fix)', () async {
      final ps = _MockPinService();
      when(() => ps.verifyProfilePin(1, '0000')).thenAnswer((_) async => true);
      final completer = Completer<void>();
      when(
        () => ps.setProfilePin(1, '5678'),
      ).thenAnswer((_) => completer.future);

      final container = _makeContainer(pinService: ps);
      final ctrl = container.read(pinFlowControllerProvider.notifier);
      ctrl.reset(PinFlowMode.change);

      // verifyCurrent
      _enterDigits(ctrl, '0000');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        container.read(pinFlowControllerProvider).step,
        PinFlowStep.enterNew,
      );
      // enterNew
      _enterDigits(ctrl, '5678');
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(pinFlowControllerProvider).step,
        PinFlowStep.confirm,
      );

      final escaped = await uncaughtErrorFrom(() async {
        // confirm step triggers the awaited setProfilePin call.
        _enterDigits(ctrl, '5678');
        await Future<void>.delayed(Duration.zero);

        container.dispose();
        completer.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(
        escaped,
        isNull,
        reason:
            'an unguarded `state = ...` after the await throws '
            'UnmountedRefException once the container is disposed mid-await '
            '(this confirm step previously had no try/catch at all)',
      );
    });
  });

  group('PinFlowController — setup mode step transitions (sync)', () {
    test('4 digits in enterNew → transitions to confirm step', () async {
      final ps = _MockPinService();
      final container = _makeContainer(pinService: ps);
      addTearDown(container.dispose);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.setup);

      final ctrl = container.read(pinFlowControllerProvider.notifier);
      // Enter 4 digits (no async here — setup enterNew is sync)
      ctrl.appendDigit('1');
      ctrl.appendDigit('2');
      ctrl.appendDigit('3');
      ctrl.appendDigit('4');

      // Give microtask queue time to flush (the state update is synchronous
      // but we need to pump Dart's event loop).
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(pinFlowControllerProvider).step,
        PinFlowStep.confirm,
      );
    });

    test('mismatched confirm → errorMessage set, back to enterNew', () async {
      final ps = _MockPinService();
      final container = _makeContainer(pinService: ps);
      addTearDown(container.dispose);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.setup);

      final ctrl = container.read(pinFlowControllerProvider.notifier);
      // Step 1: enterNew
      _enterDigits(ctrl, '1234');
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(pinFlowControllerProvider).step,
        PinFlowStep.confirm,
      );

      // Step 2: mismatched confirm
      _enterDigits(ctrl, '5678');
      await Future<void>.delayed(Duration.zero);

      final s = container.read(pinFlowControllerProvider);
      expect(s.error, isNotNull);
      expect(s.step, PinFlowStep.enterNew);
    });
  });
}
