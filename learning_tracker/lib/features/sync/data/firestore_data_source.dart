import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles all Firestore read/write operations for sync.
///
/// Collection structure (profile-scoped per story 15.11):
/// - `users/{uid}/profiles/{profileId}/completions/{autoId}` - Completions (append-only)
/// - `users/{uid}/profiles/{profileId}/bookmarks/{curriculumId}_{trackType}` - Bookmarks (LWW)
/// - `users/{uid}/profiles/{profileId}/settings/{curriculumId}` - Settings (LWW)
/// - `users/{uid}/profiles/{profileId}/goals/{id}` - Goals (LWW)
/// - `users/{uid}/profiles/{profileId}/rewards/{id}` - Rewards (LWW)
/// - `users/{uid}/profiles/{profileId}/streak/data` - Streak (single doc)
/// - `users/{uid}/profiles/{profileId}/active_curricula/data` - Active curricula
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

  /// The active profile ID for Firestore path scoping.
  final int profileId;

  /// Get current user's Firestore document reference.
  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  /// Get the profile-scoped base document reference.
  /// All profile-scoped data lives under `users/{uid}/profiles/{profileId}/`.
  DocumentReference<Map<String, dynamic>>? get _profileScopedDoc {
    return _userDoc?.collection('profiles').doc(profileId.toString());
  }

  /// Get profile subcollection reference (account-level, not profile-scoped).
  DocumentReference<Map<String, dynamic>>? get _profileDoc {
    return _userDoc?.collection('profile').doc('data');
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

  // ========== Completions Operations ==========

  /// Push a completion to Firestore (append-only).
  Future<void> pushCompletion(Map<String, dynamic> completionData) async {
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

  // ========== Bookmarks Operations ==========

  /// Push a bookmark to Firestore (last-write-wins with UTC timestamp).
  Future<void> pushBookmark(Map<String, dynamic> bookmarkData) async {
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
    final doc = _streakDoc;
    if (doc == null) return null;

    final snapshot = await doc.get();
    return snapshot.data();
  }

  /// Push streak data to Firestore (last-write-wins).
  Future<void> pushStreak(Map<String, dynamic> streakData) async {
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

  // ========== Goal Operations ==========

  /// Fetch all goals from Firestore with pagination.
  Future<List<Map<String, dynamic>>> fetchGoals({
    int pageSize = defaultPageSize,
  }) async {
    final collection = _profileScopedDoc?.collection('goals');
    if (collection == null) return [];

    return _fetchPaginated(collection, pageSize: pageSize);
  }

  /// Push a goal to Firestore (last-write-wins).
  Future<void> pushGoal(Map<String, dynamic> goalData) async {
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

  // ========== Reward Operations ==========

  /// Fetch all rewards from Firestore with pagination.
  Future<List<Map<String, dynamic>>> fetchRewards({
    int pageSize = defaultPageSize,
  }) async {
    final collection = _profileScopedDoc?.collection('rewards');
    if (collection == null) return [];

    return _fetchPaginated(collection, pageSize: pageSize);
  }

  /// Push a reward to Firestore (last-write-wins).
  Future<void> pushReward(Map<String, dynamic> rewardData) async {
    final collection = _profileScopedDoc?.collection('rewards');
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    final id = rewardData['id']?.toString();
    if (id == null) {
      throw Exception('Reward must have an id');
    }

    await collection.doc(id).set({
      ...rewardData,
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

  // ========== Reward Listener ==========

  /// Listen to real-time reward updates.
  Stream<List<Map<String, dynamic>>> listenToRewards() {
    final collection = _profileScopedDoc?.collection('rewards');
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

  // ========== Curriculum Import Metadata Operations ==========

  /// Push curriculum import metadata to Firestore.
  ///
  /// This allows other devices to detect that a curriculum has already been
  /// imported and skip re-import from Sefaria.
  Future<void> pushCurriculumImportMetadata(
    Map<String, dynamic> metadata,
  ) async {
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
