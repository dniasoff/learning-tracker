/// Shared constants for completion-event semantics.
///
/// These constants are used across domain services and providers to identify
/// special-purpose timestamps written by the bulk-prior completion pipeline.
library;

/// The sentinel [DateTime] used by [BulkPriorCompletionService] to mark items
/// that were learned before this app was installed ("bulk-prior" tier).
///
/// Matches `DateTime.utc(2000, 1, 1).millisecondsSinceEpoch`.
///
/// Compared by millisecondsSinceEpoch so timezone normalisation does not
/// cause false positives.
///
/// Any completion row with `completedAt.millisecondsSinceEpoch == kBulkPriorSentinelMs`
/// is a bulk-prior import and MUST be excluded from "live activity" aggregations
/// such as daily-completion bar charts and streak calculations.
const int kBulkPriorSentinelMs =
    946684800000; // DateTime.utc(2000, 1, 1).millisecondsSinceEpoch

/// [DateTime] representation of [kBulkPriorSentinelMs].
///
/// Prefer comparing via [kBulkPriorSentinelMs]/`millisecondsSinceEpoch`
/// where possible — a sentinel [DateTime] that has round-tripped through
/// Firestore or Drift can carry a different `isUtc` flag than this
/// instance, which breaks a plain `==`/object comparison. This value is
/// provided for call sites that need the [DateTime] itself, e.g. to stamp
/// `completedAt` when writing a bulk-prior completion, or via
/// `toUtc().isAtSameMomentAs(...)` for flag-independent comparisons.
final DateTime kBulkPriorSentinelDate = DateTime.utc(2000, 1, 1);
