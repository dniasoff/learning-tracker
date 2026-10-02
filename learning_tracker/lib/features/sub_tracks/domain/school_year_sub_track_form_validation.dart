/// Pure date-window, academic-year and field validation for the school-year
/// sub-track form (Story 2.4 / DNI-495, AC-5, AC-7, AC-8).
///
/// The form never writes: on save it maps its values to a Story 2.1
/// [SubTrackDraft] (create) or [SubTrackEdit] (only the changed fields) and
/// calls `LearningCommands.createSubTrack` / `editSubTrack`, which run the
/// shared AD-45 validation again. This file mirrors those rules so the form
/// can show inline field errors on blur and on save (UX-DR-80) before any
/// command runs, and maps a command's AD-45 violations back onto fields.
///
/// Dates are AD-41 civil `YYYY-MM-DD` strings. The academic year `Y` runs
/// from 1 September `Y` to 31 August `Y + 1`, both inclusive.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';

/// The month an academic year starts in (September).
const kAcademicYearFirstMonth = DateTime.september;

/// The form's default start month (AC-4).
const kDefaultSchoolYearStartMonth = DateTime.september;

/// The form's default end month (AC-4).
const kDefaultSchoolYearEndMonth = DateTime.july;

/// The form's prefilled weeks per year (AC-4).
const kDefaultSchoolYearWeeksPerYear = 39;

/// The form's initial leaf units per week (screens.md #05 shows 10).
const kDefaultSchoolYearRatePerWeek = 10;

/// Without a deadline the picker offers the current year plus this many
/// following years (AC-5).
const kNoDeadlineExtraAcademicYears = 2;

/// `YYYY-MM-DD` for a civil [year], [month] and [day].
CivilDate civilDateOf(int year, int month, int day) =>
    '${year.toString().padLeft(4, '0')}-'
    '${month.toString().padLeft(2, '0')}-'
    '${day.toString().padLeft(2, '0')}';

int _yearOf(CivilDate date) => int.parse(date.substring(0, 4));

int _monthOf(CivilDate date) => int.parse(date.substring(5, 7));

/// The academic year containing [date]: `Y` when [date] is in
/// [1 Sep Y, 31 Aug Y+1] (AC-5).
int academicYearOf(CivilDate date) {
  final year = _yearOf(date);
  return _monthOf(date) >= kAcademicYearFirstMonth ? year : year - 1;
}

/// The civil year [month] falls in within [academicYear]: September to
/// December are in `academicYear`, January to August in `academicYear + 1`.
int civilYearOfAcademicMonth(int academicYear, int month) =>
    month >= kAcademicYearFirstMonth ? academicYear : academicYear + 1;

/// `window_start`: the 1st of [startMonth] within [academicYear] (AC-7).
CivilDate schoolYearWindowStart(int academicYear, int startMonth) =>
    civilDateOf(
      civilYearOfAcademicMonth(academicYear, startMonth),
      startMonth,
      1,
    );

/// `window_end`: the last day of [endMonth] within [academicYear], leap
/// February included (AC-7).
CivilDate schoolYearWindowEnd(int academicYear, int endMonth) {
  final year = civilYearOfAcademicMonth(academicYear, endMonth);
  // Day 0 of the next month is the last day of this one.
  final lastDay = DateTime.utc(year, endMonth + 1, 0).day;
  return civilDateOf(year, endMonth, lastDay);
}

/// The academic years the picker offers (AC-5): from the current one through
/// the year containing [deadline], or the current one plus
/// [kNoDeadlineExtraAcademicYears] without a deadline. [include] (the edited
/// sub-track's own year) is always offered, so editing a past or far year
/// keeps its chip.
List<int> academicYearOptions({
  required CivilDate today,
  CivilDate? deadline,
  int? include,
}) {
  final first = academicYearOf(today);
  final deadlineYear = deadline == null ? null : academicYearOf(deadline);
  final last = deadlineYear == null
      ? first + kNoDeadlineExtraAcademicYears
      : (deadlineYear < first ? first : deadlineYear);
  final years = <int>{for (var y = first; y <= last; y++) y};
  if (include != null) years.add(include);
  return years.toList()..sort();
}

/// The state label of one academic-year chip (UX-DR-32).
enum AcademicYearState {
  /// A non-ended school-year sub-track already holds the year: the chip is
  /// disabled but stays in the semantics tree (UX-DR-36, UX-DR-158).
  used,

  /// The current academic year, free to choose.
  active,

  /// A later academic year, free to choose.
  open,
}

