/// The capture gate every `LearningCommands` command runs first (AD-36).
///
/// DNI-469 (1.7) owns [CaptureGate] at this path (ruling B4(d)) and fills
/// [LockWindowCaptureGate.check] over `lockWindows`, the only window
/// function (AD-36).
library;

import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

/// Whether a capture may proceed.
sealed class GateDecision {
  const GateDecision();
}

/// The capture may proceed.
final class GateOpen extends GateDecision {
  /// Creates the decision.
  const GateOpen();

  @override
  bool operator ==(Object other) => other is GateOpen;

  @override
  int get hashCode => (GateOpen).hashCode;

  @override
  String toString() => 'GateOpen()';
}

/// The learner is inside lock [window].
final class GateLocked extends GateDecision {
  /// Creates the decision.
  const GateLocked(this.window);

  /// The lock in force.
  final LockWindow window;

  @override
  bool operator ==(Object other) =>
      other is GateLocked && other.window == window;

  @override
  int get hashCode => window.hashCode;

  @override
  String toString() => 'GateLocked($window)';
}

/// Decides whether a capture at [nowUtc] may proceed.
abstract interface class CaptureGate {
  /// The decision at [nowUtc] under [settingsHistory].
  GateDecision check(LearnerSettingsHistory settingsHistory, DateTime nowUtc);
}

/// The production gate: locked inside any AD-36 lock window.
///
/// The target learner's [LearnerSettingsHistory] decides (AD-36 "every
/// write passes `CaptureGate` ... using the target learner's settings"),
/// and the lock is judged with the settings in force at `nowUtc`. Window
/// bounds are inside the lock (closed intervals, fail closed). A window
/// computation that throws is treated as a lock at `nowUtc` (FR-23 fail
/// closed): the command writes nothing.
final class LockWindowCaptureGate implements CaptureGate {
  /// The gate has no state.
  const LockWindowCaptureGate();

  @override
  GateDecision check(LearnerSettingsHistory settingsHistory, DateTime nowUtc) {
    final now = nowUtc.toUtc();
    final List<LockWindow> windows;
    try {
      windows = lockWindows(settingsHistory, now, now);
    } on Object {
      return GateLocked(unknownLockAt(now));
    }
    for (final window in windows) {
      if (window.contains(now)) return GateLocked(window);
    }
    return const GateOpen();
  }
}

/// The zero-length lock a command reports when it cannot prove the
/// learner is unlocked at [nowUtc] (settings unreadable, or the window
/// computation failed): fail closed (AD-36, FR-23).
LockWindow unknownLockAt(DateTime nowUtc) =>
    LockWindow(nowUtc.toUtc(), nowUtc.toUtc());
