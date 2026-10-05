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

final _locatedHistory = LearnerSettingsHistory.constant(newYorkLocated);
final _lock = lockWindows(
  _locatedHistory,
  DateTime.utc(2026, 9, 4),
  DateTime.utc(2026, 9, 6),
).single;
final _lockStart = _lock.startUtc;
final _lockEnd = _lock.endUtc;
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
        gate.check(c0NoLocationHistory(), DateTime.utc(2026, 9, 3, 12)),
        const GateOpen(),
      );
      expect(
        gate.check(c0NoLocationHistory(), _lockStart.subtract(_tick)),
        const GateOpen(),
      );
      expect(
        gate.check(c0NoLocationHistory(), _lockEnd.add(_tick)),
        const GateOpen(),
      );
    });

    test('no location: open on Friday afternoon and Shabbos', () {
      for (final at in [
        DateTime.utc(2026, 9, 4, 17),
        DateTime.utc(2026, 9, 5, 19),
      ]) {
        expect(gate.check(c0NoLocationHistory(), at), const GateOpen());
      }
    });

    test('locked inside a window, reporting its true bounds; both bounds '
        'are inside (closed interval, fail closed)', () {
      final window = _lock;
      for (final at in [_lockStart, DateTime.utc(2026, 9, 5, 10), _lockEnd]) {
        expect(gate.check(_locatedHistory, at), GateLocked(window));
      }
    });

    test('judges the instant with the settings in force at it', () {
      // Lakewood until Friday 17:00Z, then Jerusalem: settings at each
      // instant choose the appropriate location's window.
      final history = movedHistory(
        lakewood,
        DateTime.utc(2026, 9, 4, 17),
        jerusalem,
      );
      // Friday 13:00Z is before Lakewood candle-lighting; 17:00Z is
      // after Jerusalem candle-lighting.
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
        const LearnerSettings(
          profileId: profileUlid,
          timeZone: 'Mars/Base',
          latitude: 40.0,
          longitude: -74.0,
          inIsrael: false,
        ),
      );
      // Fri 00:00Z is before the UTC window but inside the widened one.
      expect(lockOf(gate.check(history, DateTime.utc(2026, 9, 4))), isNotNull);
    });
  });

  test('unknownLockAt is the zero-length window at now', () {
    expect(unknownLockAt(t0), LockWindow(t0, t0));
  });
}
