import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';

part 'learner_profile_entity.freezed.dart';

/// Domain entity for a Firestore learner profile:
/// `users/{uid}/learner_profiles/{profileId}` (`docs/firestore-rewrite-map.md`
/// — `LearnerProfiles` Drift table → `learner_profiles/{profileId}`;
/// `firestore.rules` `match /learner_profiles/{profileId}`).
///
/// **Not [ProfileModel]** (`profile_model.dart`, same feature) — that model
/// wraps the Drift `LearnerProfile` row (`required int id`, `required int
/// accountId`, `int avatarIndex`). None of those fit here: [profileId] is a
/// per-profile stable **ULID string** (AD-24), never the Drift-local
/// autoincrement int and never the account uid — an account owns *many*
/// profiles, so keying every profile doc-id by the shared uid would collide
/// every child of that account onto one document
/// (`lib/data/firestore/doc_ids.dart`'s [DocIds.learnerProfileUlidDocId] doc
/// comment). [accountId] does not exist on this entity at all — the
/// `users/{uid}` path segment already scopes every profile to its account,
/// so persisting a redundant account reference field would just be a second
/// place for that fact to go stale (and, incidentally, is exactly the kind
/// of Drift-autoincrement-id-in-payload shape the MCF-11 ratchet exists to
/// catch for `account_id`).
///
/// **No `isTutored`/`tutorParentUid`/`tutorRemoteProfileId`/`tutorGrantId`.**
/// Tutored mirror profiles are deleted as a concept, not ported — the old
/// sync engine copied a tutored child's data into the tutor's local DB
/// because Drift had no way to read another account's rows directly.
/// `firestore.rules` already grants a tutor direct read on
/// `users/{parentUid}/learner_profiles/{profileId}` and all 15
/// subcollections via `hasActiveTutorAccess()` — a tutor reads the parent's
/// tree directly, so there is nothing left for a mirror field to record.
///
/// **`avatar` is a non-nullable `String`, defaulting to `''`** — deliberately
/// NOT `String?`. `functions/src/tutor_writes.ts`'s `tutorEditProfile` (the
/// second writer this repository's `SetOptions(merge: true)` writes must
/// stay byte-compatible with) validates `avatar` as "if provided, a
/// non-empty string" and never offers a way to clear it back to absent —
/// avatar-as-chosen is a one-way "unset → some identifier" transition in
/// practice, exactly like Drift's `avatarIndex` defaulting to `0` rather
/// than being nullable. Because it is never null, `toFirestore()` never
/// needs to omit it, and the repository never needs the
/// `SetOptions(merge: true)` + `FieldValue.delete()` field-clearing
/// workaround `FirestoreProfileProgramRepository` needs for its genuinely
/// nullable fields.
@freezed
abstract class LearnerProfileEntity with _$LearnerProfileEntity {
  const LearnerProfileEntity._();

  const factory LearnerProfileEntity({
    /// The learner-profile ULID doc-id (AD-24). Not written into the
    /// document body — the path already carries it, matching
    /// `GoalEntity`/`BookmarkEntity`'s doc-id-omission convention.
    required String profileId,
    required String displayName,
    required ProfileMode mode,
    @Default('') String avatar,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _LearnerProfileEntity;

  /// Encodes this profile for a Firestore write. Field names match
  /// `tutorEditProfile`'s payload exactly (`display_name`, `avatar`, `mode`,
  /// plus `created_at`/`updated_at`) so an owner write and a tutor-proxy
  /// write land byte-compatible shapes.
  Map<String, dynamic> toFirestore() => {
    'display_name': displayName,
    'mode': mode.storageKey,
    'avatar': avatar,
    'created_at': FirestoreCodec.encodeDateTime(createdAt),
    'updated_at': FirestoreCodec.encodeDateTime(updatedAt),
  };

  /// Decodes a `learner_profiles/{profileId}` document. [profileId] comes
  /// from the caller (`doc.id`, mirroring `AccountEntity.fromFirestore`'s
  /// `uid` parameter) since it is not stored in the document body.
  ///
  /// An unrecognised/missing `mode` falls back to [ProfileMode.adult] —
  /// mirrors [ProfileModel.profileMode]'s established fallback (never
  /// throws for this field; `mode` drives UI affordances, not identity).
  /// Throws [FormatException] when `created_at`/`updated_at` are missing or
  /// unparseable — see [AccountEntity.fromFirestore] for the same
  /// throw-vs-silently-default reasoning.
  static LearnerProfileEntity fromFirestore(
    String profileId,
    Map<String, dynamic> data,
  ) {
    final createdAt = FirestoreCodec.parseDateTime(data['created_at']);
    final updatedAt = FirestoreCodec.parseDateTime(data['updated_at']);
    if (createdAt == null || updatedAt == null) {
      throw FormatException(
        'learner_profiles/$profileId document missing '
        'created_at/updated_at: $data',
      );
    }
    return LearnerProfileEntity(
      profileId: profileId,
      displayName: data['display_name'] as String? ?? '',
      mode:
          ProfileMode.tryFromStorageKey(data['mode'] as String? ?? '') ??
          ProfileMode.adult,
      avatar: data['avatar'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
