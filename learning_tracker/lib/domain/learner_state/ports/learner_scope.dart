/// The `(ownerUid, profileId)` pair every profile-scoped learner-state
/// repository is addressed by.
///
/// Orchestrator ruling B10: profile-scoped repositories take an explicit
/// scope rather than hard-coding the signed-in uid, so a tutor device can
/// read a talmid's log through the same port (Story 4.2a). The owner path
/// is `LearnerScope(ownerUid: <path uid>, profileId: <active profile>)`.
library;

import 'package:learning_tracker/domain/learner_state/storage_codec.dart';

/// Addresses `users/{ownerUid}/learner_profiles/{profileId}`.
final class LearnerScope {
  /// Creates a scope; throws [ArgumentError] for an empty owner uid or a
  /// non-ULID profile id (parent AD-5: never let an id fall back to
  /// something Firestore would invent).
  LearnerScope({required this.ownerUid, required this.profileId}) {
    if (ownerUid.isEmpty || ownerUid.contains('/')) {
      throw ArgumentError.value(ownerUid, 'ownerUid', 'invalid path uid');
    }
    if (!isUlid(profileId)) {
      throw ArgumentError.value(profileId, 'profileId', 'not a ULID');
    }
  }

  /// The Firestore path uid of the profile's owner account.
  final String ownerUid;

  /// The learner-profile ULID.
  final String profileId;

  /// `users/{ownerUid}/learner_profiles/{profileId}`.
  String get profilePath => 'users/$ownerUid/learner_profiles/$profileId';

  @override
  bool operator ==(Object other) =>
      other is LearnerScope &&
      other.ownerUid == ownerUid &&
      other.profileId == profileId;

  @override
  int get hashCode => Object.hash(ownerUid, profileId);

  @override
  String toString() => 'LearnerScope($profileId)';
}
