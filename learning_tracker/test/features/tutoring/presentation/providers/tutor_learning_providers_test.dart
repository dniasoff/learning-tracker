// Story 1.24 (DNI-486) — the tutored session's providers: the tutored
// learner's lock is judged on that learner's settings and never applies to
// the tutor's own app; write availability follows permission, then a
// positive probe, then the lock (loading counts as locked).

@Tags(['tutor_mode'])
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_write_availability.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/tutoring/tutor_learning_harness.dart';

final _lock = LockWindow(
  DateTime.utc(2026, 10, 1, 8),
  DateTime.utc(2026, 10, 2, 20),
);

Future<T> _read<T>(
  ProviderListenable<T> provider,
  List<Override> overrides,
) async {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  final sub = container.listen(provider, (_, _) {});
  addTearDown(sub.close);
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return sub.read();
}

void main() {
  group('tutoredLearnerLockProvider', () {
    test('false for the tutor\'s own app', () async {
      expect(
        (await _read<AsyncValue<bool>>(
          tutoredLearnerLockProvider,
          tutoredOverrides(gate: FakeCaptureGate.locked(_lock)),
        )).value,
        isFalse,
      );
    });

    test('true while the tutored learner is locked', () async {
      expect(
        (await _read<AsyncValue<bool>>(
          tutoredLearnerLockProvider,
          tutoredOverrides(
            selection: tutorSelection(),
            gate: FakeCaptureGate.locked(_lock),
          ),
        )).value,
        isTrue,
      );
    });
  });

  group('tutoredLearnerLock boundaries (AC-6: no window after a lock '
      'starts)', () {
    final history = c0SettingsHistory();
    final next = lockWindows(
      history,
      tutorFixtureNow,
      tutorFixtureNow.add(const Duration(days: 8)),
    ).firstWhere((w) => w.startUtc.isAfter(tutorFixtureNow));

    test('covers the learner the instant his next lock starts', () {
      // Off the backstop grid on purpose: only a boundary-aware recheck
      // lands exactly on the lock start.
      final t0 = next.startUtc.subtract(
        const Duration(minutes: 50, seconds: 7, milliseconds: 3),
      );
      fakeAsync((async) {
        final container = ProviderContainer(
          overrides: tutoredOverrides(
            selection: tutorSelection(),
            lockSettings: history,
            gate: const LockWindowCaptureGate(),
            clock: () => t0.add(async.elapsed),
          ),
        );
        final sub = container.listen(tutoredLearnerLockProvider, (_, _) {});
        // Let the talmid's scope and settings resolve (no clock movement).
        for (var i = 0; i < 5; i++) {
          async.elapse(Duration.zero);
        }
        expect(sub.read(), const AsyncData(false));

        async.elapse(next.startUtc.difference(t0) - civilTick);
        expect(sub.read(), const AsyncData(false));

        async.elapse(civilTick);
        expect(sub.read(), const AsyncData(true));

        sub.close();
        container.dispose();
      });
    });

    test('rechecks just after the current lock ends', () {
      final now = next.endUtc.subtract(const Duration(seconds: 5));
      expect(
        tutoredLearnerLockRecheckDelay(history, now, GateLocked(next)),
        const Duration(seconds: 5) + civilTick,
      );
    });

    test('rechecks exactly at the next lock start when it is near', () {
      final now = next.startUtc.subtract(const Duration(seconds: 12));
      expect(
        tutoredLearnerLockRecheckDelay(history, now, const GateOpen()),
        const Duration(seconds: 12),
      );
    });

    test('a far boundary or an unbounded lock falls back to the backstop', () {
      final far = next.startUtc.subtract(const Duration(hours: 3));
      expect(
        tutoredLearnerLockRecheckDelay(history, far, const GateOpen()),
        tutoredLearnerLockBackstop,
      );
      expect(
        tutoredLearnerLockRecheckDelay(
          history,
          far,
          GateLocked(unknownLockAt(far)),
        ),
        tutoredLearnerLockBackstop,
      );
    });
  });

  group('tutorWriteAvailabilityProvider', () {
    test('available when permitted, online and unlocked', () async {
      expect(
        await _read<TutorWriteAvailability>(
          tutorWriteAvailabilityProvider,
          tutoredOverrides(selection: tutorSelection()),
        ),
        TutorWriteAvailability.available,
      );
    });

    test('locked while the learner\'s settings are still loading (fail '
        'closed)', () async {
      final pending = StreamController<LearnerSettingsHistory>();
      addTearDown(pending.close);
      expect(
        await _read<TutorWriteAvailability>(
          tutorWriteAvailabilityProvider,
          tutoredOverrides(
            selection: tutorSelection(),
            lockSettingsStream: pending.stream,
          ),
        ),
        TutorWriteAvailability.locked,
      );
    });
  });
}
