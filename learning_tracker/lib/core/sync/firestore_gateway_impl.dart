import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';

/// The canonical [FirestoreGateway] implementation.
///
/// **This is the only file in `lib/` permitted to import
/// `package:cloud_firestore/cloud_firestore.dart`** — the acceptance test
/// for Story 25.12 enforces that invariant. Legacy `features/sync/data/*`
/// files were migrated to route through this gateway in the DNI-333/334/335
/// cutover.
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

  /// Sanitize a string for use as a Firestore document ID.
  ///
  /// Firestore document IDs must not contain `/` (path separator). Spaces and
  /// other non-alphanumeric characters are replaced with `_` to keep IDs
  /// readable and safe across all Firestore SDK versions.
  ///
  /// The replacement is deterministic, so the same logical key always produces
  /// the same document ID.
  static String _sanitizeDocId(String raw) =>
      raw.replaceAll('/', '_').replaceAll(' ', '_').replaceAll('.', '_');

  /// Derive a deterministic, URL-safe Firestore document ID from the
  /// completion's natural key.
  ///
  /// Format: `<profileId>_<sefariaRef>_<stageId>_<trackType>`
  ///
  /// Invalid Firestore doc ID characters (`/`, space, `.`) are replaced with
  /// `_`. The resulting ID is stable across pushes so that re-pushing the same
  /// completion overwrites the existing document rather than creating a
  /// duplicate.
  static String _completionDocId(int profileId, Map<String, dynamic> data) {
    final ref = _sanitizeDocId(
      (data['sefariaRef'] ?? data['sefaria_ref']) as String? ?? '',
    );
    final stage = (data['stageId'] ?? data['stage_id'])?.toString() ?? '';
    final tt = _sanitizeDocId(
      (data['trackType'] ?? data['track_type']) as String? ?? '',
    );
    return '${profileId}_${ref}_${stage}_$tt';
  }

  @override
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
    String? docId,
  }) async {
    final collection = _collection(profileId, 'completions');
    if (collection == null) throw _notAuthenticated;
    // Use the caller-supplied docId (the outbox entityKey) when available so
    // the document ID is exactly the same as what OutboxProcessor tracked.
    // Fall back to deriving the ID from payload fields for callers that do not
    // supply an entityKey (e.g. direct gateway use in tests).
    final id = docId != null ? _sanitizeDocId(docId) : _completionDocId(profileId, data);
    await collection.doc(id).set(
      {...data, 'synced_at': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> pushCompletionsBatch({
    required int profileId,
    required List<Map<String, dynamic>> items,
  }) async {
    if (items.isEmpty) return;
    final collection = _collection(profileId, 'completions');
    if (collection == null) throw _notAuthenticated;

    const chunkSize = 500;
    for (var start = 0; start < items.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, items.length);
      final chunk = items.sublist(start, end);
      final batch = _firestore.batch();
      for (final data in chunk) {
        // Use _entityKey when present (injected by OutboxPushPipeline.pushCompletionsBatch);
        // fall back to computing from payload fields for direct gateway callers.
        final entityKey = data['_entityKey'] as String?;
        final id = entityKey != null
            ? _sanitizeDocId(entityKey)
            : _completionDocId(profileId, data);
        // Strip internal bookkeeping key before writing to Firestore.
        final payload = entityKey != null
            ? (Map<String, dynamic>.from(data)..remove('_entityKey'))
            : data;
        batch.set(
          collection.doc(id),
          {...payload, 'synced_at': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
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
        .map((doc) => _normalizeRow({...doc.data(), 'firestore_id': doc.id}))
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
        .map((doc) => _normalizeRow({...doc.data(), 'firestore_id': doc.id}))
        .toList(growable: false);
  }

  // ── DNI-333 cutover additions ─────────────────────────────────────────────

  @override
  Future<void> pushGoal({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final collection = _collection(profileId, 'goals');
    if (collection == null) throw _notAuthenticated;
    final docId = data['id']?.toString() ?? data['goal_id']?.toString();
    if (docId != null) {
      await collection.doc(docId).set({
        ...data,
        'synced_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await collection.add({
        ...data,
        'synced_at': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> pushUiPreferences({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final doc = _doc(profileId, 'ui_preferences', 'data');
    if (doc == null) throw _notAuthenticated;
    await doc.set({
      ...data,
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> pushAccountProfile({required Map<String, dynamic> data}) async {
    final uid = _authRepository.currentUser?.uid;
    if (uid == null) throw _notAuthenticated;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('data')
        .set({
          ...data,
          'synced_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Future<void> pushCurriculumImportMetadata({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final collection = _collection(profileId, 'curriculum_import_metadata');
    if (collection == null) throw _notAuthenticated;
    final docId = data['curriculum_id']?.toString() ?? 'default';
    await collection.doc(docId).set({
      ...data,
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteUserData(String uid) async {
    final userDoc = _firestore.collection('users').doc(uid);
    const subcollections = [
      'completions',
      'bookmarks',
      'settings',
      'streaks',
      'profiles',
      'learner_profiles',
      'goals',
      'rewards',
      'sync_queue',
      'learning_order',
      'stage_definitions',
      'diagnostic_logs',
    ];
    for (final sub in subcollections) {
      await _deleteCollection(userDoc.collection(sub));
    }
    await userDoc.delete();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    const batchSize = 500;
    QuerySnapshot<Map<String, dynamic>> snapshot;
    do {
      snapshot = await ref.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length >= batchSize);
  }

  @override
  Future<void> pushDiagnosticLog({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('diagnostic_logs')
        .add({...data, 'captured_at': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> pushAccountUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<List<Map<String, dynamic>>> listenToCollection({
    required int profileId,
    required String collection,
  }) {
    final ref = _collection(profileId, collection);
    if (ref == null) return const Stream.empty();
    return ref.snapshots().map(
      (s) =>
          // RC4 fix: filter out documents that still have pending local writes
          // (hasPendingWrites = true). These are self-writes from this device
          // that have not yet been confirmed by the server. Emitting them would
          // cause the merge pipeline to re-process the same completion that was
          // just pushed — producing a listener echo storm.
          //
          // Only server-confirmed documents (hasPendingWrites = false) are
          // forwarded to the merge pipeline.
          s.docs
              .where((d) => !d.metadata.hasPendingWrites)
              .map((d) => _normalizeRow({...d.data(), 'firestore_id': d.id}))
              .toList(growable: false),
    );
  }

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) {
    final ref = _doc(profileId, collection, docId);
    if (ref == null) return const Stream.empty();
    return ref.snapshots().map((s) {
      if (!s.exists) return null;
      final data = s.data();
      if (data == null) return null;
      return _normalizeRow({...data, 'firestore_id': s.id});
    });
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async {
    final uid = _authRepository.currentUser?.uid;
    if (uid == null) return [];
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .get();
    return snap.docs
        .map((d) => _normalizeRow({...d.data(), 'firestore_id': d.id}))
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async {
    final ref = _doc(profileId, collection, docId);
    if (ref == null) return null;
    final snap = await ref.get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return _normalizeRow({...data, 'firestore_id': snap.id});
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Converts Firestore-specific types to plain Dart values so the merge
  /// pipeline never sees SDK types (e.g. [Timestamp] → ISO-8601 String).
  ///
  /// This keeps the gateway boundary clean — callers only see
  /// `Map<String, dynamic>` with standard Dart types.
  static Map<String, dynamic> _normalizeRow(Map<String, dynamic> raw) {
    return raw.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toUtc().toIso8601String());
      }
      return MapEntry(key, value);
    });
  }

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
