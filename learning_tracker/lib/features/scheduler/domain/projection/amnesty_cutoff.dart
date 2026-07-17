/// Pure reorder-amnesty cutoff computation (architecture §10.1).
///
/// Extracted from `scheduler_providers.dart` (AUD-scheduler-09) so both the
/// production amnesty filter and its regression tests exercise the same
/// code — a private, in-file helper cannot be imported by a test file, which
/// let `reorder_amnesty_test.dart` drift into hand-retyping the algorithm
/// instead of calling it.
///
/// This file is the domain layer: pure Dart, no Flutter, no Riverpod,
/// no Drift, no Firebase.
library;

/// Returns the day-level amnesty cutoff for [lastReorderAt]: midnight of
/// the device-local date on which the reorder occurred, encoded as
/// pseudo-UTC midnight (the same encoding [ScheduledUnit.date] uses).
///
/// Schedule entries are dated to UTC midnight of the unit's local day, while
/// `lastReorderAt` is a real instant (e.g. activation at 15:00 UTC).  A naive
/// `scheduledDate.isBefore(lastReorderAt)` would treat same-day schedule
/// entries as "before" the reorder and amnesty them — wiping today's overdue
/// for a track activated yesterday.  The amnesty rule (§10.1) is "items
/// scheduled on days strictly before the day of the reorder", so we normalize
/// to midnight of the device-local date here.
DateTime amnestyDayCutoffUtc(DateTime lastReorderAt) {
  final local = lastReorderAt.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}

/// Clamps [rawCutoff] to [anchor] for program tracks (architecture §10.1
/// back-date fix).
///
/// A freshly-enrolled program track has `lastReorderAt == creation day
/// (today)` while its [anchor] (`trackingStartDate`) is in the past.  The
/// raw cutoff would then amnesty the ENTIRE intended back-date window —
/// every back-dated daf scheduled before today gets silently stripped, so a
/// track started "4 days behind" shows no overdue.  Programs are
/// calendar-anchored (never user-reordered), so the cutoff is clamped to the
/// anchor: overdue on/after `trackingStartDate` is never amnestied, while a
/// genuine re-anchor (`anchor == today`) still yields no spurious overdue.
DateTime clampAmnestyCutoffToAnchor(DateTime rawCutoff, DateTime anchor) {
  return rawCutoff.isAfter(anchor) ? anchor : rawCutoff;
}
