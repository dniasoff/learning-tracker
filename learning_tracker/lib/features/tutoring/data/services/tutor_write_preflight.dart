/// The client checks every tutor write passes BEFORE any callable is
/// invoked (Story 1.24, DNI-486): the grant's `can_edit_learning` (AD-53),
/// a positive connectivity probe (online-only, deviation #3) and the
/// device user's [CaptureGate] judged with that person's own settings
/// (product ruling 2026-10-05; supersedes DNI-486's target-learner gate).
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

  /// The target learner's settings history for command semantics.
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

/// The target history needed to interpret a tutor command is unavailable;
/// this does not represent a Sacred-Time lock.
final class TutorPreflightTargetSettingsUnavailable extends TutorPreflight {
  /// Creates the outcome.
  const TutorPreflightTargetSettingsUnavailable();
}

/// The device user is inside lock [window].
final class TutorPreflightLocked extends TutorPreflight {
  /// Creates the outcome.
  const TutorPreflightLocked(this.window);

  /// The lock in force.
  final LockWindow window;
}

/// Runs the tutor write preflight for one tutored [selection].
final class TutorWritePreflight {
  /// Creates the preflight. [settingsHistory] reads the target learner's
  /// settings for command semantics. [lockHistories] reads the profiles
  /// whose settings govern this device (the tutor's own profiles in a
  /// tutored session). [isOnline] is the last connectivity probe.
  TutorWritePreflight({
    required TutoredProfileSelection selection,
    required Future<LearnerSettingsHistory> Function() settingsHistory,
    required Future<List<LearnerSettingsHistory>> Function() lockHistories,
    required CaptureGate gate,
    required bool Function() isOnline,
    required UtcClock clock,
  }) : _selection = selection,
       _settingsHistory = settingsHistory,
       _lockHistories = lockHistories,
       _gate = gate,
       _isOnline = isOnline,
       _clock = clock;

  final TutoredProfileSelection _selection;
  final Future<LearnerSettingsHistory> Function() _settingsHistory;
  final Future<List<LearnerSettingsHistory>> Function() _lockHistories;
  final CaptureGate _gate;
  final bool Function() _isOnline;
  final UtcClock _clock;
  List<LearnerSettingsHistory> _lastLockHistories = const [];

  /// The device user's settings histories from the most recent preflight.
  /// An empty list means settings were unavailable or no location was set;
  /// either way the device has no lock source to apply to stamped events.
  List<LearnerSettingsHistory> get deviceLockHistories => _lastLockHistories;

  /// Permission first, then connectivity, then the device user's lock.
  Future<TutorPreflight> check() async {
    if (!_selection.permissions.canEditLearning) {
      return const TutorPreflightNoEditAccess();
    }
    if (!_isOnline()) return const TutorPreflightOffline();
    final now = _clock().toUtc();
    final LearnerSettingsHistory history;
    List<LearnerSettingsHistory> histories;
    try {
      history = await _settingsHistory();
    } on Object {
      // The target history remains required to interpret tutor commands;
      // this is not reported as a Sacred-Time lock.
      return const TutorPreflightTargetSettingsUnavailable();
    }
    try {
      histories = await _lockHistories();
    } on Object {
      // Unknown device-user settings are not locked (product ruling
      // 2026-10-05).
      histories = const [];
    }
    _lastLockHistories = List.unmodifiable(histories);
    for (final history in histories) {
      final GateDecision decision;
      try {
        decision = _gate.check(history, now);
      } on Object {
        // Unreadable settings contribute no lock and are re-evaluated when
        // their provider recovers.
        continue;
      }
      if (decision case GateLocked(:final window)) {
        return TutorPreflightLocked(window);
      }
    }
    return TutorPreflightPassed(now, history);
  }

  /// Re-runs the gate on a callable's server-stamped [recordedAt] under the
  /// same device-user histories. True means the stored event is kept but not
  /// counted (deviation #2).
  bool stampedInLock(DateTime recordedAt) {
    for (final history in _lastLockHistories) {
      try {
        if (_gate.check(history, recordedAt.toUtc()) case GateLocked()) {
          return true;
        }
      } on Object {
        continue;
      }
    }
    return false;
  }
}
