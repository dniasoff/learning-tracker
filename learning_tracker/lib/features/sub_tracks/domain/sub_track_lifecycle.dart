/// The sub-track lifecycle read model (Story 2.8 / DNI-499): which
/// sub-tracks are active or ended on the learner's civil today, and the
/// *Add next year* copy of a school-year sub-track.
///
/// Pure Dart over the AD-34 predicates and AD-45 validation; nothing here
/// writes. A window that has passed is ended by derivation only (AD-33):
/// no `ended_at` is ever stamped for it.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/predicates.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';

/// Whether [track] is listed as ended on the learner's civil [today]
/// (AC-5, AC-6): it is tombstoned (`ended_at` set, by end, delete, undo or
/// track removal) or its window ended before [today]. Exactly
/// `!holdsGround` (AD-34): a stored `ended_at` wins over a future window, a
/// null `window_end` stays open, and `window_end` itself is still active.
bool isEndedSubTrack(SubTrack track, CivilDate today) =>
    !holdsGround(track, today);

/// The complete sub-track read held rows that failed strict decode
/// (`CompleteReadReady.rejected`). The lifecycle surfaces show it as a
/// read failure with retry instead of silently dropping the rows (AD-35):
/// a missing row could hide a used academic year or a live sub-track.
final class SubTrackReadRejectedException implements Exception {
  /// Creates the failure for [count] undecodable rows.
  const SubTrackReadRejectedException(this.count);

  /// How many rows failed decode.
  final int count;

  @override
  String toString() => 'SubTrackReadRejectedException($count rows)';
}

/// The sub-track read cannot start: no learner scope is resolved yet, or
/// the sub-track repository is not ready (no active or authenticated
/// account, ruling B1). The lifecycle surfaces show it as a read failure
/// with retry, never as an empty list: nothing has been read, so "no
/// sub-tracks" would be a false empty state that hides live and ended
/// sub-tracks (and would offer an academic year another sub-track holds).
/// The read restarts by itself once the scope and repository resolve.
final class SubTrackReadNotReadyException implements Exception {
  /// Creates the failure.
  const SubTrackReadNotReadyException();

  @override
  String toString() => 'SubTrackReadNotReadyException';
}

/// A learner's sub-tracks split into the hub's active and ended groups.
final class SubTrackLifecycleGroups {
  /// Creates the groups.
  SubTrackLifecycleGroups({
    required List<SubTrack> active,
    required List<SubTrack> ended,
  }) : active = List.unmodifiable(active),
       ended = List.unmodifiable(ended);

  /// Live sub-tracks whose window has not passed, future-start included.
  final List<SubTrack> active;

  /// Tombstoned or elapsed-window sub-tracks (UX-DR-44, UX-DR-82).
  final List<SubTrack> ended;

  /// Every sub-track, active first.
  List<SubTrack> get all => [...active, ...ended];
}

/// Splits [tracks] on [today], keeping their order; [curriculumId], when
/// given, keeps only that curriculum's sub-tracks.
SubTrackLifecycleGroups groupSubTracksByLifecycle(
  Iterable<SubTrack> tracks,
  CivilDate today, {
  String? curriculumId,
}) {
  final active = <SubTrack>[];
  final ended = <SubTrack>[];
  for (final track in tracks) {
    if (curriculumId != null && track.curriculumId != curriculumId) continue;
    (isEndedSubTrack(track, today) ? ended : active).add(track);
  }
  return SubTrackLifecycleGroups(active: active, ended: ended);
}

// ── Add next year (AC-1, AC-2) ──────────────────────────────────────────

/// The month an academic year starts in (September): September to
/// December fall in civil year `academic_year`, January to August in
/// `academic_year + 1`. The same convention as the school-year form
/// (Story 2.4 / DNI-495).
const kSubTrackAcademicYearFirstMonth = DateTime.september;

/// Without a deadline the academic-year picker offers the current year
/// plus this many following years (Story 2.4 AC-5).
const kSubTrackNoDeadlineExtraYears = 2;

/// "2027–28" for academic year 2027.
String subTrackAcademicYearLabel(int academicYear) =>
    '$academicYear–${((academicYear + 1) % 100).toString().padLeft(2, '0')}';

/// The academic year containing civil [date].
int subTrackAcademicYearOf(CivilDate date) {
  final year = int.parse(date.substring(0, 4));
  final month = int.parse(date.substring(5, 7));
  return month >= kSubTrackAcademicYearFirstMonth ? year : year - 1;
}

