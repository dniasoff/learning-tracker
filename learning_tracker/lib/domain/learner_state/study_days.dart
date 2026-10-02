/// A curriculum's study days (`study_day_configs`, the `mainTrackStudyDays`
/// entity), typed for the engine.
///
/// One doc per weekday: `day_of_week` (ISO 1 = Monday … 7 = Sunday) and
/// `day_type` (`study` or `review`). A study day schedules new learning; a
/// review day schedules reviews only. The default with no readable doc is
/// every day a study day (PRD FR-19 "default: all seven").
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';

/// Storage key `day_of_week` of a `study_day_configs` doc.
const dayOfWeekKey = 'day_of_week';

/// Storage key `day_type` of a `study_day_configs` doc.
const dayTypeKey = 'day_type';

/// `day_type` storage value of a study day.
const studyDayType = 'study';

/// The weekday (ISO 1 = Monday … 7 = Sunday) of [date].
int weekdayOf(CivilDate date) => parseCivilDay(date).weekday;

/// [date] plus [days] civil days.
CivilDate addCivilDays(CivilDate date, int days) =>
    formatCivilDay(parseCivilDay(date).add(Duration(days: days)));

/// The study-day configuration of one curriculum at one instant.
final class StudyDays {
  /// Creates a configuration from weekday sets.
  StudyDays({required Set<int> studyWeekdays, required Set<int> activeWeekdays})
    : studyWeekdays = Set.unmodifiable(studyWeekdays),
      activeWeekdays = Set.unmodifiable({...activeWeekdays, ...studyWeekdays});

  /// Every day a study day (the default).
  factory StudyDays.everyDay() =>
      StudyDays(studyWeekdays: _all, activeWeekdays: _all);

  /// Types the live ([MainTrackConfigDoc.endedAt] null) docs of
  /// `study_day_configs` given as field maps. A doc without a readable
  /// `day_of_week` (1–7) and `day_type` is skipped; with no readable doc
  /// the result is [StudyDays.everyDay].
  factory StudyDays.fromFields(Iterable<Map<String, Object?>> liveDocs) {
    final study = <int>{};
    final active = <int>{};
    for (final fields in liveDocs) {
      final dow = fields[dayOfWeekKey];
      final type = fields[dayTypeKey];
      if (dow is! int || dow < 1 || dow > 7 || type is! String) continue;
      active.add(dow);
      if (type == studyDayType) study.add(dow);
    }
    if (active.isEmpty) return StudyDays.everyDay();
    return StudyDays(studyWeekdays: study, activeWeekdays: active);
  }

  /// [StudyDays.fromFields] over the live docs of [docs].
  factory StudyDays.fromDocs(Iterable<MainTrackConfigDoc> docs) =>
      StudyDays.fromFields([
        for (final d in docs)
          if (d.endedAt == null) d.fields,
      ]);

  static const Set<int> _all = {1, 2, 3, 4, 5, 6, 7};

  /// Weekdays that are study days (new learning). May be empty: every day
  /// marked review-only.
  final Set<int> studyWeekdays;

  /// Weekdays with any configured day (study or review): the days a review
  /// can fall on.
  final Set<int> activeWeekdays;

  /// Whether [date] is a study day.
  bool isStudyDay(CivilDate date) => studyWeekdays.contains(weekdayOf(date));

  /// The count of dates in `[from, to]` (inclusive civil dates) that are
  /// study days; 0 when `from > to` (AD-44 `studyDaysToDeadline`).
  int countStudyDays(CivilDate from, CivilDate to) {
    final start = parseCivilDay(from);
    final end = parseCivilDay(to);
    if (start.isAfter(end)) return 0;
    final days = end.difference(start).inDays + 1;
    final full = days ~/ 7;
    var count = full * studyWeekdays.length;
    for (var i = 0; i < days % 7; i++) {
      final weekday = (start.weekday - 1 + full * 7 + i) % 7 + 1;
      if (studyWeekdays.contains(weekday)) count++;
    }
    return count;
  }

  /// The first date on or after [date] whose weekday is active (study or
  /// review). [date] itself when every weekday is active.
  CivilDate nextActiveOnOrAfter(CivilDate date) {
    if (activeWeekdays.length == 7 || activeWeekdays.isEmpty) return date;
    var day = date;
    while (!activeWeekdays.contains(weekdayOf(day))) {
      day = addCivilDays(day, 1);
    }
    return day;
  }

  @override
  bool operator ==(Object other) =>
      other is StudyDays &&
      other.studyWeekdays.length == studyWeekdays.length &&
      other.studyWeekdays.containsAll(studyWeekdays) &&
      other.activeWeekdays.length == activeWeekdays.length &&
      other.activeWeekdays.containsAll(activeWeekdays);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(studyWeekdays),
    Object.hashAllUnordered(activeWeekdays),
  );

  @override
  String toString() => 'StudyDays(study: $studyWeekdays)';
}
