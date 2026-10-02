// Mirror test for `lib/features/learning/domain/commands/capture_gate.dart`
// (C0, DNI-524 AC-6: exhaustive switch over GateDecision).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/c0_stub_matcher.dart';
import '../../../../helpers/learner_state_fixtures.dart';

/// Exhaustive: adding a GateDecision subtype breaks this switch at compile
/// time.
LockWindow? lockOf(GateDecision d) => switch (d) {
  GateOpen() => null,
  GateLocked(:final window) => window,
};

void main() {
  test('decisions are exhaustive and compare by value', () {
    final lock = LockWindow(t0, t1);
    expect(lockOf(const GateOpen()), isNull);
    expect(lockOf(GateLocked(lock)), lock);
    expect(GateLocked(lock), GateLocked(LockWindow(t0, t1)));
    expect(const GateOpen(), const GateOpen());
  });

  test('LockWindowCaptureGate.check is a C0 stub owned by DNI-469', () {
    expect(
      () => const LockWindowCaptureGate().check(c0SettingsHistory(), t0),
      throwsC0Stub('DNI-469', 'LockWindowCaptureGate.check'),
    );
  });
}
