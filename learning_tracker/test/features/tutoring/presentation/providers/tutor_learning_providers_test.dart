// Story 1.24 (DNI-486) — the tutored session's providers: the tutored
// learner's lock is judged on that learner's settings and never applies to
// the tutor's own app; write availability follows permission, then a
// positive probe, then the lock (loading counts as locked).

@Tags(['tutor_mode'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_write_availability.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';

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
