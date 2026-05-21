/// Thin write-only facade extracted from [SyncEngine] during DNI-333 Phase 6.
///
/// External code (repositories, services outside `lib/features/sync/data/`)
/// depends only on this interface rather than the concrete [SyncEngine].
/// That keeps the monolithic implementation hidden behind
/// `lib/features/sync/data/` while the full decomposition continues.
///
/// **Contract:** every method is a no-op when the caller holds `null`
/// (local-born accounts never instantiate a facade).
abstract class SyncWriteFacade {
  /// Rebuild and push the gamification-settings snapshot for the active profile.
  Future<void> pushGamificationSettingsSnapshot();

  /// Rebuild and push the UI-preferences snapshot for the active profile.
  ///
  /// Reads locale, Hebrew-calendar, text-display and learning-order preferences
  /// from [SharedPreferences] and enqueues them for cloud push.
  Future<void> pushUiPreferencesSnapshot();

  /// Push a bookmark to Firestore after a local write.
  Future<void> pushBookmark(Map<String, dynamic> bookmark);

  /// Push settings (stage configs, study-day patterns, …) to Firestore after
  /// a local write.
  Future<void> pushSettings(Map<String, dynamic> settings);

  /// Push a goal to Firestore after a local write. Routes to the `goals`
  /// subcollection — the pull-side listener (`fetchGoals` /
  /// `_onGoalsUpdate`) subscribes to that exact path, so goals MUST NOT be
  /// piggybacked on [pushSettings] (which targets the `settings`
  /// subcollection and never reaches the goals listener — historic bug,
  /// fixed 2026-05-19).
  Future<void> pushGoal(Map<String, dynamic> goal);

  /// Delete a goal document in Firestore. Caller passes the deterministic
  /// `firestore_id` inside the payload so the outbox dispatcher can call
  /// `FirestoreGateway.deleteGoal`.
  Future<void> deleteGoal(Map<String, dynamic> payload);

  /// Push curriculum-track state to Firestore after a local write.
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData);

  /// Push a re-ordered learning-order list for a curriculum.
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  });

  /// Push a learner profile record to Firestore.
  Future<void> pushLearnerProfile(Map<String, dynamic> profile);

  /// Delete a learner profile from Firestore (tombstones locally first).
  Future<void> deleteLearnerProfile(int profileId);

  /// Plan §F Phase 5 deliverable 6 — push stage definitions via the
  /// dedicated `stage_definition` outbox kind. Replaces the legacy
  /// `pushSettings` piggyback so the gateway can write the correct
  /// `{trackId}_{stageOrder}` doc id per stage.
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  });

  /// Plan §F Phase 1 — push a study-day config record to Firestore after a
  /// local write. The deterministic doc id is derived inside the gateway
  /// from `curriculum_id`, `day_of_week`, and `track_id` so repeated writes
  /// for the same composite key are idempotent.
  Future<void> pushStudyDayConfig(Map<String, dynamic> payload);
}
