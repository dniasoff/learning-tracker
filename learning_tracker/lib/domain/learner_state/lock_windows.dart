/// AD-36 lock windows (Shabbos and yom tov) and the AD-40 catch-up window.
///
/// DNI-466 (1.4) fills the rule functions and adds `lock_constants.dart`;
/// [UtcInterval.contains] is real now.
library;

import 'package:learning_tracker/domain/learner_state/c0_stub.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';

/// A closed UTC interval `[startUtc, endUtc]`.
base class UtcInterval {
  /// Creates the interval; both ends are UTC instants.
  const UtcInterval(this.startUtc, this.endUtc);

  /// First instant inside the interval.
  final DateTime startUtc;

  /// Last instant inside the interval.
  final DateTime endUtc;

  /// Whether [t] lies in `[startUtc, endUtc]` (both ends included).
  bool contains(DateTime t) => !t.isBefore(startUtc) && !t.isAfter(endUtc);

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is UtcInterval &&
      other.startUtc == startUtc &&
      other.endUtc == endUtc;

  @override
  int get hashCode => Object.hash(runtimeType, startUtc, endUtc);

  @override
  String toString() =>
      '$runtimeType(${startUtc.toIso8601String()}, '
      '${endUtc.toIso8601String()})';
}

/// One Shabbos or yom-tov lock (AD-36): captures inside it are refused.
final class LockWindow extends UtcInterval {
  /// Creates a lock window.
  const LockWindow(super.startUtc, super.endUtc);
}

/// The lock windows that overlap `[fromUtc, toUtc]`, each judged by the
/// settings in force at its start (AD-36).
///
/// C0 stub, filled by DNI-466 (1.4).
List<LockWindow> lockWindows(
  LearnerSettingsHistory settingsHistory,
  DateTime fromUtc,
  DateTime toUtc,
) => c0Stub('DNI-466', 'lockWindows');

/// The civil days [lock] covers, by the settings in force at its start.
///
/// C0 stub, filled by DNI-466 (1.4).
Set<CivilDate> lockedDays(
  LockWindow lock,
  LearnerSettingsHistory settingsHistory,
) => c0Stub('DNI-466', 'lockedDays');

/// The AD-40 catch-up window that follows [lock].
///
/// C0 stub, filled by DNI-466 (1.4).
UtcInterval catchUpWindow(
  LockWindow lock,
  LearnerSettingsHistory settingsHistory,
) => c0Stub('DNI-466', 'catchUpWindow');
