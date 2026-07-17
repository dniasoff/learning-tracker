/// Pure overdue projection module.
///
/// Public API:
///
/// Types:
///   [ScheduledUnit]     — one unit (date + sefariaRef) in a track's schedule.
///   [StudyDayPattern]   — the set of ISO weekdays on which the learner studies.
///   [ProjectionResult]  — the three-bucket result: overdue / dueToday / review.
///   [MissingPaceError]  — thrown when a self-paced track has no pace set.
///
/// Functions:
///   [programSchedule]            — build the schedule for a program track.
///   [selfPacedSchedule]          — build the schedule for a self-paced track.
///   [elapsedStudyDays]           — count study days in [anchor, today).
///   [project]                    — compute overdue / dueToday / review from a
///                                 schedule and a completion set.
///   [amnestyDayCutoffUtc]        — day-level reorder-amnesty cutoff
///                                 (architecture §10.1).
///   [clampAmnestyCutoffToAnchor] — clamp the amnesty cutoff to a program's
///                                 anchor (§10.1 back-date fix).
///
/// Layering: pure Dart domain layer — no Flutter, Riverpod, Drift, or Firebase.
library;

export 'amnesty_cutoff.dart'
    show amnestyDayCutoffUtc, clampAmnestyCutoffToAnchor;
export 'overdue_projection.dart' show project;
export 'overdue_schedule.dart'
    show elapsedStudyDays, programSchedule, selfPacedSchedule;
export 'overdue_types.dart'
    show MissingPaceError, ProjectionResult, ScheduledUnit, StudyDayPattern;
