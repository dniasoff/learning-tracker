// Regression test for AUD-core-preferences-04 (EH-2).
//
// `OnboardingController.advance()` previously `await`ed
// `current.save(ref)` with NO enclosing try/catch: a throwing per-step
// `save()` override propagated as a raw, uncaught exception straight out of
// `advance()`'s Future — EH-2 ("a raw exception must never propagate into
// presentation").
//
// BEFORE the fix: `advance()`'s returned Future rejected with the step's
// raw exception, and (had it advanced) `state.currentIndex` would have
// moved past a step whose data was never actually saved.
// AFTER the fix: the save is wrapped in try/catch, logged via `AppLogger`,
// and `advance()` returns `kOnboardingStepSaveFailedErrorCode` instead of
// advancing — `state` stays on the step whose save failed, so in-memory
// state never diverges from what was actually persisted.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/onboarding_step.dart';

class _ThrowingSaveStep extends OnboardingStep {
  _ThrowingSaveStep(this._id);

  final String _id;
  bool loadCalled = false;

  @override
  String get id => _id;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
    OnboardingStepContext ctx,
  ) => const SizedBox.shrink();

  @override
  Future<void> load(Ref ref) async {
    loadCalled = true;
  }

  @override
  Future<void> save(Ref ref) async {
    throw Exception('simulated step-save failure');
  }

  @override
  String? validate(Ref ref) => null;
}

class _StubStep extends OnboardingStep {
  _StubStep(this._id);

  final String _id;
  bool loadCalled = false;

  @override
  String get id => _id;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
    OnboardingStepContext ctx,
  ) => const SizedBox.shrink();

  @override
  Future<void> load(Ref ref) async {
    loadCalled = true;
  }

  @override
  String? validate(Ref ref) => null;
}

void main() {
  group('OnboardingController.advance() — AUD-core-preferences-04 (EH-2)', () {
    test('a throwing step.save() does not reject advance()\'s Future, does '
        'not advance past the failed step, and returns the failure '
        'sentinel instead of null-as-success', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(onboardingControllerProvider.notifier);

      final a = _ThrowingSaveStep('a');
      final b = _StubStep('b');
      await controller.init([a, b]);

      Object? caughtError;
      String? result;
      await runZonedGuarded(() async {
        result = await controller.advance();
      }, (error, stack) => caughtError = error);

      expect(
        caughtError,
        isNull,
        reason:
            'advance() must not let a throwing step.save() escape as '
            'an unhandled/unobserved exception (got: $caughtError)',
      );
      expect(
        result,
        kOnboardingStepSaveFailedErrorCode,
        reason:
            'advance() must not return null (its success sentinel) '
            'when the save actually failed',
      );

      final state = container.read(onboardingControllerProvider);
      expect(
        state.currentIndex,
        0,
        reason:
            'must stay on the step whose save failed — advancing past '
            'it would leave in-memory state (now showing step b as '
            'current) diverged from what is actually persisted (step '
            'a\'s data never saved)',
      );
      expect(
        b.loadCalled,
        isFalse,
        reason: 'must not load the next step when save() failed',
      );
    });

    test('a successful save still advances normally (control case — the '
        'guard must not mask a genuine successful save)', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(onboardingControllerProvider.notifier);

      final a = _StubStep('a');
      final b = _StubStep('b');
      await controller.init([a, b]);

      final result = await controller.advance();

      expect(result, isNull);
      final state = container.read(onboardingControllerProvider);
      expect(state.currentIndex, 1);
      expect(b.loadCalled, isTrue);
    });
  });
}