/// The academic years held by a non-ended school-year sub-track of
/// [curriculumId] (AD-45 limits are per curriculum), except [exceptId] (the
/// sub-track being edited: its own year is not *Used*, AC-8).
Set<int> usedAcademicYears(
  Iterable<SubTrack> subTracks, {
  required String curriculumId,
  String? exceptId,
}) => {
  for (final s in subTracks)
    if (_isOtherLiveSchoolYear(s, curriculumId, exceptId))
      if (s.academicYear case final year?) year,
};

/// The chip state of [year].
AcademicYearState academicYearState(
  int year, {
  required Set<int> used,
  required int currentYear,
}) {
  if (used.contains(year)) return AcademicYearState.used;
  return year == currentYear
      ? AcademicYearState.active
      : AcademicYearState.open;
}

bool _isOtherLiveSchoolYear(
  SubTrack s,
  String curriculumId,
  String? exceptId,
) =>
    s.curriculumId == curriculumId &&
    s.id != exceptId &&
    !s.isEnded &&
    s.type == SubTrackType.schoolYear;

/// A positive, finite number parsed from [raw] (a comma decimal separator is
/// accepted), or null for blank, zero, negative, NaN, infinite or
/// unparseable input (edge cases).
double? parsePositiveNumber(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  final value = double.tryParse(text);
  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
}

/// [value] without a trailing `.0` (`10.0` → `10`, `2.5` → `2.5`).
String formatFormNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

/// The fields of the school-year form that can carry an inline error.
enum SchoolYearFormField {
  /// "Sub-track name".
  name,

  /// The academic-year chip row.
  academicYear,

  /// The start / end month pair.
  window,

  /// "{Leaf unit} per week".
  rate,

  /// "Weeks per year".
  weeks,
}

/// One inline validation error (UX-DR-80).
enum SchoolYearFormError {
  /// The name is empty or whitespace.
  nameRequired,

  /// No academic year is selected.
  yearRequired,

  /// The academic year is held by another non-ended school-year sub-track.
  yearUsed,

  /// The window overlaps another non-ended school-year window (AD-45).
  windowOverlap,

  /// The start month falls after the end month.
  windowReversed,

  /// The value is blank, not a number, zero or negative.
  notPositive,
}

/// The raw values of the school-year form.
final class SchoolYearFormValues {
  /// Creates the values.
  const SchoolYearFormValues({
    required this.name,
    required this.academicYear,
    required this.startMonth,
    required this.endMonth,
    required this.rateText,
    required this.weeksText,
    required this.learnsOnShabbos,
  });

  /// The form's values for an existing sub-track [track] (edit, AC-8).
  factory SchoolYearFormValues.of(SubTrack track) {
    final end = track.windowEnd;
    return SchoolYearFormValues(
      name: track.name,
      academicYear: track.academicYear ?? academicYearOf(track.windowStart),
      startMonth: _monthOf(track.windowStart),
      endMonth: end == null ? kDefaultSchoolYearEndMonth : _monthOf(end),
      rateText: formatFormNumber(track.ratePerWeek),
      weeksText: formatFormNumber(track.weeksPerYear),
      learnsOnShabbos: track.learnsOnShabbos,
    );
  }

  /// The entered name (trimmed on save).
  final String name;

  /// The selected academic year, if any.
  final int? academicYear;

  /// The start month, 1–12.
  final int startMonth;

  /// The end month, 1–12.
  final int endMonth;

  /// The rate field's text.
  final String rateText;

  /// The weeks field's text.
  final String weeksText;

  /// The shabbos / yom tov switch.
  final bool learnsOnShabbos;

  /// The window start, or null without an academic year.
  CivilDate? get windowStart {
    final year = academicYear;
    return year == null ? null : schoolYearWindowStart(year, startMonth);
  }

  /// The window end, or null without an academic year.
  CivilDate? get windowEnd {
    final year = academicYear;
    return year == null ? null : schoolYearWindowEnd(year, endMonth);
  }
}

