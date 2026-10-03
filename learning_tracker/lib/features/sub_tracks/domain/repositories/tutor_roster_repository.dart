/// The tutor-roster read seam behind My talmidim (Story 4.3, DNI-511, T1;
/// FR-29, AD-53).
///
/// One entry per ACTIVE `tutor_grants` document naming the signed-in tutor,
/// with the learner identity the row needs and the grant's effective
/// permissions. Pending, revoked, resigned and expired grants never reach
/// the roster. A failed read is an error — never an empty roster — so the
/// screen can tell "no talmidim yet" from "could not load" (AC-6).
library;

import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart'
    show TutorPermissions;

/// One talmid on the tutor's roster: an active grant and its learner.
final class TalmidRosterEntry {
  /// Creates an entry.
  const TalmidRosterEntry({
    required this.grantId,
    required this.ownerUid,
    required this.profileId,
    required this.permissions,
    this.displayName,
  });

  /// The `tutor_grants` document id.
  final String grantId;

  /// The parent account that owns the learner profile (`parent_uid`).
  final String ownerUid;

  /// The learner profile id (`child_profile_id`).
  final String profileId;

  /// The server-denormalised learner name; null when the server has none.
  final String? displayName;

  /// The grant's effective permissions (AD-53).
  final TutorPermissions permissions;

  /// `tutor_grants/{grantId}.permissions.can_edit_learning` — the one AD-53
  /// write permission. A grant without the field reads as false; legacy
  /// edit keys are never consulted.
  bool get canEditLearning => permissions.canEditLearning;

  /// The learner's [LearnerScope]; null when the grant names an id that
  /// cannot address a learner subtree (never fabricated, AD-24).
  LearnerScope? get scope {
    try {
      return LearnerScope(ownerUid: ownerUid, profileId: profileId);
    } on ArgumentError {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TalmidRosterEntry &&
      other.grantId == grantId &&
      other.ownerUid == ownerUid &&
      other.profileId == profileId &&
      other.displayName == displayName &&
      other.permissions == permissions;

  @override
  int get hashCode =>
      Object.hash(grantId, ownerUid, profileId, displayName, permissions);

  @override
  String toString() => 'TalmidRosterEntry($grantId)';
}

/// The tutor's active-grant roster.
abstract interface class TutorRosterRepository {
  /// The signed-in tutor's ACTIVE grants, from one authoritative read.
  ///
  /// A successful empty result is authoritative (every grant was revoked or
  /// none was ever given). Throws [TutorRosterLoadException] when the read
  /// did not succeed, so a failure is never shown as an empty roster.
  Future<List<TalmidRosterEntry>> loadActiveTalmidim();
}

/// The roster read did not complete (offline, transient or refused). Carries
/// no learner data.
final class TutorRosterLoadException extends NetworkException {
  /// Creates the exception.
  const TutorRosterLoadException() : super('tutor roster read failed');
}
