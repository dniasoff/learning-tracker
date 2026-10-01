part of 'learning_event.dart';

/// AD-31 effective instant: `original_recorded_at ?? recorded_at`, in UTC.
///
/// This is the ONLY event-time accessor for rule code — lock (AD-36),
/// `streakDay` / `catchUpWindow` (AD-40), earning order (AD-50), review
/// schedule (AD-35), siyum and history order all read it. [LearningEvent]
/// exposes no public `recordedAt` getter.
DateTime effectiveAt(LearningEvent e) => e._originalRecordedAt ?? e._recordedAt;

/// The raw `recorded_at` instant, for the AD-54 clock-skew rule ONLY
/// (`recorded_at <= request.time + 10 min`).
///
/// Do not call this from any other rule: an undo copy, un-learn re-issue or
/// import carries `original_recorded_at`, and every other rule must see
/// that instant through [effectiveAt] instead.
DateTime rawRecordedAtForSkewRule(LearningEvent e) => e._recordedAt;
