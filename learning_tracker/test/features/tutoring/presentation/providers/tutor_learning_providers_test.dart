// DNI-486 lock affordances now follow the person using the device, per the
// 2026-10-05 product ruling; a tutored talmid's lock does not cover the tutor.

@Tags(['tutor_mode'])
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_write_availability.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';

import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/tutoring/tutor_learning_harness.dart';

final _deviceWindow = SacredWindow(
  startUtc: DateTime.utc(2026, 10, 1, 8),
  endUtc: DateTime.utc(2026, 10, 2, 20),
  kind: SacredWindowKind.shabbos,
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
    test('a locked talmid does not lock the tutor device', () async {
      final state = await _read<AsyncValue<bool>>(
        tutoredLearnerLockProvider,
        tutoredOverrides(
          selection: tutorSelection(),
          gate: FakeCaptureGate.locked(
            // The target learner's gate is deliberately locked; without a
            // tutor-device window it must not cover or disable the tutor.
            LockWindow(DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 2)),
          ),
        ),
      );
      expect(state, const AsyncData(false));
    });

    test('uses the device user window regardless of talmid settings', () async {
      final state = await _read<AsyncValue<bool>>(
        tutoredLearnerLockProvider,
        tutoredOverrides(
          selection: tutorSelection(),
          deviceWindow: _deviceWindow,
        ),
      );
      expect(state, const AsyncData(true));
    });
  });

  group('tutorWriteAvailabilityProvider', () {
    test(
      'available when permitted, online and the device user is unlocked',
      () async {
        expect(
          await _read<TutorWriteAvailability>(
            tutorWriteAvailabilityProvider,
            tutoredOverrides(selection: tutorSelection()),
          ),
          TutorWriteAvailability.available,
        );
      },
    );

    test("locked when the device user's window is active", () async {
      expect(
        await _read<TutorWriteAvailability>(
          tutorWriteAvailabilityProvider,
          tutoredOverrides(
            selection: tutorSelection(),
            deviceWindow: _deviceWindow,
          ),
        ),
        TutorWriteAvailability.locked,
      );
    });

    test('talmid settings do not drive a device lock', () async {
      expect(
        await _read<TutorWriteAvailability>(
          tutorWriteAvailabilityProvider,
          tutoredOverrides(
            selection: tutorSelection(),
            lockSettingsStream: const Stream<LearnerSettingsHistory>.empty(),
          ),
        ),
        TutorWriteAvailability.available,
      );
    });
  });
}