/// The last academic year the picker offers on [today]: the year holding
/// [deadline], never before the current one, or the current year plus
/// [kSubTrackNoDeadlineExtraYears] without a deadline.
int lastPickableAcademicYear(CivilDate today, {CivilDate? deadline}) {
  final current = subTrackAcademicYearOf(today);
  if (deadline == null) return current + kSubTrackNoDeadlineExtraYears;
  final deadlineYear = subTrackAcademicYearOf(deadline);
  return deadlineYear < current ? current : deadlineYear;
}

/// The month (1–12) of civil [date].
int subTrackMonthOf(CivilDate date) => int.parse(date.substring(5, 7));

/// `window_start`: the 1st of [startMonth] within [academicYear].
CivilDate schoolYearWindowStartOf(int academicYear, int startMonth) =>
    _civil(_civilYearOf(academicYear, startMonth), startMonth, 1);

/// `window_end`: the last day of [endMonth] within [academicYear], leap
/// February included.
CivilDate schoolYearWindowEndOf(int academicYear, int endMonth) {
  final year = _civilYearOf(academicYear, endMonth);
  // Day 0 of the next month is the last day of this one.
  return _civil(year, endMonth, DateTime.utc(year, endMonth + 1, 0).day);
}

int _civilYearOf(int academicYear, int month) =>
    month >= kSubTrackAcademicYearFirstMonth ? academicYear : academicYear + 1;

CivilDate _civil(int year, int month, int day) =>
    '${year.toString().padLeft(4, '0')}-'
    '${month.toString().padLeft(2, '0')}-'
    '${day.toString().padLeft(2, '0')}';

/// Whether *Add next year* can open for a source school-year sub-track.
enum NextYearAvailability {
  /// The pill is enabled.
  available,

  /// A non-ended school-year sub-track of the curriculum already holds
  /// `academic_year + 1` (AC-2).
  yearUsed,

  /// `academic_year + 1` is past the academic-year picker's last year
  /// (AC-2).
  beyondPickerRange,

  /// No pill: the source is not a school-year sub-track, or it is
  /// tombstoned (ended, deleted, undone or its track removed), whose detail
  /// is wholly read-only. A school year whose window merely passed keeps
  /// the pill: rolling it over creates a new sub-track and never edits the
  /// source (UJ-3: "In July the sub-track ends … He taps *Add next year*").
  notOffered,
}

/// The *Add next year* state of [source] on [today] against every other
/// sub-track of the learner ([siblings], any curriculum, live and ended).
/// [deadline] is the curriculum's live deadline, which bounds the picker.
NextYearAvailability nextYearAvailability({
  required SubTrack source,
  required Iterable<SubTrack> siblings,
  required CivilDate today,
  CivilDate? deadline,
}) {
  final year = source.academicYear;
  if (source.type != SubTrackType.schoolYear ||
      year == null ||
      source.isEnded) {
    return NextYearAvailability.notOffered;
  }
  final next = year + 1;
  for (final s in siblings) {
    if (s.id != source.id &&
        s.curriculumId == source.curriculumId &&
        s.type == SubTrackType.schoolYear &&
        s.academicYear == next &&
        countsTowardSubTrackLimits(s, today)) {
      return NextYearAvailability.yearUsed;
    }
  }
  if (next > lastPickableAcademicYear(today, deadline: deadline)) {
    return NextYearAvailability.beyondPickerRange;
  }
  return NextYearAvailability.available;
}

/// The prefilled *Add next year* draft of school-year [source] (AC-1):
/// the same curriculum, name, rate, weeks per year, `learns_on_shabbos`
/// and start/end months, for `academic_year + 1`, with empty ground. An
/// open-ended source stays open-ended. Saving it creates a new sub-track;
/// [source] is never edited.
SubTrackDraft nextYearSubTrackDraft(SubTrack source) {
  final year = source.academicYear;
  if (source.type != SubTrackType.schoolYear || year == null) {
    throw ArgumentError.value(source, 'source', 'not a school-year sub-track');
  }
  final next = year + 1;
  final end = source.windowEnd;
  return SubTrackDraft(
    curriculumId: source.curriculumId,
    name: source.name,
    type: SubTrackType.schoolYear,
    academicYear: next,
    windowStart: schoolYearWindowStartOf(
      next,
      subTrackMonthOf(source.windowStart),
    ),
    windowEnd: end == null
        ? null
        : schoolYearWindowEndOf(next, subTrackMonthOf(end)),
    ratePerWeek: source.ratePerWeek,
    weeksPerYear: source.weeksPerYear,
    learnsOnShabbos: source.learnsOnShabbos,
    ground: const [],
  );
}
