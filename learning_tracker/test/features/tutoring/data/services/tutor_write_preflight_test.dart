// Story 1.24 (DNI-486) — the tutor write preflight: permission first, then
// a positive connectivity probe, then the device user's lock, and the AC-7
// re-check of a server-stamped recorded_at under that same owner history.

@Tags(['tutor_mode'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/tutoring/tutor_learning_harness.dart';

final _lock = LockWindow(
  DateTime.utc(2026, 10, 1, 8),
  DateTime.utc(2026, 10, 2, 20),
);

TutorWritePreflight _preflight({
  bool canEditLearning = true,
  bool online = true,
  CaptureGate? gate,
  bool settingsFail = false,
  LearnerSettingsHistory? settingsHistory,
  List<LearnerSettingsHistory>? lockHistories,
  DateTime? now,
}) => TutorWritePreflight(
  selection: tutorSelection(canEditLearning: canEditLearning),
  settingsHistory: () async {
    if (settingsFail) throw StateError('unreadable');
    return settingsHistory ?? c0SettingsHistory();
  },
  lockHistories: () async => lockHistories ?? [c0SettingsHistory()],
  gate: gate ?? FakeCaptureGate.open(),
  isOnline: () => online,
  clock: () => now ?? tutorFixtureNow,
);

void main() {
  test('passes with editing access, online and outside a lock', () async {
    final check = await _preflight().check();
    expect(check, isA<TutorPreflightPassed>());
    expect((check as TutorPreflightPassed).nowUtc, tutorFixtureNow);
  });

  test('permission first, then connectivity, then the lock', () async {
    final locked = FakeCaptureGate.locked(_lock);
    expect(
      await _preflight(
        canEditLearning: false,
        online: false,
        gate: locked,
      ).check(),
      isA<TutorPreflightNoEditAccess>(),
    );
    expect(
      await _preflight(online: false, gate: locked).check(),
      isA<TutorPreflightOffline>(),
    );
    expect(
      await _preflight(gate: locked).check(),
      isA<TutorPreflightLocked>().having((l) => l.window, 'window', _lock),
    );
  });

  test(
    'a locked talmid does not lock a tutor with no configured location',
    () async {
      final now = DateTime.utc(2026, 9, 5, 12);
      final target = constantHistory(lakewood);
      final result = await _preflight(
        gate: const LockWindowCaptureGate(),
        settingsHistory: target,
        lockHistories: [constantHistory(newYorkNoLocation)],
        now: now,
      ).check();

      expect(result, isA<TutorPreflightPassed>());
      expect((result as TutorPreflightPassed).history, same(target));
    },
  );

  test(
    'the tutor device user\'s configured Shabbos lock governs captures',
    () async {
      final now = DateTime.utc(2026, 9, 5, 12);
      final tutor = constantHistory(lakewood);
      final target = constantHistory(newYorkNoLocation);
      final result = await _preflight(
        gate: const LockWindowCaptureGate(),
        settingsHistory: target,
        lockHistories: [tutor],
        now: now,
      ).check();

      expect(result, isA<TutorPreflightLocked>());
    },
  );

  test(
    'unreadable target settings are unavailable, not a Sacred-Time lock',
    () async {
      expect(
        await _preflight(settingsFail: true).check(),
        isA<TutorPreflightTargetSettingsUnavailable>(),
      );
    },
  );

  test('stampedInLock re-runs the device gate on the server stamp', () async {
    final preflight = _preflight(gate: _WindowGate());
    await preflight.check();
    expect(preflight.stampedInLock(DateTime.utc(2026, 10, 1, 9)), isTrue);
    expect(preflight.stampedInLock(DateTime.utc(2026, 10, 1, 7)), isFalse);
  });
}

final class _WindowGate implements CaptureGate {
  @override
  GateDecision check(settingsHistory, DateTime nowUtc) =>
      _lock.contains(nowUtc) ? GateLocked(_lock) : const GateOpen();
}
