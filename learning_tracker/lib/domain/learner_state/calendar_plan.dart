/// Engine stage 6a: calendar-program planning (AD-35 "Calendar programs").
///
/// A curriculum whose live `profile_programs` doc names a `program_id`
/// plans from the calendar, not from the main-track position:
/// `programAssignments(date)`, `programBacklog(today)` and the calendar
/// `dailyTarget` / shortfall. AD-44 capacity is never computed for it.
library;

import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';

/// The calendar plan of one calendar-program curriculum.
///
/// Every query is a pure function of the derived inputs, so a plan is a
/// value: two plans over equal inputs are equal.
final class CalendarPlan {
  /// Creates a plan. Prefer [deriveCalendarPlan].
  CalendarPlan({
    required Map<CivilDate, List<LeafRef>> assignments,
    required this.amnestyFrom,
    required Set<LeafRef> learnt,
  }) : _assignments = Map.unmodifiable({
         for (final MapEntry(:key, :value) in assignments.entries)
           key: List<LeafRef>.unmodifiable(value),
       }),
       _dates = (assignments.keys.toList()..sort()),
       _learnt = Set.unmodifiable(learnt);

  final Map<CivilDate, List<LeafRef>> _assignments;
  final List<CivilDate> _dates;
  final Set<LeafRef> _learnt;

  /// `max(tracking_start_date, civilDate(at) of the latest mainTrackOrder
  /// or mainTrackProgram entry)`; null when `tracking_start_date` is
  /// missing (a validation error: backlog and target are then not
  /// derived, never defaulted).
  final CivilDate? amnestyFrom;

  /// The leaves assigned on [date]: each assigned node expanded by
  /// `expandGround`, intersected with the learner's corpus, in assignment
  /// order with duplicates dropped. Learnt leaves are included.
  List<LeafRef> assignments(CivilDate date) => _assignments[date] ?? const [];

  /// The assigned leaves dated before [today] and on or after
  /// [amnestyFrom] with no counted learn event, in date order, each leaf
  /// once (at its earliest date). Empty while [amnestyFrom] is null.
  List<LeafRef> backlog(CivilDate today) {
    final from = amnestyFrom;
    if (from == null) return const [];
    return _unlearntIn(from, today, inclusiveEnd: false);
  }

  /// Assigned through [today] (from [amnestyFrom]) minus learnt: the
  /// unlearnt leaves of `backlog(today) ∪ assignments(today)`. Null while
  /// [amnestyFrom] is null.
  int? dailyTarget(CivilDate today) {
    final from = amnestyFrom;
    if (from == null) return null;
    return _unlearntIn(from, today, inclusiveEnd: true).length;
  }

  List<LeafRef> _unlearntIn(
    CivilDate from,
    CivilDate to, {
    required bool inclusiveEnd,
  }) {
    final seen = <LeafRef>{};
    final out = <LeafRef>[];
    for (final date in _dates) {
      if (date.compareTo(from) < 0) continue;
      final cmp = date.compareTo(to);
      if (cmp > 0 || (cmp == 0 && !inclusiveEnd)) break;
      for (final leaf in _assignments[date]!) {
        if (!_learnt.contains(leaf) && seen.add(leaf)) out.add(leaf);
      }
    }
    return List.unmodifiable(out);
  }

  @override
  bool operator ==(Object other) {
    if (other is! CalendarPlan ||
        other.amnestyFrom != amnestyFrom ||
        other._assignments.length != _assignments.length ||
        other._learnt.length != _learnt.length ||
        !other._learnt.containsAll(_learnt)) {
      return false;
    }
    for (final MapEntry(:key, :value) in _assignments.entries) {
      final o = other._assignments[key];
      if (o == null || o.length != value.length) return false;
      for (var i = 0; i < value.length; i++) {
        if (o[i] != value[i]) return false;
      }
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(amnestyFrom, _assignments.length, _learnt.length);
}

/// Whether [intent] follows a calendar program: its track is live and its
/// live `profile_programs` doc names a `program_id`.
bool followsCalendarProgram(MainTrackIntent? intent) {
  final program = intent?.program;
  return intent != null &&
      intent.track.endedAt == null &&
      program != null &&
      program.endedAt == null &&
      program.programId != null;
}

/// The calendar plan of [curriculumId], or null when [intent] does not
/// follow a calendar program ([followsCalendarProgram]).
///
/// * Assignments come from `calendars[program_id]` (an absent program
///   yields no assignments), expanded by `expandGround` and intersected
///   with the learner's corpus ([inScope]).
/// * `amnestyFrom` is the later of `tracking_start_date` and the civil
///   date of the latest `mainTrackOrder` / `mainTrackProgram` entry of the
///   curriculum, by `original_at ?? at` (the AD-35 intent-history instant).
///   `curriculum_tracks.last_reorder_at` and `activated_at` are not
///   inputs and are never read.
/// * A missing `tracking_start_date` adds
///   [CurriculumValidationError.missingTrackingStartDate] to [errors].
CalendarPlan? deriveCalendarPlan({
  required String curriculumId,
  required MainTrackIntent? intent,
  required Map<String, List<CalendarAssignment>> calendars,
  required Corpus corpus,
  required bool Function(LeafRef leaf) inScope,
  required Set<LeafRef> learnt,
  required List<ChangeLogEntry> intentHistory,
  required LearnerSettingsHistory settingsHistory,
  required Set<CurriculumValidationError> errors,
}) {
  if (!followsCalendarProgram(intent)) return null;
  final program = intent!.program!;
  final byDate = <CivilDate, List<CalendarAssignment>>{};
  for (final a
      in calendars[program.programId] ?? const <CalendarAssignment>[]) {
    (byDate[a.date] ??= []).add(a);
  }
  final assignments = <CivilDate, List<LeafRef>>{
    for (final MapEntry(key: date, value: list) in byDate.entries)
      date: [
        for (final leaf in expandGround([for (final a in list) a.node], corpus))
          if (inScope(leaf)) leaf,
      ],
  };
  final start = program.trackingStartDate;
  CivilDate? amnestyFrom;
  if (start == null) {
    errors.add(CurriculumValidationError.missingTrackingStartDate);
  } else {
    amnestyFrom = start;
    final reanchor = _latestReanchor(intentHistory, curriculumId);
    if (reanchor != null) {
      final day = civilDate(reanchor, settingsHistory);
      if (day.compareTo(start) > 0) amnestyFrom = day;
    }
  }
  return CalendarPlan(
    assignments: assignments,
    amnestyFrom: amnestyFrom,
    learnt: learnt,
  );
}

/// The `original_at ?? at` of the latest `mainTrackOrder` or
/// `mainTrackProgram` entry of [curriculumId], or null.
DateTime? _latestReanchor(
  List<ChangeLogEntry> intentHistory,
  String curriculumId,
) {
  DateTime? latest;
  for (final e in intentHistory) {
    if (e.entityId != curriculumId ||
        (e.entity != GovernedEntity.mainTrackOrder &&
            e.entity != GovernedEntity.mainTrackProgram)) {
      continue;
    }
    final at = e.originalAt ?? e.at;
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return latest;
}
