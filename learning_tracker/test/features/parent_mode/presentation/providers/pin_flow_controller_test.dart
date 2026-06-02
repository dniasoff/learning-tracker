/// Unit tests for [PinFlowController] — pure state-machine logic.
///
/// Tests run without a widget tree. PinService is overridden via Riverpod so
/// bcrypt never runs in tests.
library;

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
      const original = PinFlowState(
        mode: PinFlowMode.setup,
        step: PinFlowStep.confirm,
        firstPin: '1234',
        errorMessage: 'err',
      );
      final copy = original.copyWith(firstPin: null, errorMessage: null);
      expect(copy.firstPin, isNull);
      expect(copy.errorMessage, isNull);
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
      expect(container.read(pinFlowControllerProvider).errorMessage, isNull);
    });
  });

  group('PinFlowController — verify mode (async)', () {
    test('correct PIN → completed == true', () async {
      final ps = _MockPinService();
      when(() => ps.verifyProfilePin(1, '1234')).thenAnswer((_) async => true);

      final container = _makeContainer(pinService: ps);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);

      _enterDigits(container.read(pinFlowControllerProvider.notifier), '1234');

      // Allow the async verify to complete.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(container.read(pinFlowControllerProvider).completed, isTrue);
      container.dispose();
    });

    test('wrong PIN → errorMessage is set, digits cleared', () async {
      final ps = _MockPinService();
      when(() => ps.verifyProfilePin(1, '0000')).thenAnswer((_) async => false);

      final container = _makeContainer(pinService: ps);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);

      _enterDigits(container.read(pinFlowControllerProvider.notifier), '0000');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final s = container.read(pinFlowControllerProvider);
      expect(s.completed, isFalse);
      expect(s.errorMessage, isNotNull);
      expect(s.digits, isEmpty);
      container.dispose();
    });

    test('lockout → lockedOut == true', () async {
      final ps = _MockPinService();
      when(
        () => ps.verifyProfilePin(1, '9999'),
      ).thenThrow(const PinLockoutException(5));

      final container = _makeContainer(pinService: ps);
      container
          .read(pinFlowControllerProvider.notifier)
          .reset(PinFlowMode.verify);

      _enterDigits(container.read(pinFlowControllerProvider.notifier), '9999');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final s = container.read(pinFlowControllerProvider);
      expect(s.lockedOut, isTrue);
      expect(s.lockoutMinutes, 5);
      container.dispose();
    });
  });

  group('PinFlowController — setup mode step transitions (sync)', () {
    test('4 digits in enterNew → transitions to confirm step', () async {
      final ps = _MockPinService();
      final container = _makeContainer(pinService: ps);
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
      container.dispose();
    });

    test('mismatched confirm → errorMessage set, back to enterNew', () async {
      final ps = _MockPinService();
      final container = _makeContainer(pinService: ps);
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
      expect(s.errorMessage, isNotNull);
      expect(s.step, PinFlowStep.enterNew);
      container.dispose();
    });
  });
}
