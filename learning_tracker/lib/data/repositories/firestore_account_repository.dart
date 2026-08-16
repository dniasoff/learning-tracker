/// Firestore implementation for the account document and its legacy
/// free-form snapshot — Epic B (`docs/firestore-rewrite-map.md`), built to
/// the shape `lib/data/repositories/firestore_stage_definition_repository.dart`
/// establishes as the reference. See that file's class doc comment for the
/// pattern this copies. This doc comment only calls out what is DIFFERENT
/// here.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/firestore/write_ack.dart';
import 'package:learning_tracker/features/account/domain/models/account_entity.dart';

/// The fixed doc-id `FirestoreGatewayImpl.pushAccountProfile` and
/// `firestore.rules`' "LIVE LAYOUT" comment both name for the account
/// profile snapshot: `users/{uid}/profile/data`. Not routed through
/// `DocIds` — like `preferences/gamification_settings`'s scope-name
/// literal, this is a fixed constant naming a singleton document, not a
/// natural key assembled from caller data.
const String _kProfileSnapshotDocId = 'data';

/// Firestore-backed repository for `users/{uid}` (the account document) and
/// `users/{uid}/profile/{docId}` (a legacy free-form account snapshot) —
/// `docs/firestore-rewrite-map.md` (`Accounts` Drift table → `users/{uid}`),
/// `firestore.rules` `match /users/{uid}` and its nested `match
/// /profile/{docId}`.
///
/// **Not wired into the app yet** — same status as every other repository
/// under `lib/data/repositories/`: stands alone, nothing under
/// `lib/features/` reads it, the existing Drift-backed `UserProfileDao` is
/// untouched.
///
/// **No interface** — same reasoning as `FirestoreBookmarkRepository`'s doc
/// comment.
///
/// ## Two documents, two different levels of schema commitment
///
/// The account document (`users/{uid}`) is a real, typed entity —
/// [AccountEntity] — because it has an honest, load-bearing shape today
/// (`email`, `display_name`, `created_at`, `updated_at`; see that class's
/// doc comment for what was deliberately dropped: `tier`, `passwordHash`).
///
/// The `profile/{docId}` snapshot is NOT modeled as a typed entity. It has
/// no `.hasOnly()` whitelist in `firestore.rules` (same "genuinely
/// open-ended" category as `preferences/gamification_settings` and
/// `curriculum_scopes` per `docs/firestore-rewrite-map.md`), no live caller
/// anywhere in `lib/` today (`FirestoreGatewayImpl.pushAccountProfile` has
/// zero call sites outside its own interface/impl/test), and no documented
/// field set to model — inventing typed fields for a schema nobody has
/// defined would violate "only build methods with honest Firestore
/// meaning." [getProfileSnapshot]/[watchProfileSnapshot]/
/// [updateProfileSnapshot] expose it as a plain `Map<String, dynamic>`
/// instead, kept alive here only because `firestore.rules` still names the
/// path as real and an honest repository should not silently drop a path
/// the rules grant the owner read/write on.
///
/// ## `createAccount` is idempotent by design
///
/// Unlike [FirestoreGoalRepository.createGoal] (whose doc-id embeds
/// `createdAt`, so calling it twice creates two distinct documents),
/// `users/{uid}` is a FIXED doc-id — the uid never changes. A naive
/// `set(..., merge: true)` on every call would silently overwrite
/// `created_at` on a second, accidental call (e.g. a retried sign-up step).
/// [createAccount] therefore reads first and returns the existing account
/// unchanged if one is already there — the same "no-op if already exists"
/// idempotency `FirestoreStageDefinitionRepository.initializeDefaults` uses
/// for exactly the same reason.
///
/// ## No `FieldValue.delete()` handling for `email`
///
/// `FirestoreProfileProgramRepository` needs an explicit
/// `FieldValue.delete()` workaround for its genuinely nullable fields under
/// `SetOptions(merge: true)` (omitting a null field from the payload leaves
/// the OLD value in place, not null). [AccountEntity.email] does not need
/// that: it only ever transitions `null` → a real address (the anonymous →
/// linked-credential upgrade flow), never back — see
/// [AccountEntity.email]'s doc comment. [updateAccount] never intentionally
/// sends a null `email` for an account that already has one, so the trap
/// this class's sibling repositories work around does not apply here.
class FirestoreAccountRepository {
  FirestoreAccountRepository({
    required FirebaseFirestore firestore,
    required String uid,
    AppLogger? logger,
  }) : _firestore = firestore,
       _uid = uid,
       _logger = logger ?? AppLogger.instance;

