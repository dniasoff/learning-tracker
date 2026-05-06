import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles all Firestore read/write operations for sync.
///
/// Collection structure (profile-scoped):
/// - `users/{uid}/learner_profiles/{profileId}/completions/{autoId}` - Completions (append-only)
/// - `users/{uid}/learner_profiles/{profileId}/bookmarks/{curriculumId}_{trackType}` - Bookmarks (LWW)
/// - `users/{uid}/learner_profiles/{profileId}/settings/{curriculumId}` - Settings (LWW)
/// - `users/{uid}/learner_profiles/{profileId}/goals/{id}` - Goals (LWW)
/// - `users/{uid}/learner_profiles/{profileId}/learning_ledger/{id}` - Lifetime / cumulative progress (append-only)
/// - `users/{uid}/learner_profiles/{profileId}/streak/data` - Streak (single doc)
/// - `users/{uid}/learner_profiles/{profileId}/notification_settings/preferences` - Notification preferences (LWW)
/// - `users/{uid}/learner_profiles/{profileId}/gamification_settings/config` -
///   Points config, `reward_settings` (milestones + unlocks). Milestone
///   `track_id: 0` means total-points (global) ladder; positive ids are
///   per-curriculum tracks. Document includes `schema_version` (see
///   [SyncEngine] gamification payload).
/// - `users/{uid}/learner_profiles/{profileId}/ui_preferences/data` - Locale, calendar, text display, learning-order prefs
/// - `users/{uid}/learner_profiles/{profileId}/active_curricula/data` - Active curricula
/// - `users/{uid}/learner_profiles/{profileId}/curriculum_tracks/{curriculumId}_{trackType}` - Track state + progress schema (LWW)
/// - `users/{uid}/profile/data` - User profile (account-level, not profile-scoped)
class FirestoreDataSource {
  FirestoreDataSource({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    this.profileId = 0,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  bool _profilePathChecked = false;
  bool _legacyProfilesMigrated = false;

  /// The active profile ID for Firestore path scoping.
  final int profileId;

  /// Create a datasource instance scoped to a different learner profile.
  ///
  /// Useful when flushing queued operations that were created under another
  /// profile before the user switched profiles.
  FirestoreDataSource forProfile(int targetProfileId) {
    return FirestoreDataSource(
      firestore: _firestore,
      auth: _auth,
      profileId: targetProfileId,
    );
  }

  /// Whether the current Firebase user is authenticated.
  ///
  /// Used by [SyncEngine] to skip Firestore operations before auth completes,
  /// avoiding PERMISSION_DENIED errors that cascade into permanent degradation.
  bool get isAuthenticated => _auth.currentUser != null;

  /// Get current user's Firestore document reference.
  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  /// Get the profile-scoped base document reference.
  /// All profile-scoped data lives under
  /// `users/{uid}/learner_profiles/{profileId}/`.
  DocumentReference<Map<String, dynamic>>? get _profileScopedDoc {
    return _userDoc?.collection('learner_profiles').doc(profileId.toString());
  }

  /// Legacy profile-scoped path used by older builds.
  DocumentReference<Map<String, dynamic>>? get _legacyProfileScopedDoc {
    return _userDoc?.collection('profiles').doc(profileId.toString());
  }

  /// Get profile subcollection reference (account-level, not profile-scoped).
  DocumentReference<Map<String, dynamic>>? get _profileDoc {
    return _userDoc?.collection('profile').doc('data');
  }

  /// Account-level collection of learner profiles (not profile-scoped).
  /// One doc per learner profile; doc id is the local profile id as a string.
  CollectionReference<Map<String, dynamic>>? get _learnerProfilesCollection {
    return _userDoc?.collection('learner_profiles');
  }

  /// Get completions subcollection reference (profile-scoped).
  CollectionReference<Map<String, dynamic>>? get _completionsCollection {
    return _profileScopedDoc?.collection('completions');
  }

  /// Get bookmarks subcollection reference (profile-scoped).
  CollectionReference<Map<String, dynamic>>? get _bookmarksCollection {
    return _profileScopedDoc?.collection('bookmarks');
  }

  /// Get settings subcollection reference (profile-scoped).
  CollectionReference<Map<String, dynamic>>? get _settingsCollection {
    return _profileScopedDoc?.collection('settings');
  }

  /// Get streak document reference (profile-scoped).
  DocumentReference<Map<String, dynamic>>? get _streakDoc {
    return _profileScopedDoc?.collection('streak').doc('data');
  }

  /// Notification settings document reference (profile-scoped).
  DocumentReference<Map<String, dynamic>>? get _notificationSettingsDoc {
    return _profileScopedDoc
        ?.collection('notification_settings')
        .doc('preferences');
  }

  /// Gamification settings document reference (profile-scoped).
  DocumentReference<Map<String, dynamic>>? get _gamificationSettingsDoc {
    return _profileScopedDoc?.collection('gamification_settings').doc('config');
  }

  /// UI preferences (locale, Hebrew calendar, text display, learning-order flag).
  DocumentReference<Map<String, dynamic>>? get _uiPreferencesDoc {
    return _profileScopedDoc?.collection('ui_preferences').doc('data');
  }

  Future<void> _ensureProfilePathReady() async {
    if (_profilePathChecked) return;
    _profilePathChecked = true;

    await _migrateAllLegacyProfilesIfNeeded();

    final target = _profileScopedDoc;
    final legacy = _legacyProfileScopedDoc;
    if (target == null || legacy == null) return;

    // Legacy path `users/{uid}/profiles/{profileId}` is often denied by
    // deployed rules (only `learner_profiles` is allowed). Skip migration
    // when reads fail so sync can still use `learner_profiles`.
    try {
      final legacySnapshot = await legacy.get();
      if (!legacySnapshot.exists) {
        return;
      }

      final targetSnapshot = await target.get();
      if (!targetSnapshot.exists) {
        await target.set({
          ...?legacySnapshot.data(),
          'id': profileId,
          'migrated_from_profiles': true,
          'migrated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      const subcollections = [
        'completions',
        'bookmarks',
        'settings',
        'goals',
        'profile_programs',
        'streak',
        'active_curricula',
        'curriculum_tracks',
        'notification_settings',
        'gamification_settings',
        'ui_preferences',
        'learning_ledger',
        'curriculum_imports',
      ];

      for (final sub in subcollections) {
        final legacyCol = legacy.collection(sub);
        final targetCol = target.collection(sub);
        final docs = await legacyCol.get();
        if (docs.docs.isEmpty) continue;

        for (final doc in docs.docs) {
          await targetCol.doc(doc.id).set(doc.data(), SetOptions(merge: true));
        }
        for (final doc in docs.docs) {
          await doc.reference.delete();
        }
      }

      await legacy.delete().catchError((_) {});
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return;
      }
      rethrow;
    }
  }

  /// One-time migration from deprecated `users/{uid}/profiles` to
  /// `users/{uid}/learner_profiles`. Rules often deny the legacy path; in that
  /// case we skip silently so [fetchLearnerProfiles] and sync continue.
  Future<void> _migrateAllLegacyProfilesIfNeeded() async {
    if (_legacyProfilesMigrated) return;

    final userDoc = _userDoc;
    if (userDoc == null) {
      _legacyProfilesMigrated = true;
      return;
    }

    try {
      final legacyProfiles = await userDoc.collection('profiles').get();
      if (legacyProfiles.docs.isEmpty) {
        _legacyProfilesMigrated = true;
        return;
      }

      const subcollections = [
        'completions',
        'bookmarks',
        'settings',
        'goals',
        'profile_programs',
        'streak',
        'active_curricula',
        'curriculum_tracks',
        'notification_settings',
        'gamification_settings',
        'ui_preferences',
        'learning_ledger',
        'curriculum_imports',
      ];

      for (final legacy in legacyProfiles.docs) {
        final profileDocId = legacy.id;
        final profileIntId = int.tryParse(profileDocId);
        final target = userDoc.collection('learner_profiles').doc(profileDocId);

        final targetSnapshot = await target.get();
        if (!targetSnapshot.exists) {
          await target.set({
            ...legacy.data(),
            if (profileIntId != null) 'id': profileIntId,
            'migrated_from_profiles': true,
            'migrated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        for (final sub in subcollections) {
          final legacyCol = legacy.reference.collection(sub);
          final targetCol = target.collection(sub);
          final docs = await legacyCol.get();
          if (docs.docs.isEmpty) continue;

          for (final doc in docs.docs) {
            await targetCol
                .doc(doc.id)
                .set(doc.data(), SetOptions(merge: true));
          }
          for (final doc in docs.docs) {
            await doc.reference.delete();
          }
        }

        await legacy.reference.delete().catchError((_) {});
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _legacyProfilesMigrated = true;
        return;
      }
      rethrow;
    }

    _legacyProfilesMigrated = true;
  }

  // ========== Profile Operations ==========

  /// Fetch user profile from Firestore.
  Future<Map<String, dynamic>?> fetchProfile() async {
    final doc = _profileDoc;
    if (doc == null) return null;

    final snapshot = await doc.get();
    return snapshot.data();
  }

  /// Push user profile to Firestore.
  Future<void> pushProfile(Map<String, dynamic> profileData) async {
    final doc = _profileDoc;
    if (doc == null) {
      throw Exception('User not authenticated');
    }

    await doc.set({
      ...profileData,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ========== Learner Profile Operations ==========

  /// Fetch all learner profiles for the current cloud account.
  /// Used on sign-in / new-device restore to rebuild the local profiles
  /// table so the profile picker has something to show.
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async {
    await _migrateAllLegacyProfilesIfNeeded();
    final collection = _learnerProfilesCollection;
    if (collection == null) return const [];

    final snapshot = await collection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {...data, 'id': int.tryParse(doc.id) ?? data['id']};
    }).toList();
  }

  /// Push a learner profile to Firestore (LWW by updated_at).
  Future<void> pushLearnerProfile(Map<String, dynamic> profileData) async {
    final collection = _learnerProfilesCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    final id = profileData['id'];
    if (id == null) {
      throw ArgumentError('Learner profile must include id');
    }

    await collection.doc(id.toString()).set({
      ...profileData,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Delete a learner profile from Firestore.
  Future<void> deleteLearnerProfile(int profileId) async {
    final collection = _learnerProfilesCollection;
    if (collection == null) return;
    final profileDoc = collection.doc(profileId.toString());

    const profileSubcollections = [
      'completions',
      'bookmarks',
      'settings',
      'goals',
      'rewards',
      'learning_ledger',
      'active_curricula',
      'curriculum_imports',
      'curriculum_tracks',
      'profile_programs',
      'notification_settings',
      'gamification_settings',
      'ui_preferences',
      'streak',
    ];

    // Firestore does not cascade subcollection deletes. Remove descendants
    // first so profile deletion is complete and does not leave orphaned docs.
    for (final sub in profileSubcollections) {
      final subSnapshot = await profileDoc.collection(sub).get();
      for (final doc in subSnapshot.docs) {
        await doc.reference.delete();
      }
    }

    await profileDoc.delete();
  }

  // ========== Completions Operations ==========

  /// Push a completion to Firestore (append-only).
  Future<void> pushCompletion(Map<String, dynamic> completionData) async {
    await _ensureProfilePathReady();
    final collection = _completionsCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.add({
      ...completionData,
      'synced_at': FieldValue.serverTimestamp(),
    });
  }

  /// Page size for paginated Firestore fetches.
  static const int defaultPageSize = 500;

  /// Fetch all completions from Firestore with pagination.
  Future<List<Map<String, dynamic>>> fetchCompletions({
    int pageSize = defaultPageSize,
  }) async {
    await _ensureProfilePathReady();
    final collection = _completionsCollection;
    if (collection == null) return [];

    final results = <Map<String, dynamic>>[];
    var query = collection.orderBy(FieldPath.documentId).limit(pageSize);

    while (true) {
      final snapshot = await query.get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        results.add({...data, 'firestore_id': doc.id});
      }
      if (snapshot.docs.length < pageSize) break;
      query = collection
          .orderBy(FieldPath.documentId)
          .startAfterDocument(snapshot.docs.last)
          .limit(pageSize);
    }

    return results;
  }

  /// Listen to real-time completions updates.
  Stream<List<Map<String, dynamic>>> listenToCompletions() {
    final collection = _completionsCollection;
    if (collection == null) {
      return Stream.value([]);
    }

    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {...data, 'firestore_id': doc.id};
      }).toList();
    });
  }

  // ========== Learning Ledger Operations ==========

  /// Get learning ledger subcollection reference (profile-scoped).
  CollectionReference<Map<String, dynamic>>? get _ledgerCollection {
    return _profileScopedDoc?.collection('learning_ledger');
  }

  /// Push a ledger entry to Firestore (append-only).
  Future<void> pushLedgerEntry(Map<String, dynamic> entryData) async {
    final collection = _ledgerCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.add({
      ...entryData,
      'synced_at': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch all ledger entries from Firestore with pagination.
  Future<List<Map<String, dynamic>>> fetchLedgerEntries({
    int pageSize = defaultPageSize,
  }) async {
    await _ensureProfilePathReady();
    final collection = _ledgerCollection;
    if (collection == null) return [];

    return _fetchPaginated(collection, pageSize: pageSize);
  }

  /// Listen to real-time ledger entry updates.
  Stream<List<Map<String, dynamic>>> listenToLedgerEntries() {
    final collection = _ledgerCollection;
    if (collection == null) {
      return Stream.value([]);
    }

    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {...data, 'firestore_id': doc.id};
      }).toList();
    });
  }

  // ========== Bookmarks Operations ==========

  /// Push a bookmark to Firestore (last-write-wins with UTC timestamp).
  Future<void> pushBookmark(Map<String, dynamic> bookmarkData) async {
    await _ensureProfilePathReady();
    final collection = _bookmarksCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    // Deterministic ID: {curriculumId}_{trackType}
    final curriculumId = bookmarkData['curriculum_id'];
    final trackType = bookmarkData['track_type'];
    final docId = '${curriculumId}_$trackType';

    await collection.doc(docId).set({
      ...bookmarkData,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch all bookmarks from Firestore with pagination.
  Future<List<Map<String, dynamic>>> fetchBookmarks({
    int pageSize = defaultPageSize,
  }) async {
    await _ensureProfilePathReady();
    final collection = _bookmarksCollection;
    if (collection == null) return [];

    return _fetchPaginated(collection, pageSize: pageSize);
  }

  /// Listen to real-time bookmark updates.
  Stream<List<Map<String, dynamic>>> listenToBookmarks() {
    final collection = _bookmarksCollection;
    if (collection == null) {
      return Stream.value([]);
    }

    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // ========== Settings Operations ==========

  /// Push settings to Firestore (last-write-wins with UTC timestamp).
  Future<void> pushSettings(Map<String, dynamic> settingsData) async {
    await _ensureProfilePathReady();
    final collection = _settingsCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    // Deterministic ID: {curriculumId}
    final curriculumId = settingsData['curriculum_id'];
    final docId = curriculumId as String;

    await collection.doc(docId).set({
      ...settingsData,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch all settings from Firestore with pagination.
  Future<List<Map<String, dynamic>>> fetchSettings({
    int pageSize = defaultPageSize,
  }) async {
    await _ensureProfilePathReady();
    final collection = _settingsCollection;
    if (collection == null) return [];

    return _fetchPaginated(collection, pageSize: pageSize);
  }

  /// Listen to real-time settings updates.
  Stream<List<Map<String, dynamic>>> listenToSettings() {
    final collection = _settingsCollection;
    if (collection == null) {
      return Stream.value([]);
    }

    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // ========== Streak Operations ==========

  /// Fetch streak data from Firestore.
  Future<Map<String, dynamic>?> fetchStreak() async {
    await _ensureProfilePathReady();
    final doc = _streakDoc;
    if (doc == null) return null;

    final snapshot = await doc.get();
    return snapshot.data();
  }

  /// Push streak data to Firestore (last-write-wins).
  Future<void> pushStreak(Map<String, dynamic> streakData) async {
    await _ensureProfilePathReady();
    final doc = _streakDoc;
    if (doc == null) {
      throw Exception('User not authenticated');
    }

    await doc.set({
      ...streakData,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Listen to real-time streak updates.
  Stream<Map<String, dynamic>?> listenToStreak() {
    final doc = _streakDoc;
    if (doc == null) {
      return Stream.value(null);
    }

    return doc.snapshots().map((snapshot) => snapshot.data());
  }

  // ========== Notification Settings Operations ==========

  /// Push notification preferences to Firestore (last-write-wins).
  Future<void> pushNotificationSettings(
    Map<String, dynamic> notificationSettings,
  ) async {
    await _ensureProfilePathReady();
    final doc = _notificationSettingsDoc;
    if (doc == null) {
      throw Exception('User not authenticated');
    }

    await doc.set({
      ...notificationSettings,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch notification preferences from Firestore.
  Future<Map<String, dynamic>?> fetchNotificationSettings() async {
    await _ensureProfilePathReady();
    final doc = _notificationSettingsDoc;
    if (doc == null) return null;

    final snapshot = await doc.get();
    return snapshot.data();
  }

  /// Listen to real-time notification preference updates.
  Stream<Map<String, dynamic>?> listenToNotificationSettings() {
    final doc = _notificationSettingsDoc;
    if (doc == null) {
      return Stream.value(null);
    }

    return doc.snapshots().map((snapshot) => snapshot.data());
  }

  // ========== Gamification Settings Operations ==========

  /// Push gamification settings to Firestore (last-write-wins).
  Future<void> pushGamificationSettings(
    Map<String, dynamic> gamificationSettings,
  ) async {
    await _ensureProfilePathReady();
    final doc = _gamificationSettingsDoc;
    if (doc == null) {
      throw Exception('User not authenticated');
    }

    await doc.set({
      ...gamificationSettings,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch gamification settings from Firestore.
  Future<Map<String, dynamic>?> fetchGamificationSettings() async {
    await _ensureProfilePathReady();
    final doc = _gamificationSettingsDoc;
    if (doc == null) return null;

    final snapshot = await doc.get();
    return snapshot.data();
  }

  /// Listen to real-time gamification settings updates.
  Stream<Map<String, dynamic>?> listenToGamificationSettings() {
    final doc = _gamificationSettingsDoc;
    if (doc == null) {
      return Stream.value(null);
    }
    return doc.snapshots().map((snapshot) => snapshot.data());
  }

  // ========== UI Preferences (locale, calendar, text display) ==========

  /// Push UI preferences to Firestore (last-write-wins).
  Future<void> pushUiPreferences(Map<String, dynamic> uiPreferences) async {
    await _ensureProfilePathReady();
    final doc = _uiPreferencesDoc;
    if (doc == null) {
      throw Exception('User not authenticated');
    }

    await doc.set({
      ...uiPreferences,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch UI preferences from Firestore.
  Future<Map<String, dynamic>?> fetchUiPreferences() async {
    await _ensureProfilePathReady();
    final doc = _uiPreferencesDoc;
    if (doc == null) return null;

    final snapshot = await doc.get();
    return snapshot.data();
  }

  /// Listen to real-time UI preference updates.
  Stream<Map<String, dynamic>?> listenToUiPreferences() {
    final doc = _uiPreferencesDoc;
    if (doc == null) {
      return Stream.value(null);
    }
    return doc.snapshots().map((snapshot) => snapshot.data());
  }

  // ========== Goal Operations ==========

  /// Fetch all goals from Firestore with pagination.
  Future<List<Map<String, dynamic>>> fetchGoals({
    int pageSize = defaultPageSize,
  }) async {
    await _ensureProfilePathReady();
    final collection = _profileScopedDoc?.collection('goals');
    if (collection == null) return [];

    return _fetchPaginated(collection, pageSize: pageSize);
  }

  /// Push a goal to Firestore (last-write-wins).
  Future<void> pushGoal(Map<String, dynamic> goalData) async {
    await _ensureProfilePathReady();
    final collection = _profileScopedDoc?.collection('goals');
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    final id = goalData['id']?.toString();
    if (id == null) {
      throw Exception('Goal must have an id');
    }

    await collection.doc(id).set({
      ...goalData,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ========== Goal Listener ==========

  /// Listen to real-time goal updates.
  Stream<List<Map<String, dynamic>>> listenToGoals() {
    final collection = _profileScopedDoc?.collection('goals');
    if (collection == null) {
      return Stream.value([]);
    }

    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // ========== Profile Program Operations ==========

  /// Get profile-program assignments collection (profile-scoped).
  CollectionReference<Map<String, dynamic>>? get _profileProgramsCollection {
    return _profileScopedDoc?.collection('profile_programs');
  }

  /// Push a profile-program assignment to Firestore (LWW).
  Future<void> pushProfileProgram(
    Map<String, dynamic> profileProgramData,
  ) async {
    await _ensureProfilePathReady();
    final collection = _profileProgramsCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    final curriculumId = profileProgramData['curriculum_id'] as String?;
    if (curriculumId == null || curriculumId.isEmpty) {
      throw ArgumentError('Profile program must include curriculum_id');
    }

    await collection.doc(curriculumId).set({
      ...profileProgramData,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Deletes profile-program doc when learner switches to self-paced.
  Future<void> deleteProfileProgramForCurriculum(String curriculumId) async {
    await _ensureProfilePathReady();
    final collection = _profileProgramsCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }
    if (curriculumId.isEmpty) {
      throw ArgumentError('curriculumId must not be empty');
    }
    await collection.doc(curriculumId).delete();
  }

  /// Fetch profile-program assignments from Firestore.
  Future<List<Map<String, dynamic>>> fetchProfilePrograms({
    int pageSize = defaultPageSize,
  }) async {
    await _ensureProfilePathReady();
    final collection = _profileProgramsCollection;
    if (collection == null) return [];

    return _fetchPaginated(collection, pageSize: pageSize);
  }

  /// Listen to real-time profile-program assignment updates.
  Stream<List<Map<String, dynamic>>> listenToProfilePrograms() {
    final collection = _profileProgramsCollection;
    if (collection == null) {
      return Stream.value([]);
    }

    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // ========== Active Curricula Operations ==========

  /// Get active curricula document reference (profile-scoped).
  DocumentReference<Map<String, dynamic>>? get _activeCurriculaDoc {
    return _profileScopedDoc?.collection('active_curricula').doc('data');
  }

  /// Push active curricula list to Firestore.
  Future<void> pushActiveCurricula(List<String> activeCurricula) async {
    await _ensureProfilePathReady();
    final doc = _activeCurriculaDoc;
    if (doc == null) {
      throw Exception('User not authenticated');
    }

    await doc.set({
      'curricula': activeCurricula,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch active curricula list from Firestore.
  Future<List<String>> fetchActiveCurricula() async {
    await _ensureProfilePathReady();
    final doc = _activeCurriculaDoc;
    if (doc == null) return [];

    final snapshot = await doc.get();
    final data = snapshot.data();
    if (data == null) return [];

    final curricula = data['curricula'];
    if (curricula is List) {
      return curricula.cast<String>();
    }
    return [];
  }

  /// Listen to real-time active curricula updates.
  Stream<List<String>> listenToActiveCurricula() {
    final doc = _activeCurriculaDoc;
    if (doc == null) {
      return Stream.value([]);
    }

    return doc.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return [];

      final curricula = data['curricula'];
      if (curricula is List) {
        return curricula.cast<String>();
      }
      return [];
    });
  }

  // ========== Curriculum Tracks Operations ==========

  /// Get curriculum-tracks subcollection reference (profile-scoped).
  CollectionReference<Map<String, dynamic>>? get _curriculumTracksCollection {
    return _profileScopedDoc?.collection('curriculum_tracks');
  }

  /// Push a curriculum track to Firestore (LWW, keyed by curriculumId_trackType).
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {
    await _ensureProfilePathReady();
    final collection = _curriculumTracksCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    final curriculumId = trackData['curriculum_id'];
    final trackType = trackData['track_type'];
    final docId = '${curriculumId}_$trackType';

    await collection.doc(docId).set({
      ...trackData,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch all curriculum tracks from Firestore with pagination.
  Future<List<Map<String, dynamic>>> fetchCurriculumTracks({
    int pageSize = defaultPageSize,
  }) async {
    await _ensureProfilePathReady();
    final collection = _curriculumTracksCollection;
    if (collection == null) return [];

    return _fetchPaginated(collection, pageSize: pageSize);
  }

  /// Listen to real-time curriculum-track updates.
  Stream<List<Map<String, dynamic>>> listenToCurriculumTracks() {
    final collection = _curriculumTracksCollection;
    if (collection == null) {
      return Stream.value([]);
    }

    return collection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // ========== Curriculum Import Metadata Operations ==========

  /// Push curriculum import metadata to Firestore.
  ///
  /// This allows other devices to detect that a curriculum has already been
  /// imported and skip re-import from Sefaria.
  Future<void> pushCurriculumImportMetadata(
    Map<String, dynamic> metadata,
  ) async {
    await _ensureProfilePathReady();
    final collection = _profileScopedDoc?.collection('curriculum_imports');
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    final curriculumId = metadata['curriculum_id'] as String;
    await collection.doc(curriculumId).set({
      ...metadata,
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch curriculum import metadata from Firestore.
  Future<Map<String, dynamic>?> fetchCurriculumImportMetadata(
    String curriculumId,
  ) async {
    await _ensureProfilePathReady();
    final collection = _profileScopedDoc?.collection('curriculum_imports');
    if (collection == null) return null;

    final snapshot = await collection.doc(curriculumId).get();
    return snapshot.data();
  }

  // ========== Pagination Helper ==========

  /// Generic paginated fetch for any Firestore collection.
  Future<List<Map<String, dynamic>>> _fetchPaginated(
    CollectionReference<Map<String, dynamic>> collection, {
    required int pageSize,
  }) async {
    final results = <Map<String, dynamic>>[];
    var query = collection.orderBy(FieldPath.documentId).limit(pageSize);

    while (true) {
      final snapshot = await query.get();
      for (final doc in snapshot.docs) {
        results.add(doc.data());
      }
      if (snapshot.docs.length < pageSize) break;
      query = collection
          .orderBy(FieldPath.documentId)
          .startAfterDocument(snapshot.docs.last)
          .limit(pageSize);
    }

    return results;
  }
}
