/// The client checks every tutor write passes BEFORE any callable is
/// invoked (Story 1.24, DNI-486): the grant's `can_edit_learning` (AD-53),
/// a positive connectivity probe (online-only, deviation #3) and the
/// TARGET learner's [CaptureGate] judged with that learner's settings in
/// force (AD-36 "every write passes CaptureGate ... using the target
/// learner's settings").
///
/// These checks are for the immediate affordance and the lock; the
/// callables (`writeWithChangeLog`) stay authoritative for the grant.
library;

import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event_stamp.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';

/// The outcome of [TutorWritePreflight.check].
sealed class TutorPreflight {
  const TutorPreflight();
}

/// Every check passed at [nowUtc] under the target learner's [history].
final class TutorPreflightPassed extends TutorPreflight {
  /// Creates the outcome.
  const TutorPreflightPassed(this.nowUtc, this.history);

  /// The single instant the write is judged at.
  final DateTime nowUtc;

  /// The target learner's settings history.
  final LearnerSettingsHistory history;
}

/// The grant does not allow editing (`can_edit_learning` false).
final class TutorPreflightNoEditAccess extends TutorPreflight {
  /// Creates the outcome.
  const TutorPreflightNoEditAccess();
}

/// The device is not positively online.
final class TutorPreflightOffline extends TutorPreflight {
  /// Creates the outcome.
  const TutorPreflightOffline();
}

/// The target learner is inside lock [window] (or its settings could not
/// be read: fail closed, FR-23).
final class TutorPreflightLocked extends TutorPreflight {
  /// Creates the outcome.
  const TutorPreflightLocked(this.window);

  /// The lock in force.
  final LockWindow window;
}

/// Runs the tutor write preflight for one tutored [selection].
final class TutorWritePreflight {
  /// Creates the preflight. [settingsHistory] reads the TARGET learner's
  /// settings history (never the tutor device's); [isOnline] is the last
  /// connectivity probe (true only when positively online).
  const TutorWritePreflight({
    required TutoredProfileSelection selection,
    required Future<LearnerSettingsHistory> Function() settingsHistory,
    required CaptureGate gate,
    required bool Function() isOnline,
    required UtcClock clock,
  }) : _selection = selection,
       _settingsHistory = settingsHistory,
       _gate = gate,
       _isOnline = isOnline,
       _clock = clock;

  final TutoredProfileSelection _selection;
  final Future<LearnerSettingsHistory> Function() _settingsHistory;
  final CaptureGate _gate;
  final bool Function() _isOnline;
  final UtcClock _clock;

  /// Permission first, then connectivity, then the target learner's lock.
  Future<TutorPreflight> check() async {
    if (!_selection.permissions.canEditLearning) {
      return const TutorPreflightNoEditAccess();
    }
    if (!_isOnline()) return const TutorPreflightOffline();
    final now = _clock().toUtc();
    final LearnerSettingsHistory history;
    final GateDecision decision;
    try {
      history = await _settingsHistory();
      decision = _gate.check(history, now);
    } on Object {
      return TutorPreflightLocked(unknownLockAt(now)); // FR-23 fail closed
    }
    return switch (decision) {
      GateLocked(:final window) => TutorPreflightLocked(window),
      GateOpen() => TutorPreflightPassed(now, history),
    };
  }
}
