// Mirror test for `lib/features/learning/domain/commands/capture_gate.dart`
// (C0 DNI-524 AC-6: exhaustive switch over GateDecision; DNI-469 AC-1:
// the lock check every command runs first).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/lock_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

/// Exhaustive: adding a GateDecision subtype breaks this switch at compile
/// time.
LockWindow? lockOf(GateDecision d) => switch (d) {
  GateOpen() => null,
  GateLocked(:final window) => window,
};

// The UTC no-location learner's fail-closed Shabbos lock (AD-36 FR-23):
// Fri 2026-09-04 12:00Z → Sun 2026-09-06 01:00Z.
final _lockStart = DateTime.utc(2026, 9, 4, 12);
final _lockEnd = DateTime.utc(2026, 9, 6, 1);
const _tick = Duration(microseconds: 1);

void main() {
  const gate = LockWindowCaptureGate();

  test('decisions are exhaustive and compare by value', () {
    final lock = LockWindow(t0, t1);
    expect(lockOf(const GateOpen()), isNull);
    expect(lockOf(GateLocked(lock)), lock);
    expect(GateLocked(lock), GateLocked(LockWindow(t0, t1)));
    expect(const GateOpen(), const GateOpen());
  });

  group('LockWindowCaptureGate.check (AD-36)', () {
    test('open outside every lock window', () {
      expect(
        gate.check(c0SettingsHistory(), DateTime.utc(2026, 9, 3, 12)),
        const GateOpen(),
      );
      expect(
        gate.check(c0SettingsHistory(), _lockStart.subtract(_tick)),
        const GateOpen(),
      );
      expect(
        gate.check(c0SettingsHistory(), _lockEnd.add(_tick)),
        const GateOpen(),
      );
    });

    test('locked inside a window, reporting its true bounds; both bounds '
        'are inside (closed interval, fail closed)', () {
      final window = LockWindow(_lockStart, _lockEnd);
      for (final at in [_lockStart, DateTime.utc(2026, 9, 5, 10), _lockEnd]) {
        expect(gate.check(c0SettingsHistory(), at), GateLocked(window));
      }
    });

    test('judges the instant with the settings in force at it', () {
      // UTC until Fri 00:00Z, then New York (fail-closed window shifts to
      // Fri 12:00 → Sun 01:00 New York = 16:00Z → 05:00Z).
      final history = movedHistory(
        c0Settings,
        DateTime.utc(2026, 9, 4),
        newYorkNoLocation,
      );
      // 13:00Z Friday is inside the UTC window, outside the New York one.
      expect(
        gate.check(history, DateTime.utc(2026, 9, 4, 13)),
        const GateOpen(),
      );
      expect(
        lockOf(gate.check(history, DateTime.utc(2026, 9, 4, 17))),
        isNotNull,
      );
    });

    test('an unknown time zone fails closed to the widened window', () {
      final history = LearnerSettingsHistory.constant(
        const LearnerSettings(profileId: profileUlid, timeZone: 'Mars/Base'),
      );
      // Fri 00:00Z is before the UTC window but inside the widened one.
      expect(lockOf(gate.check(history, DateTime.utc(2026, 9, 4))), isNotNull);
    });
  });

  test('unknownLockAt is the zero-length window at now', () {
    expect(unknownLockAt(t0), LockWindow(t0, t0));
  });
}
