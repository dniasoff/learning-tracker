import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:learning_tracker/core/sync/exceptions/firestore_permission_denied_exception.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';

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
    String? Function()? activeAccountUid,
  }) : _firestore = firestore,
       _authRepository = authRepository,
       _activeAccountUid = activeAccountUid;

  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;

  /// Resolves the UID of the *active account record* (the on-screen account
  /// the local DB/UI are scoped to), independent of [FirebaseAuth.currentUser].
  ///
  /// C#1 safety floor: there is exactly ONE FirebaseAuth slot, so after an
  /// in-app account switch `currentUser` may still point at the PREVIOUS cloud
  /// account. Every per-user/per-profile Firestore path is addressed from the
  /// active-account UID, NOT from `currentUser`, so a stale `currentUser` can
  /// never address (and corrupt) the wrong account's cloud space — at worst the
  /// Firestore security rules deny the operation (UID ≠ auth.uid) rather than
  /// silently writing into account A while the UI thinks it is account B.
  ///
  /// This is built from the locally-stored active-account record and therefore
  /// needs no network round-trip — reads/writes stay offline-safe. Falls back
  /// to `currentUser` only when no active-account UID is injected (e.g. legacy
  /// tests) so behaviour is unchanged where the resolver is absent.
  final String? Function()? _activeAccountUid;

  /// The UID every path is keyed off. Prefers the active-account record; only
  /// falls back to the FirebaseAuth session when no resolver was injected.
  String? get _addressedUid =>
      _activeAccountUid?.call() ?? _authRepository.currentUser?.uid;

  // ── push ──────────────────────────────────────────────────────────────────

  /// Maximum number of operations Firestore permits in a single [WriteBatch].
  static const int _writeBatchLimit = 500;

  /// Default listener page size (Phase 2 of the sync-architecture plan).
  ///
  /// Listeners are bounded to keep gRPC stream payloads small and to cap the
  /// cost of self-echoes on heavy accounts (a user with 10k completions would
  /// otherwise receive a 10k-doc snapshot on every change). The supervisor
  /// pairs the bound with a recovery pull when the snapshot saturates this
  /// limit, so older changes are not silently truncated.
  static const int kListenerPageSize = 500;

  /// Percent-encode one natural-key component so it is safe to join into a
  /// canonical completion key.
  ///
  /// The set of *unescaped* characters is intentionally minimal — only ASCII
  /// letters, digits, `-` and `~` survive unescaped. Every other byte
  /// (including `%`, the chosen separator `_`, `/`, `.`, and space) is
  /// percent-encoded as `%XX`. Because `%` itself is escaped, the encoding is
  /// injective: decode is unambiguous, so distinct inputs always produce
  /// distinct outputs.
  static String _encodeKeyComponent(String raw) {
    final out = StringBuffer();
    for (final unit in utf8.encode(raw)) {
      final isUnreserved =
          (unit >= 0x30 && unit <= 0x39) || // 0-9
          (unit >= 0x41 && unit <= 0x5A) || // A-Z
          (unit >= 0x61 && unit <= 0x7A) || // a-z
          unit == 0x2D || // -
          unit == 0x7E; // ~
      if (isUnreserved) {
        out.writeCharCode(unit);
      } else {
        out
          ..write('%')
          ..write(unit.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
    return out.toString();
  }

  /// The single canonical completion document-ID function.
  ///
  /// The ID is derived from the completion's structured natural key —
  /// `profile_id` (int), `sefaria_ref` (string), `stage_id` (int),
  /// `track_type` (string), and `curriculum_id` (string). snake_case keys are
  /// authoritative; camelCase keys are accepted as a defensive fallback.
  ///
  /// **Per-curriculum isolation (Option B).** Including `curriculum_id` as the
  /// fifth component ensures that two completions with the same
  /// (profileId, sefariaRef, stageId, trackType) but different curriculumIds
  /// map to DISTINCT Firestore documents. Without this, a learner enrolled in
  /// two curricula covering the same sefariaRef would collide on the same doc,
  /// causing one curriculum's data to silently overwrite the other's.
  ///
  /// **Collision-free guarantee.** Each of the five components is
  /// percent-encoded by [_encodeKeyComponent] before being joined with `_`.
  /// The encoding escapes `%` and `_` themselves, so an encoded component can
  /// never contain a literal `_`. The joined string therefore has exactly
  /// four `_` separators at unambiguous positions — it can be split back into
  /// the original five components. A reversible (injective) transform maps
  /// distinct natural-key tuples to distinct IDs. In particular `Berakhot 1.1`,
  /// `Berakhot 1/1` and `Berakhot 1 1` encode to three different strings
  /// (`.`→`%2E`, `/`→`%2F`, space→`%20`) and thus three distinct documents.
  ///
  /// The result contains only `A-Z a-z 0-9 - ~ % _` — none of which is `/`,
  /// none of which forms `.`/`..` or the reserved `__.*__` pattern — so it is
  /// always a legal Firestore document ID.
  ///
  /// This is the **only** doc-ID derivation used for completions, by both
  /// [pushCompletion] and [pushCompletionsBatch].
  static String _completionDocId(int profileId, Map<String, dynamic> data) {
    final ref = (data['sefaria_ref'] ?? data['sefariaRef']) as String? ?? '';
    final stage = (data['stage_id'] ?? data['stageId'])?.toString() ?? '';
    final trackType =
        (data['track_type'] ?? data['trackType']) as String? ?? '';
    final curriculumId =
        (data['curriculum_id'] ?? data['curriculumId']) as String? ?? '';
    return [
      _encodeKeyComponent(profileId.toString()),
      _encodeKeyComponent(ref),
      _encodeKeyComponent(stage),
      _encodeKeyComponent(trackType),
      _encodeKeyComponent(curriculumId),
    ].join('_');
  }

  /// Return a copy of [data] with internal bookkeeping keys removed.
  ///
  /// Any key beginning with `_` is application-internal scaffolding (e.g. the
  /// outbox `_entityKey` and `_target_profile_id`) and must never reach a
  /// Firestore document. Centralising the strip here keeps every push path
  /// — single, batch, snapshot and event — defensively clean. Every push
  /// method that writes a `Map` to Firestore routes its payload through this
  /// so a closed `hasOnly()` whitelist in `firestore.rules` is never tripped
  /// by an internal key.
  static Map<String, dynamic> _stripInternalKeys(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};
    for (final entry in data.entries) {
      if (entry.key.startsWith('_')) continue;
      cleaned[entry.key] = entry.value;
    }
    return cleaned;
  }

  /// Return a copy of [data] in which the `completed_at` field is a genuine
  /// Firestore [Timestamp] rather than an ISO-8601 string.
  ///
  /// The outbox payload is JSON, so `completed_at` arrives here as an
  /// ISO-8601 *string* (`cmd.completedAt.toUtc().toIso8601String()`). The
  /// `completions` security rule compares `completed_at <= request.time`;
  /// in Firestore Security Rules a `string <= timestamp` comparison is
  /// `false`, which would deny EVERY completion create. Writing a real
  /// `Timestamp` makes the rule comparison sound.
  ///
  /// The value is left untouched when it is already a [Timestamp] (defensive
  /// — a future caller may pre-convert) or absent/null (the rule guards the
  /// field with `'completed_at' in request.resource.data`, so an omitted
  /// field is not denied). The read path is unaffected: [_normalizeRow]
  /// converts any Firestore `Timestamp` back to an ISO-8601 string on read.
  static Map<String, dynamic> _timestampifyCompletedAt(
    Map<String, dynamic> data,
  ) {
    var result = data;

    // Normalize completed_at
    final completedAt = result['completed_at'];
    if (completedAt != null && completedAt is! Timestamp) {
      if (completedAt is DateTime) {
        result = {
          ...result,
          'completed_at': Timestamp.fromDate(completedAt.toUtc()),
        };
      } else if (completedAt is String) {
        // A malformed string must not throw out of the whole batch — leave the
        // value untouched so only this one document is affected (denied by the
        // completed_at rule) rather than poisoning every sibling in the chunk.
        final parsed = DateTime.tryParse(completedAt);
        if (parsed != null) {
          result = {
            ...result,
            'completed_at': Timestamp.fromDate(parsed.toUtc()),
          };
        }
      }
    }

    // Normalize purged_at (present in tombstone outbox payloads).
    if (result.containsKey('purged_at')) {
      final purgedAt = result['purged_at'];
      if (purgedAt != null && purgedAt is! Timestamp) {
        if (purgedAt is DateTime) {
          result = {
            ...result,
            'purged_at': Timestamp.fromDate(purgedAt.toUtc()),
          };
        } else if (purgedAt is String) {
          final parsed = DateTime.tryParse(purgedAt);
          if (parsed != null) {
            result = {
              ...result,
              'purged_at': Timestamp.fromDate(parsed.toUtc()),
            };
          }
        }
      }
    }

    return result;
  }

  @override
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
    String? docId,
  }) async {
    final collection = _collection(profileId, 'completions');
    if (collection == null) throw _notAuthenticated;
    // The completion document ID is ALWAYS derived from the structured
    // natural key — never from the caller-supplied [docId]. The outbox
    // `entityKey` is a local-only dedup key and is deliberately NOT used as
    // the Firestore document ID (it collides on `:`-vs-doc-id rules and
    // diverges from the batch path). The [docId] parameter is retained on the
    // interface for non-completion callers; for completions it is ignored.
    final id = _completionDocId(profileId, data);
    await collection.doc(id).set({
      ..._timestampifyCompletedAt(_stripInternalKeys(data)),
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> items,
  }) async {
    if (items.isEmpty) return const [];
    final collection = _collection(profileId, 'completions');
    if (collection == null) throw _notAuthenticated;

    final pushed = <String>[];
    for (var start = 0; start < items.length; start += _writeBatchLimit) {
      final end = (start + _writeBatchLimit).clamp(0, items.length);
      final chunk = items.sublist(start, end);
      final batch = _firestore.batch();
      for (final item in chunk) {
        // The doc ID is always derived from the payload's structured natural
        // key — the same single function used by [pushCompletion]. The outbox
        // entityKey is used only to report which rows committed.
        final id = _completionDocId(profileId, item.payload);
        batch.set(collection.doc(id), {
          ..._timestampifyCompletedAt(_stripInternalKeys(item.payload)),
          'synced_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      // Per-chunk commit accounting: if this chunk throws, the entityKeys of
      // the chunks that already committed are carried out on a
      // [BatchPushException] so the caller (OutboxProcessor) can delete
      // exactly the rows that genuinely landed and retry only the rest —
      // committed rows are never re-pushed or dead-lettered (H3).
      try {
        await batch.commit();
      } catch (e) {
        throw SyncPushException(
          committed: List.unmodifiable(pushed),
          pushCause: e,
        );
      }
      pushed.addAll(chunk.map((e) => e.entityKey));
    }
    return pushed;
  }

  @override
  Future<void> pushStreak({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    // W3.37: streak changed from single snapshot doc (streak/data) to an
    // append-only event collection (streak_events/{ulid}). Each StreakEvent
    // stored in Drift gets its own document keyed by the event ULID. The
    // outbox payload carries a 'ulid' field; fall back to a server-side
    // auto-generated doc-id if absent so old outbox rows flush cleanly.
    final collection = _collection(profileId, 'streak_events');
    if (collection == null) throw _notAuthenticated;
    final ulid = data['ulid'] as String?;
    final ref = ulid != null ? collection.doc(ulid) : collection.doc();
    await ref.set({
      ..._stripInternalKeys(data),
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
      ..._stripInternalKeys(data),
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
    // H1 fix (V3-W1): W3.22 removed trackType from curriculum_tracks; one track
    // per (profileId, curriculumId) is now the invariant. Use curriculumId alone
    // as the document ID so every track lands at a stable, unique path.
    // The old pattern `${curriculumId}_${trackType}` would degenerate to
    // `${curriculumId}_` (empty trackType) causing all curricula to overwrite
    // the same document on multi-curriculum accounts.
    final curriculumId = data['curriculum_id']?.toString() ?? '';
    final docId = curriculumId;
    await collection.doc(docId).set({
      ..._stripInternalKeys(data),
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
      ..._stripInternalKeys(data),
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
      ..._stripInternalKeys(data),
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── P2a additions ──────────────────────────────────────────────────────────

  @override
  Future<void> pushNotificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    // W3.33: unified into preferences/{scope} — scope = 'notification_settings'.
    final doc = _doc(profileId, 'preferences', 'notification_settings');
    if (doc == null) throw _notAuthenticated;
    await doc.set({
      ..._stripInternalKeys(data),
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> pushGamificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    // W3.33: unified into preferences/{scope} — scope = 'gamification_settings'.
    final doc = _doc(profileId, 'preferences', 'gamification_settings');
    if (doc == null) throw _notAuthenticated;
    await doc.set({
      ..._stripInternalKeys(data),
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
      ..._stripInternalKeys(data),
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
    // W3.36: use the ULID from the payload as doc-id instead of auto-id.
    // This makes the write idempotent — retrying the same outbox row always
    // hits the same document (INSERT OR IGNORE semantics via merge:true).
    final collection = _collection(profileId, 'learning_ledger');
    if (collection == null) throw _notAuthenticated;
    final ulid = data['ulid'] as String?;
    final ref = ulid != null ? collection.doc(ulid) : collection.doc();
    await ref.set({
      ..._stripInternalKeys(data),
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
      // W3.36: use ULID as doc-id for idempotent batch writes.
      final ulid = entry['ulid'] as String?;
      final ref = ulid != null ? collection.doc(ulid) : collection.doc();
      batch.set(ref, {
        ..._stripInternalKeys(entry),
        'synced_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
      ..._stripInternalKeys(data),
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

  /// No composite Firestore index is required by the sync subsystem, so
  /// `firestore.indexes.json` carries an empty `indexes` array. [fetchPage]
  /// orders solely by `FieldPath.documentId`; [fetchAll] and
  /// [listenToCollection] issue unfiltered snapshots; no query combines
  /// `.where(...)` with `.orderBy(...)` on a non-documentId field. Restore an
  /// index declaration only if a composite-index-needing query is added.
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

    // W7.10: convert PERMISSION_DENIED → FirestorePermissionDeniedException.
    final snapshot = await _guardPermission(
      () => query.get(),
      collection: collection,
      operation: 'read',
    );
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
        ..._stripInternalKeys(data),
        'synced_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await collection.add({
        ..._stripInternalKeys(data),
        'synced_at': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> deleteGoal({
    required int profileId,
    required String firestoreId,
  }) async {
    final collection = _collection(profileId, 'goals');
    if (collection == null) throw _notAuthenticated;
    await collection.doc(firestoreId).delete();
  }

  @override
  Future<void> pushUiPreferences({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    // W3.33: unified into preferences/{scope} — scope = 'ui_preferences'.
    final doc = _doc(profileId, 'preferences', 'ui_preferences');
    if (doc == null) throw _notAuthenticated;
    await doc.set({
      ..._stripInternalKeys(data),
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> pushAccountProfile({required Map<String, dynamic> data}) async {
    final uid = _addressedUid;
    if (uid == null) throw _notAuthenticated;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('profile')
        .doc('data')
        .set({
          ..._stripInternalKeys(data),
          'synced_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Future<void> pushCurriculumImportMetadata({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    // W3.34: renamed collection curriculum_import_metadata → import_metadata.
    final collection = _collection(profileId, 'import_metadata');
    if (collection == null) throw _notAuthenticated;
    final docId = data['curriculum_id']?.toString() ?? 'default';
    await collection.doc(docId).set({
      ..._stripInternalKeys(data),
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
        .add({
          ..._stripInternalKeys(data),
          'captured_at': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> pushAccountUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      ..._stripInternalKeys(data),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = kListenerPageSize,
  }) {
    final ref = _collection(profileId, collection);
    if (ref == null) return const Stream.empty();

    // Phase 2 of the sync-architecture plan: every listener is bounded by
    // `.orderBy(<orderField>, descending: true).limit(limit)`. Per-collection
    // [orderField] (e.g. `updated_at`, `completed_at`, `event_timestamp`) is
    // passed in by the caller so each collection sorts by a meaningful
    // recency field. Collections without an orderable timestamp pass
    // [FirestoreGateway.documentIdOrderField] and fall through to the
    // documentId path below.
    final bounded = orderField == FirestoreGateway.documentIdOrderField
        ? ref.orderBy(FieldPath.documentId, descending: true).limit(limit)
        : ref.orderBy(orderField, descending: true).limit(limit);

    // The stream must always reflect the full server-confirmed collection
    // state — including, while offline, the locally-cached documents — so the
    // consumer never sees the collection "vanish" off the network.
    //
    // The only thing we suppress is the *local echo*: when this device writes
    // a document, the listener fires immediately with a snapshot in which that
    // document's change carries `hasPendingWrites == true`. Re-processing that
    // self-write would loop the merge pipeline. So we iterate `docChanges` and
    // drop a document from the emitted list ONLY when it appears solely as an
    // un-acked local write — i.e. it is `added` (or `modified`) with
    // `hasPendingWrites` and the document is not otherwise present as a
    // server-confirmed entry. Genuine remote snapshots still emit in full.
    return bounded.snapshots().map((snapshot) {
      // Doc IDs that exist only as un-acked local writes in this snapshot.
      final localOnly = <String>{};
      for (final change in snapshot.docChanges) {
        if (change.doc.metadata.hasPendingWrites) {
          localOnly.add(change.doc.id);
        }
      }
      final rows = snapshot.docs
          .where(
            (d) => !localOnly.contains(d.id) || !d.metadata.hasPendingWrites,
          )
          .map((d) => _normalizeRow({...d.data(), 'firestore_id': d.id}))
          .toList(growable: false);
      // isAtLimit is computed against the raw snapshot count (pre-local-echo
      // filtering): the at-limit signal is about the *server's* page, not the
      // post-filter row count. A snapshot that filled the page even though
      // some rows were local-echo placeholders still indicates there may be
      // older changes the listener window did not cover.
      final isAtLimit = snapshot.docs.length >= limit;
      return ListenerSnapshot(rows: rows, isAtLimit: isAtLimit);
    });
  }

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({
    int limit = kListenerPageSize,
  }) {
    final uid = _addressedUid;
    if (uid == null) return const Stream.empty();

    // The `tutor_grants` collection lives at the root level and the security
    // rule grants read access when either `tutor_uid == auth.uid` or
    // `parent_uid == auth.uid`. Firestore does not support OR queries so we
    // merge two streams client-side, de-duplicating by document id (a single
    // grant document references both tutor and parent, but the caller may be
    // either; a self-tutoring grant is the only path where one doc appears in
    // both streams — even so dedup is harmless).
    final asTutor = _firestore
        .collection('tutor_grants')
        .where('tutor_uid', isEqualTo: uid)
        .orderBy('updated_at', descending: true)
        .limit(limit);
    final asParent = _firestore
        .collection('tutor_grants')
        .where('parent_uid', isEqualTo: uid)
        .orderBy('updated_at', descending: true)
        .limit(limit);

    final tutorStream = asTutor.snapshots();
    final parentStream = asParent.snapshots();

    // ignore: close_sinks — the controller is closed by the
    // StreamController.onCancel hook below; the analyzer cannot see that.
    final controller = StreamController<ListenerSnapshot>.broadcast();
    QuerySnapshot<Map<String, dynamic>>? lastTutor;
    QuerySnapshot<Map<String, dynamic>>? lastParent;

    void emit() {
      final docs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      var maxSize = 0;
      for (final src in [lastTutor, lastParent]) {
        if (src == null) continue;
        if (src.docs.length > maxSize) maxSize = src.docs.length;
        for (final d in src.docs) {
          docs[d.id] = d;
        }
      }
      final rows = docs.values
          .where((d) => !d.metadata.hasPendingWrites)
          .map((d) => _normalizeRow({...d.data()!, 'firestore_id': d.id}))
          .toList(growable: false);
      // A grant document with no `tutor_email`, `revoked_at` etc. can still
      // be a valid row — the merger handles missing fields. isAtLimit reflects
      // the worst case across the two underlying queries.
      controller.add(ListenerSnapshot(rows: rows, isAtLimit: maxSize >= limit));
    }

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subTutor;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subParent;
    controller.onListen = () {
      subTutor = tutorStream.listen((snap) {
        lastTutor = snap;
        emit();
      }, onError: controller.addError);
      subParent = parentStream.listen((snap) {
        lastParent = snap;
        emit();
      }, onError: controller.addError);
    };
    controller.onCancel = () async {
      await subTutor?.cancel();
      await subParent?.cancel();
      await controller.close();
    };
    return controller.stream;
  }

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({
    int limit = kListenerPageSize,
  }) {
    final uid = _addressedUid;
    if (uid == null) return const Stream.empty();
    // The `learner_profiles` collection lives at the account level
    // (users/{uid}/learner_profiles) — it is the PARENT of the per-profile
    // subcollections, not a child of any one profile document. Listen with
    // the standard bound + order-by-updated_at descending.
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('learner_profiles');
    final bounded = ref.orderBy('updated_at', descending: true).limit(limit);
    return bounded.snapshots().map((snapshot) {
      final localOnly = <String>{};
      for (final change in snapshot.docChanges) {
        if (change.doc.metadata.hasPendingWrites) {
          localOnly.add(change.doc.id);
        }
      }
      final rows = snapshot.docs
          .where(
            (d) => !localOnly.contains(d.id) || !d.metadata.hasPendingWrites,
          )
          .map((d) => _normalizeRow({...d.data(), 'firestore_id': d.id}))
          .toList(growable: false);
      return ListenerSnapshot(
        rows: rows,
        isAtLimit: snapshot.docs.length >= limit,
      );
    });
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
    final uid = _addressedUid;
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

  // ── W2.29 additions — stage_definitions/ collection ─────────────────────

  @override
  Future<void> pushStageDefinition({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final collection = _collection(profileId, 'stage_definitions');
    if (collection == null) throw _notAuthenticated;
    // Doc ID: "{trackId}_{stageOrder}" — deterministic, overwrites cleanly.
    final trackId = data['track_id']?.toString() ?? '';
    final stageOrder = data['stage_order']?.toString() ?? '';
    if (trackId.isEmpty || stageOrder.isEmpty) {
      throw ArgumentError(
        'pushStageDefinition requires non-null track_id and stage_order',
      );
    }
    final docId = '${trackId}_$stageOrder';
    await collection.doc(docId).set({
      ..._stripInternalKeys(data),
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Phase 1 — study_day_configs/ collection ─────────────────────────────

  @override
  Future<void> pushStudyDayConfig({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    final collection = _collection(profileId, 'study_day_configs');
    if (collection == null) throw _notAuthenticated;
    final curriculumId = data['curriculum_id']?.toString() ?? '';
    final dayOfWeek = data['day_of_week']?.toString() ?? '';
    final trackId = data['track_id']?.toString() ?? '';
    if (curriculumId.isEmpty || dayOfWeek.isEmpty || trackId.isEmpty) {
      throw ArgumentError(
        'pushStudyDayConfig requires non-null curriculum_id, day_of_week, and track_id',
      );
    }
    final docId = '${curriculumId}_${dayOfWeek}_$trackId';
    await collection.doc(docId).set({
      ..._stripInternalKeys(data),
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── WS9 Wave-B (C#2) — points spend economy ────────────────────────────────

  @override
  Future<void> pushPointsLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    // Append-only: use the ULID from the payload as doc-id so retrying the
    // same outbox row always hits the same document (INSERT OR IGNORE
    // semantics via merge:true).
    final collection = _collection(profileId, 'points_ledger');
    if (collection == null) throw _notAuthenticated;
    final ulid = data['ulid'] as String?;
    final ref = ulid != null ? collection.doc(ulid) : collection.doc();
    await ref.set({
      ..._stripInternalKeys(data),
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> pushRewardRedemption({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    // LWW state-machine doc keyed by the stable ULID. `updated_at` is the LWW
    // field; the merger applies the latest-by-updated_at status.
    final collection = _collection(profileId, 'reward_redemptions');
    if (collection == null) throw _notAuthenticated;
    final ulid = data['ulid'] as String?;
    final ref = ulid != null ? collection.doc(ulid) : collection.doc();
    await ref.set({
      ..._stripInternalKeys(data),
      'synced_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  /// Returns the account-level learner-profile document reference, or `null`
  /// when the caller is not authenticated.
  ///
  /// Path: `users/{uid}/learner_profiles/{profileId}`
  ///
  /// This single helper is the sole place the learner-profile document path
  /// is constructed; both the public [_learnerProfileDoc] use site and the
  /// per-profile [_collection] subcollections derive from it (H12).
  DocumentReference<Map<String, dynamic>>? _learnerProfileDoc(int profileId) {
    final uid = _addressedUid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(profileId.toString());
  }

  // ── T1.gateway — parent-scoped child reads ────────────────────────────────

  /// Path helper: subcollection reference in the parent's namespace.
  ///
  /// Path: `users/{parentUid}/learner_profiles/{remoteProfileId}/{name}`
  CollectionReference<Map<String, dynamic>> _childCollection(
    String parentUid,
    String remoteProfileId,
    String name,
  ) => _firestore
      .collection('users')
      .doc(parentUid)
      .collection('learner_profiles')
      .doc(remoteProfileId)
      .collection(name);

  @override
  Future<FirestorePage> fetchChildPage({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async {
    final ref = _childCollection(parentUid, remoteProfileId, collection);
    var query = ref.orderBy(FieldPath.documentId).limit(pageSize);
    if (cursor != null && cursor['firestore_id'] is String) {
      query = query.startAfter([cursor['firestore_id']]);
    }
    final snapshot = await _guardPermission(
      () => query.get(),
      collection: collection,
      operation: 'read',
    );
    final rows = snapshot.docs
        .map((doc) => _normalizeRow({...doc.data(), 'firestore_id': doc.id}))
        .toList(growable: false);
    return FirestorePage(rows: rows);
  }

  @override
  Future<Map<String, dynamic>?> fetchChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String docId,
  }) async {
    final ref = _childCollection(
      parentUid,
      remoteProfileId,
      collection,
    ).doc(docId);
    final snap = await ref.get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return _normalizeRow({...data, 'firestore_id': snap.id});
  }

  // ── D3/D5 — parent-scoped child listeners ────────────────────────────────

  @override
  Stream<ListenerSnapshot> listenToChildCollection({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String orderField,
    int limit = kListenerPageSize,
  }) {
    final ref = _childCollection(parentUid, remoteProfileId, collection);
    final bounded = orderField == FirestoreGateway.documentIdOrderField
        ? ref.orderBy(FieldPath.documentId, descending: true).limit(limit)
        : ref.orderBy(orderField, descending: true).limit(limit);
    return bounded.snapshots().map((snapshot) {
      final localOnly = <String>{};
      for (final change in snapshot.docChanges) {
        if (change.doc.metadata.hasPendingWrites) {
          localOnly.add(change.doc.id);
        }
      }
      final rows = snapshot.docs
          .where(
            (d) => !localOnly.contains(d.id) || !d.metadata.hasPendingWrites,
          )
          .map((d) => _normalizeRow({...d.data(), 'firestore_id': d.id}))
          .toList(growable: false);
      final isAtLimit = snapshot.docs.length >= limit;
      return ListenerSnapshot(rows: rows, isAtLimit: isAtLimit);
    });
  }

  @override
  Stream<Map<String, dynamic>?> listenToChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String docId,
  }) {
    final ref = _childCollection(
      parentUid,
      remoteProfileId,
      collection,
    ).doc(docId);
    return ref.snapshots().map((s) {
      if (!s.exists) return null;
      final data = s.data();
      if (data == null) return null;
      return _normalizeRow({...data, 'firestore_id': s.id});
    });
  }

  // ── Tutor audit log reads (W6.13) ─────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> fetchAuditLogEntries({
    required String grantId,
    String? startTimestamp,
    String? endTimestamp,
    String? actionFilter,
  }) async {
    var q = _firestore
        .collection('tutor_grants')
        .doc(grantId)
        .collection('audit_log')
        .orderBy('timestamp', descending: true);

    if (startTimestamp != null && endTimestamp != null) {
      q = q.where(
        'timestamp',
        isGreaterThanOrEqualTo: startTimestamp,
        isLessThanOrEqualTo: endTimestamp,
      );
    } else if (startTimestamp != null) {
      q = q.where('timestamp', isGreaterThanOrEqualTo: startTimestamp);
    } else if (endTimestamp != null) {
      q = q.where('timestamp', isLessThanOrEqualTo: endTimestamp);
    }

    if (actionFilter != null) {
      q = q.where('action', isEqualTo: actionFilter);
    }

    final snapshot = await q.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns a per-profile subcollection reference, or `null` when the caller
  /// is not authenticated.
  ///
  /// Path: `users/{uid}/learner_profiles/{profileId}/{name}`. Derives from
  /// [_learnerProfileDoc] so the learner-profile path is built in exactly one
  /// place.
  CollectionReference<Map<String, dynamic>>? _collection(
    int profileId,
    String name,
  ) => _learnerProfileDoc(profileId)?.collection(name);

  DocumentReference<Map<String, dynamic>>? _doc(
    int profileId,
    String collection,
    String docId,
  ) => _collection(profileId, collection)?.doc(docId);

  Exception get _notAuthenticated =>
      Exception('FirestoreGatewayImpl: user not authenticated');

  // ── W7.10: PERMISSION_DENIED conversion ────────────────────────────────────

  /// Wrap a Firestore operation and convert Firebase PERMISSION_DENIED errors
  /// to [FirestorePermissionDeniedException] so callers can catch a typed
  /// domain exception rather than a raw [FirebaseException].
  ///
  /// Any other [FirebaseException] is re-thrown unchanged.
  static Future<T> _guardPermission<T>(
    Future<T> Function() op, {
    String? collection,
    String? operation,
  }) async {
    try {
      return await op();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw FirestorePermissionDeniedException(
          e.message ?? 'Firestore PERMISSION_DENIED',
          collection: collection,
          operation: operation,
          cause: e,
        );
      }
      rethrow;
    }
  }
}
