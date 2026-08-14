/// Unit tests for [PinEntryMachine] — the single implementation of the
/// digit-buffer/busy/lockout transition logic (AUD-profiles-06).
///
/// Pure Dart — no widget tree, no Riverpod container. Every PIN-entry UI
/// (PinFlowController behind the routed PinFlowScreen, and the three modal
/// dialogs) constructs one of these and forwards keypad gestures into it, so
/// these tests are the single source of truth for the transitions shared by
/// all of them — this is what "one implementation owns the transitions"
/// (the finding's acceptance criterion) actually rests on.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_entry_machine.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockPinService extends Mock implements PinService {}

/// Builds a machine plus the list of every state it has emitted, for
/// assertions that don't want to re-derive intermediate transitions.
({PinEntryMachine machine, List<PinFlowState> states}) _build({
  required PinService pinService,
  String? profileId = 'profile-1',
  PinFlowMode initialMode = PinFlowMode.verify,
  bool Function() isActive = _alwaysTrue,
}) {
  final states = <PinFlowState>[];
  final machine = PinEntryMachine(
    pinService: () => pinService,
    profileId: () => profileId,
    onStateChanged: states.add,
    isActive: isActive,
    initialMode: initialMode,
  );
  return (machine: machine, states: states);
}

bool _alwaysTrue() => true;

void _enterDigits(PinEntryMachine machine, String pin) {
  for (final d in pin.split('')) {
    machine.appendDigit(d);
  }
}

