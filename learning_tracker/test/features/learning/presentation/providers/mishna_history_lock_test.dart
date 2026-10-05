/// DNI-475 (Story 1.13) unit level: the Mishna-history lock is the target
/// learner's AD-36 lock (their lock settings judged by the shared capture
/// gate), not only the device's sacred window.
/// TQ-6: fixed instants only.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/presentation/providers/mishna_history_provider.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/learner_state/provider_settle.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/tutoring/tutor_learning_harness.dart';

/// The device owner's own learner: no lock in force.
final _ownScope = c0Scope();

/// A talmid in another parent's namespace: Shabbos is in force for them.
final _talmidScope = LearnerScope(ownerUid: 'parent-uid', profileId: ulidA);

final _ownSettings = c0SettingsHistory();
final _talmidSettings = LearnerSettingsHistory.constant(
  const LearnerSettings(profileId: ulidA, timeZone: 'Asia/Jerusalem'),
);

final _shabbos = LockWindow(t0, t1);

/// Locked exactly when asked about [_talmidSettings].
final class _TalmidLockedGate implements CaptureGate {
  final List<LearnerSettingsHistory> checked = [];

  @override
  GateDecision check(LearnerSettingsHistory settingsHistory, DateTime nowUtc) {
    checked.add(settingsHistory);
    return identical(settingsHistory, _talmidSettings)
        ? GateLocked(_shabbos)
        : const GateOpen();
  }
}

ProviderContainer _container({
  required LearnerScope? active,
  required CaptureGate gate,
  SacredWindow? deviceLock,
  Stream<LearnerSettingsHistory> Function(LearnerScope scope)? settings,
  bool tutored = false,
}) {
  final container = ProviderContainer(
    overrides: [
      ...learnerStateOverrides(scope: active, gate: gate),
      currentSacredWindowProvider.overrideWithValue(deviceLock),
      learnerLockSettingsProvider.overrideWith(
        (ref, scope) =>
            settings?.call(scope) ??
            Stream.value(
              scope == _talmidScope ? _talmidSettings : _ownSettings,
            ),
      ),
      if (tutored)
        activeTutoredProfileSelectionProvider.overrideWith(
          () => FixedTutoredSelection(tutorSelection()),
        ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('history visibility follows the device user (AD-36)', () {
    test(
      'a tutored talmid lock does not hide history from an unlocked tutor',
      () async {
        final gate = _TalmidLockedGate();
        final container = _container(
          active: _talmidScope,
          gate: gate,
          tutored: true,
        );

        final lock = await settledAsync(container, mishnaHistoryLockProvider);

        expect(lock, const AsyncData(false));
        expect(gate.checked, isEmpty);
      },
    );

    test("the device owner's own open lock does not unlock the talmid's "
        'history, and the talmid lock does not lock the owner', () async {
      final gate = _TalmidLockedGate();
      final own = _container(active: _ownScope, gate: gate);
      expect(
        await settledAsync(own, mishnaHistoryLockProvider),
        const AsyncData(false),
      );
      expect(gate.checked, [same(_ownSettings)]);
    });

    test('the device lock still locks the history', () async {
      final container = _container(
        active: _ownScope,
        gate: FakeCaptureGate.open(),
        deviceLock: SacredWindow(
          startUtc: t0,
          endUtc: t1,
          kind: SacredWindowKind.shabbos,
        ),
      );
      expect(
        await settledAsync(container, mishnaHistoryLockProvider),
        const AsyncData(true),
      );
    });

    test('loading or unreadable settings do not create a lock', () async {
      final loading = _container(
        active: _talmidScope,
        gate: FakeCaptureGate.open(),
        settings: (_) => const Stream<LearnerSettingsHistory>.empty(),
      );
      expect(
        await settledAsync(loading, mishnaHistoryLockProvider),
        const AsyncData(false),
      );

      final failing = _container(
        active: _talmidScope,
        gate: FakeCaptureGate.open(),
        settings: (_) => Stream.error(StateError('settings unreadable')),
      );
      final lock = await settledAsync(failing, mishnaHistoryLockProvider);
      expect(lock, const AsyncData(false));
    });

    test('re-judges the lock as time passes', () async {
      final gate = FakeCaptureGate.open();
      final container = _container(active: _talmidScope, gate: gate);
      expect(
        await settledAsync(container, mishnaHistoryLockProvider),
        const AsyncData(false),
      );

      gate.decision = GateLocked(_shabbos);
      // The provider's recheck timer is real; invalidating stands in for
      // its tick without waiting 30 s.
      container.invalidate(mishnaHistoryLockProvider);
      expect(
        await settledAsync(container, mishnaHistoryLockProvider),
        const AsyncData(true),
      );
    });
  });
}
