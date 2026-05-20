/// Zero-cost typed IDs for database primary keys and natural identifiers.
///
/// Each extension type is a compile-time wrapper around its underlying
/// primitive — at runtime the value is exactly the primitive with no
/// allocation overhead.
///
/// ## Motivation (W3.1 / W3.2)
/// Using `int profileId` everywhere allows accidental mixing of e.g. a
/// track ID where a profile ID is expected. Extension types prevent that at
/// the call-site while keeping the Drift schema free of runtime objects.
///
/// ## Conversion
/// ```dart
/// final id = ProfileId(42);
/// final raw = id.value;       // 42 — to pass into a Drift query
/// final same = ProfileId(raw); // wrap again at the boundary
/// ```
///
/// The extension types **do not** replace the Drift-generated int columns —
/// they are used at domain / repository boundaries where mixing IDs of
/// different entities would be a bug.
library;

/// Typed wrapper for `learner_profiles.id`.
extension type ProfileId(int value) implements int {}

/// Typed wrapper for `curriculum_tracks.id`.
extension type TrackId(int value) implements int {}

/// Typed wrapper for `stage_definitions.id`.
extension type StageId(int value) implements int {}

/// Typed wrapper for a Sefaria reference string (natural key, not a row id).
///
/// Distinct from the full [SefariaRef] value object in
/// `core/domain/value_objects/sefaria_ref.dart` — this is the lightweight
/// identity-only variant used in Firestore document keys and merger natural
/// keys.
extension type SefariaRefId(String value) implements String {}

/// Typed wrapper for a Firebase UID (`accounts.firebase_uid`).
extension type UserId(String value) implements String {}

/// Typed wrapper for a tutor-grant document ID (Firestore `tutor_grants/{id}`).
extension type TutorGrantId(String value) implements String {}