void main() {
  group('PinEntryMachine — construction / reset', () {
    test('constructs with the correct initial step per mode', () {
      final setup = _build(
        pinService: _MockPinService(),
        initialMode: PinFlowMode.setup,
      );
      expect(setup.machine.state.step, PinFlowStep.enterNew);

      final change = _build(
        pinService: _MockPinService(),
        initialMode: PinFlowMode.change,
      );
      expect(change.machine.state.step, PinFlowStep.verifyCurrent);

      final verify = _build(
        pinService: _MockPinService(),
        initialMode: PinFlowMode.verify,
      );
      expect(verify.machine.state.step, PinFlowStep.verifyCurrent);
    });

    test('reset() reinitialises mode/step and clears in-progress digits', () {
      final b = _build(pinService: _MockPinService());
      b.machine.appendDigit('1');
      b.machine.appendDigit('2');
      expect(b.machine.state.digits, '12');

      b.machine.reset(PinFlowMode.setup);
      expect(b.machine.state.mode, PinFlowMode.setup);
      expect(b.machine.state.step, PinFlowStep.enterNew);
      expect(b.machine.state.digits, isEmpty);
    });
  });

  group('PinEntryMachine.appendDigit / backspace', () {
    test('accumulates up to 4 digits and caps there', () {
      final ps = _MockPinService();
      when(
        () => ps.verifyProfilePin(any(), any()),
      ).thenAnswer((_) => Completer<bool>().future);
      final b = _build(pinService: ps);

      b.machine.appendDigit('1');
      b.machine.appendDigit('2');
      b.machine.appendDigit('3');
      b.machine.appendDigit('4');
      b.machine.appendDigit('5'); // ignored — busy (async verify in flight)

      expect(b.machine.state.digits.length, 4);
    });

    test('backspace removes the last digit; no-op on empty', () {
      final b = _build(pinService: _MockPinService());
      b.machine.appendDigit('1');
      b.machine.appendDigit('2');
      b.machine.backspace();
      expect(b.machine.state.digits, '1');

      b.machine.reset(PinFlowMode.verify);
      b.machine.backspace();
      expect(b.machine.state.digits, isEmpty);
    });
  });

  // ── Setup mode — PP-1 busy guard (original fix, now on the shared class) ──
  group(
    'PinEntryMachine — setup mode enterNew -> confirm busy guard (PP-1)',
    () {
      test(
        'a rapid extra digit right after the 4th enterNew digit is swallowed',
        () async {
          final ps = _MockPinService();
          final b = _build(
            pinService: ps,
            profileId: 'profile-1',
            initialMode: PinFlowMode.setup,
          );

          for (final d in '1234'.split('')) {
            b.machine.appendDigit(d);
          }
          b.machine.appendDigit('9'); // rapid extra tap, no await in between

          await Future<void>.delayed(Duration.zero);

          expect(b.machine.state.step, PinFlowStep.confirm);
          expect(
            b.machine.state.digits,
            isEmpty,
            reason: 'the extra tap must not land as digit 1 of confirm',
          );
          expect(b.machine.state.firstPin, '1234');
        },
      );
    },
  );

  // ── Change mode — the SAME guard, now generalised (AUD-profiles-06) ───────
  group('PinEntryMachine — change mode enterNew -> confirm busy guard '
      '(AUD-profiles-06 generalisation)', () {
    test('a rapid extra digit right after the 4th enterNew digit is '
        'swallowed, exactly like setup mode', () async {
      final ps = _MockPinService();
      when(
        () => ps.verifyProfilePin('profile-1', '0000'),
      ).thenAnswer((_) async => true);
      final b = _build(
        pinService: ps,
        profileId: 'profile-1',
        initialMode: PinFlowMode.change,
      );

      // verifyCurrent (async — advances to enterNew).
      _enterDigits(b.machine, '0000');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(b.machine.state.step, PinFlowStep.enterNew);

      // enterNew: 4 digits + an immediate extra tap, no await in between.
      for (final d in '1234'.split('')) {
        b.machine.appendDigit(d);
      }
      b.machine.appendDigit('9');

      await Future<void>.delayed(Duration.zero);

      expect(b.machine.state.step, PinFlowStep.confirm);
      expect(
        b.machine.state.digits,
        isEmpty,
        reason: 'the extra tap must not land as digit 1 of confirm',
      );
      expect(b.machine.state.firstPin, '1234');
    });
  });

  // ── Verify mode ─────────────────────────────────────────────────────────
  group('PinEntryMachine — verify mode', () {
    test('correct PIN completes the flow', () async {
      final ps = _MockPinService();
      when(
        () => ps.verifyProfilePin('profile-1', '1234'),
      ).thenAnswer((_) async => true);
      final b = _build(pinService: ps, initialMode: PinFlowMode.verify);

      _enterDigits(b.machine, '1234');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(b.machine.state.completed, isTrue);
      expect(b.machine.state.digits, isEmpty);
    });

    test('wrong PIN sets incorrectPin error and clears digits', () async {
      final ps = _MockPinService();
      when(
        () => ps.verifyProfilePin('profile-1', '0000'),
      ).thenAnswer((_) async => false);
      final b = _build(pinService: ps, initialMode: PinFlowMode.verify);

      _enterDigits(b.machine, '0000');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(b.machine.state.completed, isFalse);
      expect(b.machine.state.error, PinFlowError.incorrectPin);
      expect(b.machine.state.digits, isEmpty);
    });

    test('lockout sets lockedOut + lockoutMinutes', () async {
      final ps = _MockPinService();
      when(
        () => ps.verifyProfilePin('profile-1', '9999'),
      ).thenThrow(const PinLockoutException(5));
      final b = _build(pinService: ps, initialMode: PinFlowMode.verify);

      _enterDigits(b.machine, '9999');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(b.machine.state.lockedOut, isTrue);
      expect(b.machine.state.lockoutMinutes, 5);
    });

    test(
      'no active profile sets noActiveProfile error, no service call',
      () async {
        final ps = _MockPinService();
        final b = _build(
          pinService: ps,
          profileId: null,
          initialMode: PinFlowMode.verify,
        );

        _enterDigits(b.machine, '1234');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(b.machine.state.error, PinFlowError.noActiveProfile);
        verifyNever(() => ps.verifyProfilePin(any(), any()));
      },
    );
  });

  // ── busy never sticks true on an untyped PinService exception ─────────
  // (AUD-profiles-11). Originally landed against PinFlowController directly;
  // AUD-profiles-06 later consolidated the transition logic these 4 sites
  // live in into this shared PinEntryMachine, so the regression coverage
  // moves with the implementation.
  group('PinEntryMachine — busy never sticks true on untyped PinService '
      'exception (AUD-profiles-11)', () {
    test('verify mode: a generic StateError from verifyProfilePin clears '
        'busy and surfaces PinFlowError.unexpected', () async {
      final ps = _MockPinService();
      when(
        () => ps.verifyProfilePin('profile-1', '1234'),
      ).thenThrow(StateError('bcrypt hashing error'));
      final b = _build(pinService: ps, initialMode: PinFlowMode.verify);

      _enterDigits(b.machine, '1234');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(b.machine.state.busy, isFalse);
      expect(b.machine.state.error, PinFlowError.unexpected);

      // The keypad must still accept input — busy isn't stuck.
      b.machine.appendDigit('1');
      expect(b.machine.state.digits, '1');
    });

    test(
      'change mode verifyCurrent: a generic StateError from '
      'verifyProfilePin clears busy and surfaces PinFlowError.unexpected',
      () async {
        final ps = _MockPinService();
        when(
          () => ps.verifyProfilePin('profile-1', '0000'),
        ).thenThrow(StateError('secure-storage read failure'));
        final b = _build(pinService: ps, initialMode: PinFlowMode.change);

        _enterDigits(b.machine, '0000');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(b.machine.state.busy, isFalse);
        expect(b.machine.state.error, PinFlowError.unexpected);
        expect(b.machine.state.step, PinFlowStep.verifyCurrent);

        b.machine.appendDigit('1');
        expect(b.machine.state.digits, '1');
      },
    );

    test('setup mode confirm+save: a generic StateError from setProfilePin '
        'clears busy and surfaces PinFlowError.unexpected', () async {
      final ps = _MockPinService();
      when(
        () => ps.setProfilePin('profile-1', '1234'),
      ).thenThrow(StateError('disk full'));
      final b = _build(pinService: ps, initialMode: PinFlowMode.setup);

      _enterDigits(b.machine, '1234'); // enterNew -> confirm
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(b.machine.state.step, PinFlowStep.confirm);

      _enterDigits(b.machine, '1234'); // confirm -> save (throws)
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(b.machine.state.busy, isFalse);
      expect(b.machine.state.error, PinFlowError.unexpected);
      expect(b.machine.state.step, PinFlowStep.enterNew);

      b.machine.appendDigit('1');
      expect(b.machine.state.digits, '1');
    });

    test('change mode confirm+save: a generic StateError from setProfilePin '
        'clears busy and surfaces PinFlowError.unexpected', () async {
      final ps = _MockPinService();
      when(
        () => ps.verifyProfilePin('profile-1', '0000'),
      ).thenAnswer((_) async => true);
      when(
        () => ps.setProfilePin('profile-1', '1234'),
      ).thenThrow(StateError('disk full'));
      final b = _build(pinService: ps, initialMode: PinFlowMode.change);

      _enterDigits(b.machine, '0000'); // verifyCurrent -> enterNew
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(b.machine.state.step, PinFlowStep.enterNew);

      _enterDigits(b.machine, '1234'); // enterNew -> confirm
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(b.machine.state.step, PinFlowStep.confirm);

      _enterDigits(b.machine, '1234'); // confirm -> save (throws)
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(b.machine.state.busy, isFalse);
      expect(b.machine.state.error, PinFlowError.unexpected);
      expect(b.machine.state.step, PinFlowStep.enterNew);

      b.machine.appendDigit('1');
      expect(b.machine.state.digits, '1');
    });
  });

  // ── isActive() guard (SM-4 parity) ─────────────────────────────────────
  group('PinEntryMachine — isActive guard (SM-4 parity)', () {
    test(
      'no state emitted after the await once isActive() reports false',
      () async {
        final ps = _MockPinService();
        final completer = Completer<bool>();
        when(
          () => ps.verifyProfilePin('profile-1', '1234'),
        ).thenAnswer((_) => completer.future);

        var active = true;
        final b = _build(
          pinService: ps,
          initialMode: PinFlowMode.verify,
          isActive: () => active,
        );

        _enterDigits(b.machine, '1234');
        await Future<void>.delayed(Duration.zero);
        final emittedBeforeDispose = b.states.length;

        active = false; // simulate widget/ref disposal mid-await
        completer.complete(true);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(
          b.states.length,
          emittedBeforeDispose,
          reason:
              'no further state must be emitted once isActive() is false, '
              'mirroring the ref.mounted / mounted guard (SM-4)',
        );
      },
    );
  });
}
