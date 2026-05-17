import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';

/// Adapter that translates the legacy [FirestoreDataSource] interface into
/// [FirestoreGateway] calls.
///
/// **This file must not import `package:cloud_firestore` directly** — the
/// gateway is the only allowed consumer of Firestore types (Story 25.12
/// AC1). All previous direct Firestore calls have been forwarded to
/// [FirestoreGateway] methods added in DNI-333.
///
/// Kept alive because [SyncEngine] still depends on it. It will be deleted
/// once [SyncEngine] is fully migrated (post DNI-333 clean-up).
class FirestoreDataSource {
  FirestoreDataSource({
    required FirestoreGateway gateway,
    required AuthRepository auth,
    this.profileId = 0,
  }) : _gateway = gateway,
       _auth = auth;

  final FirestoreGateway _gateway;
  final AuthRepository _auth;

  /// The active profile ID for Firestore path scoping.
  final int profileId;

  static const int defaultPageSize = 100;

  /// Create a datasource instance scoped to a different learner profile.
  FirestoreDataSource forProfile(int targetProfileId) {
    return FirestoreDataSource(
      gateway: _gateway,
      auth: _auth,
      profileId: targetProfileId,
    );
  }

  /// Whether the current Firebase user is authenticated.
  bool get isAuthenticated => _auth.currentUser != null;

  // ========== Profile Operations ==========

  Future<Map<String, dynamic>?> fetchProfile() async {
    return _gateway.fetchDocument(
      profileId: profileId,
      collection: 'profile',
      docId: 'data',
    );
  }

  Future<void> pushProfile(Map<String, dynamic> profileData) async {
    await _gateway.pushAccountProfile(data: profileData);
  }

  // ========== Learner Profile Operations ==========

  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async {
    return _gateway.fetchLearnerProfiles();
  }

  Future<void> pushLearnerProfile(Map<String, dynamic> profileData) async {
    final id = profileData['id'];
    final pid = id is int
        ? id
        : int.tryParse(id?.toString() ?? '') ?? profileId;
    await _gateway.pushLearnerProfile(profileId: pid, data: profileData);
  }

  Future<void> deleteLearnerProfile(int targetProfileId) async {
    await _gateway.deleteLearnerProfile(targetProfileId);
  }

  Future<void> deleteCurriculumTrack({
    required String curriculumId,
    required String trackType,
  }) async {
    // Not directly available in gateway — no-op (handled by gateway on push side)
  }

  // ========== Completions Operations ==========

  Future<List<Map<String, dynamic>>> fetchCompletions({
    int pageSize = defaultPageSize,
  }) async {
    return _gateway.fetchAll(profileId: profileId, collection: 'completions');
  }

  Stream<List<Map<String, dynamic>>> listenToCompletions() {
    return _gateway.listenToCollection(
      profileId: profileId,
      collection: 'completions',
    );
  }

  Future<void> pushCompletion(Map<String, dynamic> completionData) async {
    await _gateway.pushCompletion(profileId: profileId, data: completionData);
  }

  // ========== Learning Ledger Operations ==========

  Future<void> pushLedgerEntry(Map<String, dynamic> entryData) async {
    await _gateway.pushLedgerEntry(profileId: profileId, data: entryData);
  }

  Future<List<Map<String, dynamic>>> fetchLedgerEntries({
    int pageSize = defaultPageSize,
  }) async {
    return _gateway.fetchAll(
      profileId: profileId,
      collection: 'learning_ledger',
    );
  }

  Stream<List<Map<String, dynamic>>> listenToLedgerEntries() {
    return _gateway.listenToCollection(
      profileId: profileId,
      collection: 'learning_ledger',
    );
  }

  // ========== Bookmarks Operations ==========

  Future<void> pushBookmark(Map<String, dynamic> bookmarkData) async {
    await _gateway.pushBookmark(profileId: profileId, data: bookmarkData);
  }

  Future<List<Map<String, dynamic>>> fetchBookmarks({
    int pageSize = defaultPageSize,
  }) async {
    return _gateway.fetchAll(profileId: profileId, collection: 'bookmarks');
  }

  Stream<List<Map<String, dynamic>>> listenToBookmarks() {
    return _gateway.listenToCollection(
      profileId: profileId,
      collection: 'bookmarks',
    );
  }

  // ========== Settings Operations ==========

  Future<void> pushSettings(Map<String, dynamic> settingsData) async {
    await _gateway.pushSettings(profileId: profileId, data: settingsData);
  }

  Future<List<Map<String, dynamic>>> fetchSettings({
    int pageSize = defaultPageSize,
  }) async {
    return _gateway.fetchAll(profileId: profileId, collection: 'settings');
  }

  Stream<List<Map<String, dynamic>>> listenToSettings() {
    return _gateway.listenToCollection(
      profileId: profileId,
      collection: 'settings',
    );
  }

  // ========== Streak Operations ==========

  Future<Map<String, dynamic>?> fetchStreak() async {
    return _gateway.fetchDocument(
      profileId: profileId,
      collection: 'streak',
      docId: 'data',
    );
  }

  Future<void> pushStreak(Map<String, dynamic> streakData) async {
    await _gateway.pushStreak(profileId: profileId, data: streakData);
  }

  Stream<Map<String, dynamic>?> listenToStreak() {
    return _gateway.listenToDocument(
      profileId: profileId,
      collection: 'streak',
      docId: 'data',
    );
  }

