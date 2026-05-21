/// The entity-kind taxonomy known to [MergeRouter].
///
/// Adding a new sync-able entity means:
///   1. add a constant here, and to [EntityKind.all] in order,
///   2. add a concrete `EntityMerger` subclass in a new file,
///   3. add one entry to the `MergeRouter` constructor's `mergers` map.
///
/// No other file in the project enumerates this taxonomy (verified by the
/// Story 25.13 acceptance test).
class EntityKind {
  const EntityKind._();

  static const completion = 'completion';
  static const streak = 'streak';
  static const learnerProfile = 'learner_profile';
  static const trackConfig = 'track_config';
  static const bookmark = 'bookmark';
  static const settings = 'settings';
  static const stageDefinition = 'stage_definition';
  static const profileProgram = 'profile_program';
  static const learningOrder = 'learning_order'; // W2.26 — closes C3/H3
  // W2.27 — closes M1
  static const goal = 'goal';
  static const learningLedger = 'learning_ledger';
  static const notificationSettings = 'notification_settings';
  static const gamificationSettings = 'gamification_settings';
  static const uiPreferences = 'ui_preferences';

  // W3.17 — tutor mode (S3 W3.38 adds the Firestore collection)
  static const tutorGrant = 'tutor_grant';

  // Phase 1 — study-day config enrolment in the sync pipeline.
  static const studyDayConfig = 'study_day_config';

  /// Deterministic enumeration order for tests and diagnostics.
  static const List<String> all = [
    completion,
    streak,
    learnerProfile,
    trackConfig,
    bookmark,
    settings,
    stageDefinition,
    profileProgram,
    learningOrder,
    goal,
    learningLedger,
    notificationSettings,
    gamificationSettings,
    uiPreferences,
    tutorGrant,
    studyDayConfig,
  ];
}

/// Per-entity merge strategy used by [MergeRouter] to apply pulled rows.
///
/// Implementations are intentionally sealed (only the seven listed in
/// [EntityKind.all] are valid). A future entity addition is a new file
/// plus one new router entry — no existing code edits required.
abstract class EntityMerger {
  /// The [EntityKind] this merger handles.
  String get kind;

  /// Apply the [rows] returned by `PullPipeline.fetchPage(...)` for the
  /// given [profileId]. Implementations decide LWW vs. event-log
  /// semantics via [MergeRules] + the injected [MergeStore].
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  });
}

/// Storage adapter every merger talks to.
///
/// Mergers do not touch Drift DAOs directly — they go through this seam so
/// (a) the merge logic is unit-testable without spinning up a database, and
/// (b) DAO churn during DNI-338 (BaseDao + TrackScope) cannot break merge
/// behaviour. A concrete `DriftMergeStore` will be wired up in DNI-335 once
/// the listener supervisor exists to drive sustained pulls.
///
/// All operations are profile-scoped — passing a row with mismatched
/// `profile_id` is a caller bug.
abstract class MergeStore {
  /// Read the current `updatedAt` for an LWW comparison. Returns `null`
  /// if no local row exists yet (in which case the remote row wins).
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  });

  /// Read the persisted Firestore server timestamp (`synced_at`) for
  /// `(kind, naturalKey)`. Used as the tie-breaker when client
  /// `updated_at` values are within ±5 s on two devices. Returns `null`
  /// when no row has been applied or the row carried no `synced_at`
  /// (legacy data / first sync).
  Future<DateTime?> currentSyncedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  });

  /// Persist the remote `updated_at` (and optional Firestore server
  /// timestamp `syncedAt`) after a successful merge. Called by every LWW
  /// merger immediately after [upsert].
  Future<void> persistUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime updatedAt,
    DateTime? syncedAt,
  });

  /// Phase-3 LWW gate: returns `true` when the remote row should overwrite
  /// the current local row.
  ///
  /// Rules (in order):
  ///   1. If `remoteUpdatedAt` is `null`, return `false` — we cannot decide
  ///      without a remote timestamp.
  ///   2. If `localUpdatedAt` is `null`, return `true` — no local row yet.
  ///   3. If `|local - remote| > 5 s`, the strict `remote > local`
  ///      comparison decides (local wins on ties).
  ///   4. Within the ±5 s clock-skew window, fall back to the server
  ///      timestamp (`syncedAt`). Remote wins iff its `syncedAt` is
  ///      strictly after the local-persisted `syncedAt`.
  ///   5. If `syncedAt` is missing or equal on both sides, prefer remote
  ///      (it has authoritatively reached the server; preserves
  ///      convergence).
  bool remoteIsNewer({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    DateTime? localSyncedAt,
    DateTime? remoteSyncedAt,
  });

  /// Upsert a row (LWW winners — the merger has already decided that the
  /// remote row should overwrite local).
  Future<void> upsert({
    required String kind,
    required int profileId,
    required Map<String, dynamic> fields,
  });

  /// Insert a row only if its natural key is not present locally — used
  /// for append-only event tables (completions, streak events). On a
  /// natural-key clash the remote row is silently dropped because the
  /// composite-UNIQUE invariant from DNI-323 already deduplicated it.
  Future<void> insertIfAbsent({
    required String kind,
    required int profileId,
    required String naturalKey,
    required Map<String, dynamic> fields,
  });
}
