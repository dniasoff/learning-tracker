import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/codec/firestore_codec.dart';

part 'account_entity.freezed.dart';

/// Domain entity for the Firestore account document: `users/{uid}`
/// (`docs/firestore-rewrite-map.md` — `Accounts` Drift table → `users/{uid}`;
/// `firestore.rules` `match /users/{uid}`).
///
/// **Not the same thing as [AppUser]** (`app_user.dart`, same feature). Reads
/// from `FirebaseAuth` directly — the live session, recomputed every time
/// from SDK state, with no persisted `createdAt`/`updatedAt` of its own.
/// [AccountEntity] is the Firestore-persisted account RECORD this app keeps
/// alongside the auth session — the two are deliberately separate concerns
/// that happen to overlap on `uid`/`email`/`displayName`.
///
/// **No `tier` field — deliberate, not an oversight.** The pre-rewrite
/// `Accounts` Drift table carried a `tier` column (`cloudBorn` | `localBorn`)
/// set once at signup. Under the current design every account has a real
/// Firebase uid from creation (anonymous at creation; `linkWithCredential`
/// on upgrade preserves the uid) — so "cloud-born vs local-born" collapses
/// to exactly "anonymous vs has-linked-credentials", a live `FirebaseAuth`
/// property (`User.isAnonymous` / `providerData`), not something this
/// entity needs to persist or that this repository needs to write.
///
/// **No `passwordHash` field.** That column is local-only (argon2id hash for
/// a local-born account, used to unlock the on-device Drift database before
/// any network round-trip is possible) and never had a Firestore
/// counterpart in the live gateway (`FirestoreGatewayImpl.
/// pushAccountUserProfile`'s only real caller sends `{'displayName': ...}`
/// only — see `lib/features/onboarding/domain/services/
/// user_profile_service.dart`). Nothing in this rewrite carries it to
/// Firestore.
@freezed
abstract class AccountEntity with _$AccountEntity {
  const AccountEntity._();

  const factory AccountEntity({
    /// Firebase uid — also the `users/{uid}` doc-id. Not written into the
    /// document body itself (the path already carries it; matches
    /// `GoalEntity`/`BookmarkEntity` never re-storing their own doc-id
    /// components redundantly).
    required String uid,

    /// `null` until the account is upgraded from anonymous (the
    /// credential-less offline-account flow supplies a real email at
    /// `linkWithCredential` time; see `docs/firestore-rewrite-map.md`'s
    /// "Owner decisions" section). Deliberately never cleared once set —
    /// see [FirestoreAccountRepository.updateAccount]'s doc comment for why
    /// that means no `FieldValue.delete()` handling is needed for this
    /// field.
    String? email,
    required String displayName,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AccountEntity;

  /// Encodes this account for a Firestore write. [uid] is never included —
  /// see the constructor doc comment.
  Map<String, dynamic> toFirestore() => {
    'email': email,
    'display_name': displayName,
    'created_at': FirestoreCodec.encodeDateTime(createdAt),
    'updated_at': FirestoreCodec.encodeDateTime(updatedAt),
  };

  /// Decodes a `users/{uid}` document into an [AccountEntity]. [uid] comes
  /// from the caller (the path segment, mirroring
  /// `LearnerProfileEntity.fromFirestore`'s `profileId` parameter) — it is
  /// never read from the document body.
  ///
  /// Throws [FormatException] when `created_at`/`updated_at` are missing or
  /// unparseable — a caller-visible decode failure by design, same as
  /// `GoalEntity.fromFirestore`/`stageDefinitionFromFirestore`, never
  /// silently defaulted.
  static AccountEntity fromFirestore(String uid, Map<String, dynamic> data) {
    final createdAt = FirestoreCodec.parseDateTime(data['created_at']);
    final updatedAt = FirestoreCodec.parseDateTime(data['updated_at']);
    if (createdAt == null || updatedAt == null) {
      throw FormatException(
        'users/$uid document missing created_at/updated_at: $data',
      );
    }
    return AccountEntity(
      uid: uid,
      email: data['email'] as String?,
      displayName: data['display_name'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
