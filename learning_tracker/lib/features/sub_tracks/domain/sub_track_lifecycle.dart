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
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart';

/// Whether [track] is listed as ended on the learner's civil [today]
/// (AC-5, AC-6): it is tombstoned (`ended_at` set, by end, delete, undo or
/// track removal) or its window ended before [today]. Exactly
/// `!holdsGround` (AD-34): a stored `ended_at` wins over a future window, a
/// null `window_end` stays open, and `window_end` itself is still active.
bool isEndedSubTrack(SubTrack track, CivilDate today) =>
    !holdsGround(track, today);

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

// The academic-year convention (September start), the picker range and
// the month-bounded window dates are Story 2.4's (DNI-495,
// `school_year_sub_track_form_validation.dart`); *Add next year* reuses
// them so the pill, the prefill and the form agree.

/// The last academic year the school-year picker offers on [today]
/// ([academicYearOptions] without an edited row's own year).
int lastPickableAcademicYear(CivilDate today, {CivilDate? deadline}) =>
    academicYearOptions(today: today, deadline: deadline).last;

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
    windowStart: schoolYearWindowStart(next, _monthOf(source.windowStart)),
    windowEnd: end == null ? null : schoolYearWindowEnd(next, _monthOf(end)),
    ratePerWeek: source.ratePerWeek,
    weeksPerYear: source.weeksPerYear,
    learnsOnShabbos: source.learnsOnShabbos,
    ground: const [],
  );
}

int _monthOf(CivilDate date) => int.parse(date.substring(5, 7));
