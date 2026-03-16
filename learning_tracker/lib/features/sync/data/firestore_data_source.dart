import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles all Firestore read/write operations for sync.
///
/// Collection structure per P4:
/// - `users/{uid}/profile` - User profile (single doc)
/// - `users/{uid}/completions/{autoId}` - Completions (append-only)
/// - `users/{uid}/bookmarks/{curriculumId}_{trackType}` - Bookmarks (last-write-wins)
/// - `users/{uid}/settings/{curriculumId}` - Settings (last-write-wins)
/// - `users/{uid}/streak` - Streak data (single doc)
class FirestoreDataSource {
  FirestoreDataSource({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Get current user's Firestore document reference.
  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  /// Get profile subcollection reference.
  DocumentReference<Map<String, dynamic>>? get _profileDoc {
    return _userDoc?.collection('profile').doc('data');
  }

  /// Get completions subcollection reference.
  CollectionReference<Map<String, dynamic>>? get _completionsCollection {
    return _userDoc?.collection('completions');
  }

  /// Get bookmarks subcollection reference.
  CollectionReference<Map<String, dynamic>>? get _bookmarksCollection {
    return _userDoc?.collection('bookmarks');
  }

  /// Get settings subcollection reference.
  CollectionReference<Map<String, dynamic>>? get _settingsCollection {
    return _userDoc?.collection('settings');
  }

  /// Get streak document reference.
  DocumentReference<Map<String, dynamic>>? get _streakDoc {
    return _userDoc?.collection('streak').doc('data');
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

  /// Fetch all completions from Firestore.
  Future<List<Map<String, dynamic>>> fetchCompletions() async {
    final collection = _completionsCollection;
    if (collection == null) return [];

    final snapshot = await collection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {...data, 'firestore_id': doc.id};
    }).toList();
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

  /// Fetch all bookmarks from Firestore.
  Future<List<Map<String, dynamic>>> fetchBookmarks() async {
    final collection = _bookmarksCollection;
    if (collection == null) return [];

    final snapshot = await collection.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
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

  /// Fetch all settings from Firestore.
  Future<List<Map<String, dynamic>>> fetchSettings() async {
    final collection = _settingsCollection;
    if (collection == null) return [];

    final snapshot = await collection.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
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

  /// Push a goal to Firestore (last-write-wins).
  Future<void> pushGoal(Map<String, dynamic> goalData) async {
    final collection = _userDoc?.collection('goals');
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

  /// Push a reward to Firestore (last-write-wins).
  Future<void> pushReward(Map<String, dynamic> rewardData) async {
    final collection = _userDoc?.collection('rewards');
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

  // ========== Active Curricula Operations ==========

  /// Get active curricula document reference.
  DocumentReference<Map<String, dynamic>>? get _activeCurriculaDoc {
    return _userDoc?.collection('active_curricula').doc('data');
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
    final collection = _userDoc?.collection('curriculum_imports');
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
    final collection = _userDoc?.collection('curriculum_imports');
    if (collection == null) return null;

    final snapshot = await collection.doc(curriculumId).get();
    return snapshot.data();
  }
}