  final FirebaseFirestore _firestore;
  final String _uid;
  final AppLogger _logger;

  DocumentReference<Map<String, dynamic>> get _accountDoc =>
      _firestore.collection('users').doc(_uid);

  DocumentReference<Map<String, dynamic>> get _profileSnapshotDoc =>
      _accountDoc.collection('profile').doc(_kProfileSnapshotDocId);

  AccountEntity? _decodeAccount(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) return null;
    return AccountEntity.fromFirestore(_uid, data);
  }

  /// Returns this account's document, or `null` if it does not exist yet
  /// (e.g. an anonymous session that has not called [createAccount]).
  Future<AccountEntity?> getAccount() async =>
      _decodeAccount(await _accountDoc.get());

  /// Live updates for this account's document. Resubscribes with bounded
  /// exponential backoff if the underlying listener errors
  /// (`resilientDocStream`).
  Stream<AccountEntity?> watchAccount() {
    return resilientDocStream<AccountEntity?>(
      openStream: () => _accountDoc.snapshots(),
      decode: _decodeAccount,
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_account_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'uid': _uid},
      ),
    );
  }

  /// Creates the account document if none exists yet; otherwise a no-op
  /// that returns the existing account unchanged — see the class doc
  /// comment ("`createAccount` is idempotent by design") for why this
  /// checks first rather than blindly merge-writing.
  Future<AccountEntity> createAccount({
    required String displayName,
    String? email,
  }) async {
    final existing = await getAccount();
    if (existing != null) return existing;
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final account = AccountEntity(
      uid: _uid,
      email: email,
      displayName: displayName,
      createdAt: now,
      updatedAt: now,
    );
    await _accountDoc
        .set(account.toFirestore(), SetOptions(merge: true))
        .orQueuedOffline;
    return account;
  }

  /// Updates [account] and writes the result back to `users/{uid}`.
  /// Omitting [displayName]/[email] leaves the existing value untouched —
  /// mirrors `FirestoreGoalRepository.updateGoal`'s "current entity +
  /// optional overrides" shape.
  Future<AccountEntity> updateAccount({
    required AccountEntity account,
    String? displayName,
    String? email,
  }) async {
    final now = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final updated = account.copyWith(
      displayName: displayName ?? account.displayName,
      email: email ?? account.email,
      updatedAt: now,
    );
    await _accountDoc
        .set(updated.toFirestore(), SetOptions(merge: true))
        .orQueuedOffline;
    return updated;
  }

  /// Returns the raw `users/{uid}/profile/data` snapshot, or `null` if it
  /// does not exist. See the class doc comment for why this is an untyped
  /// `Map` rather than a decoded entity.
  Future<Map<String, dynamic>?> getProfileSnapshot() async =>
      (await _profileSnapshotDoc.get()).data();

  /// Live updates for the `users/{uid}/profile/data` snapshot. Resubscribes
  /// with bounded exponential backoff if the underlying listener errors
  /// (`resilientDocStream`).
  Stream<Map<String, dynamic>?> watchProfileSnapshot() {
    return resilientDocStream<Map<String, dynamic>?>(
      openStream: () => _profileSnapshotDoc.snapshots(),
      decode: (snap) => snap.data(),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_account_profile_snapshot_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'uid': _uid},
      ),
    );
  }

  /// Merge-writes [data] into `users/{uid}/profile/data`. Open-ended by
  /// design (see the class doc comment) — callers own their own field
  /// shape; this method performs no validation beyond what
  /// `firestore.rules` itself enforces.
  Future<void> updateProfileSnapshot(Map<String, dynamic> data) async {
    await _profileSnapshotDoc
        .set(data, SetOptions(merge: true))
        .orQueuedOffline;
  }
}
