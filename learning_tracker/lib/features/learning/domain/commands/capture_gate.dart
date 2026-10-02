/// The capture gate every `LearningCommands` command runs first (AD-36).
///
/// DNI-469 (1.7) owns [CaptureGate] at this path (ruling B4(d)) and fills
/// [LockWindowCaptureGate.check].
library;

import 'package:learning_tracker/domain/learner_state/c0_stub.dart';
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
final class LockWindowCaptureGate implements CaptureGate {
  /// The gate has no state.
  const LockWindowCaptureGate();

  /// C0 stub, filled by DNI-469 (1.7).
  @override
  GateDecision check(LearnerSettingsHistory settingsHistory, DateTime nowUtc) =>
      c0Stub('DNI-469', 'LockWindowCaptureGate.check');
}
