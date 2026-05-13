import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';

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
    required FirebaseAuth auth,
  }) : _firestore = firestore,
       _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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

  // ── helpers ───────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>>? _collection(
    int profileId,
    String name,
  ) {
    final uid = _auth.currentUser?.uid;
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
