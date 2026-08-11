/// Firestore-backed repository for `users/{uid}/diagnostic_logs/{autoId}` —
/// built to the shape `lib/data/repositories/firestore_account_repository.dart`
/// establishes as the reference. See that file's class doc comment for the
/// pattern this copies. This doc comment only calls out what is DIFFERENT
/// here.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/firestore/write_ack.dart';

/// Firestore-backed repository for the diagnostic-log upload feature
/// (Settings → "Send Diagnostic Logs"). Replaces
/// `FirestoreGatewayImpl.pushDiagnosticLog` (archived with the rest of the
/// Drift sync engine, `docs/_archive/drift-user-db/sync/`).
///
/// `firestore.rules`' `diagnostic_logs` match: `allow create: if
/// isOwner(uid); allow update, delete: if false` — append-only, owner-only,
/// no `.hasOnly()` field whitelist (genuinely open-ended, matching
/// `preferences/gamification_settings`/`curriculum_scopes`), so [pushLog]
/// takes a raw `Map` rather than a typed entity, same reasoning
/// `FirestoreAccountRepository`'s `profile/{docId}` snapshot doc comment
/// gives for its own untyped write.
class FirestoreDiagnosticLogRepository {
  FirestoreDiagnosticLogRepository({
    required FirebaseFirestore firestore,
    required String uid,
  }) : _firestore = firestore,
       _uid = uid;

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _logs =>
      _firestore.collection('users').doc(_uid).collection('diagnostic_logs');

  /// Appends one diagnostic-log document with an auto-generated id.
  ///
  /// Uses `.doc()` (a client-generated id, matching every other write in
  /// this migration — see `firestore_points_ledger_repository.dart.append`)
  /// rather than `.add()`, which returns `Future<DocumentReference>` and
  /// cannot be timed with [FirestoreWriteAck.orQueuedOffline] (a `Future<void>`
  /// extension).
  Future<void> pushLog(Map<String, dynamic> data) async {
    await _logs.doc().set(data).orQueuedOffline;
  }
}