/// Validates [values] (AC-7, AC-8) against [subTracks] (the learner's
/// sub-tracks, any curriculum, live and ended). Only non-ended school-year
/// sub-tracks of [curriculumId] other than [editingId] count. Returns one
/// error per failing field; empty when the form can be saved.
Map<SchoolYearFormField, SchoolYearFormError> validateSchoolYearForm(
  SchoolYearFormValues values, {
  required String curriculumId,
  required Iterable<SubTrack> subTracks,
  String? editingId,
}) {
  final errors = <SchoolYearFormField, SchoolYearFormError>{};
  if (values.name.trim().isEmpty) {
    errors[SchoolYearFormField.name] = SchoolYearFormError.nameRequired;
  }
  final year = values.academicYear;
  if (year == null) {
    errors[SchoolYearFormField.academicYear] = SchoolYearFormError.yearRequired;
  } else {
    final used = usedAcademicYears(
      subTracks,
      curriculumId: curriculumId,
      exceptId: editingId,
    );
    if (used.contains(year)) {
      errors[SchoolYearFormField.academicYear] = SchoolYearFormError.yearUsed;
    }
    final start = values.windowStart!;
    final end = values.windowEnd!;
    if (start.compareTo(end) > 0) {
      errors[SchoolYearFormField.window] = SchoolYearFormError.windowReversed;
    } else if (subTracks.any(
      (s) =>
          _isOtherLiveSchoolYear(s, curriculumId, editingId) &&
          _overlaps(start, end, s.windowStart, s.windowEnd),
    )) {
      errors[SchoolYearFormField.window] = SchoolYearFormError.windowOverlap;
    }
  }
  if (parsePositiveNumber(values.rateText) == null) {
    errors[SchoolYearFormField.rate] = SchoolYearFormError.notPositive;
  }
  if (parsePositiveNumber(values.weeksText) == null) {
    errors[SchoolYearFormField.weeks] = SchoolYearFormError.notPositive;
  }
  return errors;
}

/// Inclusive civil-date overlap; a null [bEnd] is open-ended. Windows that
/// touch on one day overlap (AD-45, inclusive bounds).
bool _overlaps(
  CivilDate aStart,
  CivilDate aEnd,
  CivilDate bStart,
  CivilDate? bEnd,
) => aStart.compareTo(bEnd ?? '9999-12-31') <= 0 && bStart.compareTo(aEnd) <= 0;

/// The create intent for valid [values] (AC-7): `type = school_year`,
/// month-bounded window dates, `ground = []`. Only call it after
/// [validateSchoolYearForm] returned no error.
SubTrackDraft schoolYearDraft(
  SchoolYearFormValues values, {
  required String curriculumId,
}) => SubTrackDraft(
  curriculumId: curriculumId,
  name: values.name.trim(),
  type: SubTrackType.schoolYear,
  academicYear: values.academicYear,
  windowStart: values.windowStart!,
  windowEnd: values.windowEnd,
  ratePerWeek: parsePositiveNumber(values.rateText)!,
  weeksPerYear: parsePositiveNumber(values.weeksText)!,
  learnsOnShabbos: values.learnsOnShabbos,
  ground: const [],
);

/// The edit of [current] to valid [values] carrying only the changed fields
/// (AC-8), or null when nothing changed.
SubTrackEdit? schoolYearEdit(SubTrack current, SchoolYearFormValues values) {
  final name = values.name.trim();
  final rate = parsePositiveNumber(values.rateText)!;
  final weeks = parsePositiveNumber(values.weeksText)!;
  final start = values.windowStart!;
  final end = values.windowEnd!;
  final edit = SubTrackEdit(
    name: name == current.name ? null : name,
    academicYear: values.academicYear == current.academicYear
        ? null
        : values.academicYear,
    windowStart: start == current.windowStart ? null : start,
    windowEnd: end == current.windowEnd ? null : end,
    ratePerWeek: rate == current.ratePerWeek ? null : rate,
    weeksPerYear: weeks == current.weeksPerYear ? null : weeks,
    learnsOnShabbos: values.learnsOnShabbos == current.learnsOnShabbos
        ? null
        : values.learnsOnShabbos,
  );
  final changed = [
    edit.name,
    edit.academicYear,
    edit.windowStart,
    edit.windowEnd,
    edit.ratePerWeek,
    edit.weeksPerYear,
    edit.learnsOnShabbos,
  ].any((v) => v != null);
  return changed ? edit : null;
}

/// The inline field errors for the AD-45 [violations] a command returned
/// (shared validation, Story 2.1). Violations with no form field (e.g. a
/// calendar-program curriculum) are left out; the caller reports them.
Map<SchoolYearFormField, SchoolYearFormError> schoolYearErrorsFromViolations(
  Iterable<SubTrackViolation> violations,
) => {
  for (final v in violations)
    ...switch (v.limit) {
      SubTrackLimit.schoolYearDuplicate => {
        SchoolYearFormField.academicYear: SchoolYearFormError.yearUsed,
      },
      SubTrackLimit.schoolYearOverlap => {
        SchoolYearFormField.window: SchoolYearFormError.windowOverlap,
      },
      SubTrackLimit.windowReversed => {
        SchoolYearFormField.window: SchoolYearFormError.windowReversed,
      },
      SubTrackLimit.nonPositiveRate => {
        SchoolYearFormField.rate: SchoolYearFormError.notPositive,
      },
      SubTrackLimit.nonPositiveWeeks => {
        SchoolYearFormField.weeks: SchoolYearFormError.notPositive,
      },
      _ => const <SchoolYearFormField, SchoolYearFormError>{},
    },
};
