/// "Has today's learning been done?" for notifications, read from
/// `LearnerState` only (DNI-482 AC-5, AD-35; ruling B13 default).
///
/// Replaces the retired notifications completion-range query (R11): there
/// is no second completion-derived calculation, only a projection of the
/// engine's counted events.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';

/// The learner's state is not complete yet, so "done today" is unknown.
///
/// Owner ruling D-E: an unknown answer is never reported as `false` — a
/// fabricated "not done" would fire a reminder for a learner whose record
/// simply is not loaded.
final class LearnerStateNotReadyException implements Exception {
  /// Creates the exception.
  const LearnerStateNotReadyException();

  @override
  String toString() =>
      'LearnerStateNotReadyException: the learner state is still loading, '
      'so whether today is done is unknown.';
}

/// Whether [state] holds at least one counted learning event whose
/// effective civil date is today (ruling B13).
///
/// - Counted means what the engine counted: a voided event and an event
///   stamped during a lock (AD-36) never count (`countedLearns`).
/// - Any source counts — main track, sub-track or catch-up — and any
///   curriculum unless [curriculumId] narrows it. A `before_tracking`
///   record (prior learning entered now) is not learning done today.
/// - "Today" is [day], defaulting to `state.today`; an event's day is the
///   civil date of `effectiveAt` in the time zone in force then
///   ([settingsHistory], AD-41).
///
/// A null [state] (still loading, never partial) throws
/// [LearnerStateNotReadyException].
bool learnedToday(
  LearnerState? state,
  LearnerSettingsHistory settingsHistory, {
  CivilDate? day,
  String? curriculumId,
}) {
  if (state == null) throw const LearnerStateNotReadyException();
  final today = day ?? state.today;
  for (final e in state.countedLearns) {
    if (e.dateState == DateState.beforeTracking) continue;
    if (curriculumId != null && e.curriculumId != curriculumId) continue;
    if (civilDate(effectiveAt(e), settingsHistory) == today) return true;
  }
  return false;
}
