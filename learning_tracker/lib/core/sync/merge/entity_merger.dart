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
