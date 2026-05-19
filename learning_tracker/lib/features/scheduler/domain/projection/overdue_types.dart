/// Pure value types for the overdue projection module.
///
/// All types are immutable plain Dart — no codegen, no Flutter, no Riverpod,
/// no Drift, no Firebase.  They can be constructed in unit tests with zero
/// external dependencies.
library;

// ---------------------------------------------------------------------------
// Scheduled unit — one entry in a track's schedule for a given date.
// ---------------------------------------------------------------------------

/// A single unit that a track expects to be studied on [date].
///
/// For a program track [sefariaRef] is the calendar ref (e.g. "Berakhot 2a").
/// For a self-paced track [sefariaRef] is the curriculum leaf ref at the
/// computed position.
class ScheduledUnit {
  const ScheduledUnit({required this.date, required this.sefariaRef});

  /// The calendar date (UTC, midnight) on which this unit is expected.
  final DateTime date;

  /// Stable Sefaria ref — the key used in the completion log.
  final String sefariaRef;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduledUnit &&
          date == other.date &&
          sefariaRef == other.sefariaRef;

  @override
  int get hashCode => Object.hash(date, sefariaRef);

  @override
  String toString() => 'ScheduledUnit($sefariaRef @ $date)';
}

// ---------------------------------------------------------------------------
// Study-day pattern — the days of the week on which the learner studies.
// ---------------------------------------------------------------------------

/// A set of ISO weekdays (Monday = 1 … Sunday = 7) on which the learner
/// studies.  Used by [selfPacedSchedule] to count elapsed study days.
///
/// An empty set means "study every day" — equivalent to all 7 days.
class StudyDayPattern {
  /// Create a pattern from an explicit set.  An empty set is interpreted as
  /// "every day" (see [isStudyDay]).
  const StudyDayPattern(this.weekdays);

  /// Every day — the default for tracks that have no study-day config.
  static const StudyDayPattern everyDay = StudyDayPattern({});

  /// The ISO weekdays on which the learner studies.
  final Set<int> weekdays;

  /// True if [isoWeekday] (1 = Monday … 7 = Sunday) is a study day.
  bool isStudyDay(int isoWeekday) {
    if (weekdays.isEmpty) return true;
    return weekdays.contains(isoWeekday);
  }
}

// ---------------------------------------------------------------------------
// Projection result
// ---------------------------------------------------------------------------

/// The result of [project] — the three buckets of the overdue view.
///
/// All sets contain stable Sefaria refs.  They are disjoint: a ref that
/// appears in [overdue] will not appear in [dueToday] or [review], and so on.
class ProjectionResult {
  const ProjectionResult({
    required this.overdue,
    required this.dueToday,
    required this.review,
  });

  /// Units scheduled for dates strictly before today that have not been
  /// completed.  These are the "backlog" items.
  final Set<String> overdue;

  /// Units scheduled for today that have not been completed.
  final Set<String> dueToday;

  /// Review items due today (chazara / spaced-repetition).  This bucket is
  /// left empty by the pure projection — it requires stage-completion data
  /// that is computed by the engine.  Future waves may populate it.
  final Set<String> review;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectionResult &&
          _setsEqual(overdue, other.overdue) &&
          _setsEqual(dueToday, other.dueToday) &&
          _setsEqual(review, other.review);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(overdue),
    Object.hashAllUnordered(dueToday),
    Object.hashAllUnordered(review),
  );

  static bool _setsEqual(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  @override
  String toString() =>
      'ProjectionResult('
      'overdue=${overdue.length}, '
      'dueToday=${dueToday.length}, '
      'review=${review.length})';
}

// ---------------------------------------------------------------------------
// Self-paced schedule error
// ---------------------------------------------------------------------------

/// Thrown by [selfPacedSchedule] when no explicit pace has been configured.
///
/// Architecture §10.3: a self-paced track MUST have an explicit pace.  The
/// projection must NOT silently default or return 0 — it throws this error.
class MissingPaceError extends ArgumentError {
  MissingPaceError()
    : super(
        'Self-paced track has no explicit pace. '
        'The setup UI must force the user to set a pace before this '
        'projection runs (architecture §10.3). '
        'Do not supply a default — prompt the user instead.',
      );
}
