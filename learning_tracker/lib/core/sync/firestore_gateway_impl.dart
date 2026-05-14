import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';

/// The canonical [FirestoreGateway] implementation.
///
/// **This is the only file in `lib/` permitted to import
/// `package:cloud_firestore/cloud_firestore.dart`** — the acceptance test
/// for Story 25.12 enforces that invariant (with a transitional allowlist
/// for the legacy `features/sync/data/*` files that DNI-334..335 are
/// retiring).
///
/// Collection layout (v1, set by DNI-325):
///   `users/{uid}/learner_profiles/{profileId}/<collection>/...`
class FirestoreGatewayImpl implements FirestoreGateway {
  FirestoreGatewayImpl({
    required FirebaseFirestore firestore,
    required AuthRepository authRepository,
  }) : _firestore = firestore,
       _authRepository = authRepository;

  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;

  // ── push ──────────────────────────────────────────────────────────────────

  @override
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final collection = _collection(profileId, 'completions');
    if (collection == null) throw _notAuthenticated;
    await collection.add({...data, 'synced_at': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> pushStreak({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final doc = _doc(profileId, 'streak', 'data');
    if (doc == null) throw _notAuthenticated;
    await doc.set({
      ...data,
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> pushSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final collection = _collection(profileId, 'settings');
    if (collection == null) throw _notAuthenticated;
    final docId = data['curriculum_id']?.toString() ?? 'default';
    await collection.doc(docId).set({
      ...data,
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> pushTrack({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final collection = _collection(profileId, 'curriculum_tracks');
    if (collection == null) throw _notAuthenticated;
    final curriculumId = data['curriculum_id']?.toString() ?? '';
    final trackType = data['track_type']?.toString() ?? '';
    final docId = '${curriculumId}_$trackType';
    await collection.doc(docId).set({
      ...data,
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final collection = _collection(profileId, 'learning_order');
    if (collection == null) throw _notAuthenticated;
    final curriculumId = data['curriculum_id']?.toString() ?? '';
    final ref =
        data['sefaria_ref']?.toString() ?? data['ref']?.toString() ?? '';
    final docId = '${curriculumId}_$ref';
    await collection.doc(docId).set({
      ...data,
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> pushBookmark({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final collection = _collection(profileId, 'bookmarks');
    if (collection == null) throw _notAuthenticated;
    final curriculumId = data['curriculum_id']?.toString() ?? '';
    final trackType = data['track_type']?.toString() ?? '';
    final docId = '${curriculumId}_$trackType';
    await collection.doc(docId).set({
      ...data,
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── P2a additions ──────────────────────────────────────────────────────────

  @override
  Future<void> pushNotificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final doc = _doc(profileId, 'notification_settings', 'preferences');
    if (doc == null) throw _notAuthenticated;
    await doc.set({
      ...data,
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> pushGamificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final doc = _doc(profileId, 'gamification_settings', 'config');
    if (doc == null) throw _notAuthenticated;
    await doc.set({
      ...data,
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── P2b additions ──────────────────────────────────────────────────────────

  @override
  Future<void> pushLearnerProfile({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    // Learner-profile documents live at the account level, not inside a
    // profile subcollection:  users/{uid}/learner_profiles/{profileId}
    final learnerProfileDoc = _learnerProfileDoc(profileId);
    if (learnerProfileDoc == null) throw _notAuthenticated;
    await learnerProfileDoc.set({
      ...data,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteLearnerProfile(int profileId) async {
    // The Firestore delete uses a server-side Cloud Function that runs
    // recursiveDelete on the profile document and all its subcollections.
    // The SharedPreferences tombstone is intentionally NOT written here —
    // that is the caller's responsibility (SyncEngine or ProfileRepositoryImpl).
    final callable = FirebaseFunctions.instance.httpsCallable(
      'deleteLearnerProfile',
    );
    await callable.call<Map<String, dynamic>>({'profileId': profileId});
  }

  // ── P2c additions ──────────────────────────────────────────────────────────

  @override
  Future<void> pushLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final collection = _collection(profileId, 'learning_ledger');
    if (collection == null) throw _notAuthenticated;
    await collection.add({...data, 'synced_at': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> pushLedgerEntriesBatch({
    required int profileId,
    required List<Map<String, dynamic>> entries,
  }) async {
    if (entries.isEmpty) return;
    final collection = _collection(profileId, 'learning_ledger');
    if (collection == null) throw _notAuthenticated;
    final batch = _firestore.batch();
    for (final entry in entries) {
      final doc = collection.doc();
      batch.set(doc, {...entry, 'synced_at': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  // ── P2d additions ──────────────────────────────────────────────────────────

  @override
  Future<void> pushProfileProgram({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final collection = _collection(profileId, 'profile_programs');
    if (collection == null) throw _notAuthenticated;
    final curriculumId = data['curriculum_id']?.toString() ?? '';
    await collection.doc(curriculumId).set({
      ...data,
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> removeProfileProgramAssignment({
    required int profileId,
    required String curriculumStorageKey,
  }) async {
    final collection = _collection(profileId, 'profile_programs');
    if (collection == null) throw _notAuthenticated;
    await collection.doc(curriculumStorageKey).delete();
  }

  // ── pull ──────────────────────────────────────────────────────────────────

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async {
    final ref = _collection(profileId, collection);
    if (ref == null) return const FirestorePage(rows: []);

    var query = ref.orderBy(FieldPath.documentId).limit(pageSize);
    if (cursor != null && cursor['firestore_id'] is String) {
      query = query.startAfter([cursor['firestore_id']]);
    }

    final snapshot = await query.get();
    final rows = snapshot.docs
        .map((doc) => {...doc.data(), 'firestore_id': doc.id})
        .toList(growable: false);
    return FirestorePage(rows: rows);
  }

  // ── P2e additions ──────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  }) async {
    final ref = _collection(profileId, collection);
    if (ref == null) return [];
    final snapshot = await ref.get();
    return snapshot.docs
        .map((doc) => {...doc.data(), 'firestore_id': doc.id})
        .toList(growable: false);
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Returns the account-level learner-profile document reference.
  ///
  /// Path: `users/{uid}/learner_profiles/{profileId}`
  ///
  /// This is distinct from the profile-scoped subcollections returned by
  /// [_collection] — it is the profile's own document in the parent collection.
  DocumentReference<Map<String, dynamic>>? _learnerProfileDoc(int profileId) {
    final uid = _authRepository.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(profileId.toString());
  }

  CollectionReference<Map<String, dynamic>>? _collection(
    int profileId,
    String name,
  ) {
    final uid = _authRepository.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(profileId.toString())
        .collection(name);
  }

  DocumentReference<Map<String, dynamic>>? _doc(
    int profileId,
    String collection,
    String docId,
  ) => _collection(profileId, collection)?.doc(docId);

  Exception get _notAuthenticated =>
      Exception('FirestoreGatewayImpl: user not authenticated');
}
