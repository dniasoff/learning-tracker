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

  /// Push a bookmark to Firestore after a local write.
  Future<void> pushBookmark(Map<String, dynamic> bookmark);

  /// Push settings (goals, stage configs, …) to Firestore after a local write.
  Future<void> pushSettings(Map<String, dynamic> settings);

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
}