  // ========== Notification Settings Operations ==========

  Future<void> pushNotificationSettings(
    Map<String, dynamic> notificationSettings,
  ) async {
    await _gateway.pushNotificationSettings(
      profileId: profileId,
      data: notificationSettings,
    );
  }

  Future<Map<String, dynamic>?> fetchNotificationSettings() async {
    return _gateway.fetchDocument(
      profileId: profileId,
      collection: 'notification_settings',
      docId: 'preferences',
    );
  }

  Stream<Map<String, dynamic>?> listenToNotificationSettings() {
    return _gateway.listenToDocument(
      profileId: profileId,
      collection: 'notification_settings',
      docId: 'preferences',
    );
  }

  // ========== Gamification Settings Operations ==========

  Future<void> pushGamificationSettings(
    Map<String, dynamic> gamificationSettings,
  ) async {
    await _gateway.pushGamificationSettings(
      profileId: profileId,
      data: gamificationSettings,
    );
  }

  Future<Map<String, dynamic>?> fetchGamificationSettings() async {
    return _gateway.fetchDocument(
      profileId: profileId,
      collection: 'gamification_settings',
      docId: 'config',
    );
  }

  Stream<Map<String, dynamic>?> listenToGamificationSettings() {
    return _gateway.listenToDocument(
      profileId: profileId,
      collection: 'gamification_settings',
      docId: 'config',
    );
  }

  // ========== UI Preferences Operations ==========

  Future<void> pushUiPreferences(Map<String, dynamic> uiPreferences) async {
    await _gateway.pushUiPreferences(profileId: profileId, data: uiPreferences);
  }

  Future<Map<String, dynamic>?> fetchUiPreferences() async {
    return _gateway.fetchDocument(
      profileId: profileId,
      collection: 'ui_preferences',
      docId: 'data',
    );
  }

  Stream<Map<String, dynamic>?> listenToUiPreferences() {
    return _gateway.listenToDocument(
      profileId: profileId,
      collection: 'ui_preferences',
      docId: 'data',
    );
  }

  // ========== Goal Operations ==========

  Future<List<Map<String, dynamic>>> fetchGoals({
    int pageSize = defaultPageSize,
  }) async {
    return _gateway.fetchAll(profileId: profileId, collection: 'goals');
  }

  Future<void> pushGoal(Map<String, dynamic> goalData) async {
    await _gateway.pushGoal(profileId: profileId, data: goalData);
  }

  Stream<List<Map<String, dynamic>>> listenToGoals() {
    return _gateway.listenToCollection(
      profileId: profileId,
      collection: 'goals',
    );
  }

  // ========== Profile Program Operations ==========

  Future<void> pushProfileProgram(
    Map<String, dynamic> profileProgramData,
  ) async {
    await _gateway.pushProfileProgram(
      profileId: profileId,
      data: profileProgramData,
    );
  }

  Future<void> deleteProfileProgramForCurriculum(String curriculumId) async {
    await _gateway.removeProfileProgramAssignment(
      profileId: profileId,
      curriculumStorageKey: curriculumId,
    );
  }

  Future<List<Map<String, dynamic>>> fetchProfilePrograms({
    int pageSize = defaultPageSize,
  }) async {
    return _gateway.fetchAll(
      profileId: profileId,
      collection: 'profile_programs',
    );
  }

  Stream<List<Map<String, dynamic>>> listenToProfilePrograms() {
    return _gateway.listenToCollection(
      profileId: profileId,
      collection: 'profile_programs',
    );
  }

  // ========== Curriculum Tracks Operations ==========

  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {
    await _gateway.pushTrack(profileId: profileId, data: trackData);
  }

  Future<List<Map<String, dynamic>>> fetchCurriculumTracks({
    int pageSize = defaultPageSize,
  }) async {
    return _gateway.fetchAll(
      profileId: profileId,
      collection: 'curriculum_tracks',
    );
  }

  Stream<List<Map<String, dynamic>>> listenToCurriculumTracks() {
    return _gateway.listenToCollection(
      profileId: profileId,
      collection: 'curriculum_tracks',
    );
  }

  // ========== Curriculum Import Metadata Operations ==========

  Future<void> pushCurriculumImportMetadata(
    Map<String, dynamic> metadata,
  ) async {
    await _gateway.pushCurriculumImportMetadata(
      profileId: profileId,
      data: metadata,
    );
  }

  Future<Map<String, dynamic>?> fetchCurriculumImportMetadata(
    String curriculumId,
  ) async {
    return _gateway.fetchDocument(
      profileId: profileId,
      collection: 'curriculum_imports',
      docId: curriculumId,
    );
  }

  // ========== Learning Order Operations ==========

  Future<void> pushLearningOrderItem(Map<String, dynamic> itemData) async {
    await _gateway.pushLearningOrder(profileId: profileId, data: itemData);
  }

  Future<List<Map<String, dynamic>>> fetchLearningOrder({
    int pageSize = defaultPageSize,
  }) async {
    return _gateway.fetchAll(
      profileId: profileId,
      collection: 'learning_order',
    );
  }

  Stream<List<Map<String, dynamic>>> listenToLearningOrder() {
    return _gateway.listenToCollection(
      profileId: profileId,
      collection: 'learning_order',
    );
  }
}
