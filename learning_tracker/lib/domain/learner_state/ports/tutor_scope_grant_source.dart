/// The grant-scoped learner read seam (Story 4.2a, DNI-523, ruling B10).
///
/// A tutor device reads another owner's learner tree through the same
/// [LearnerScope]-keyed repositories the owner uses. Firestore rules already
/// authorize that read (`hasActiveTutorAccess`); this port lets the client
/// decide, live and per scope, whether an active `tutor_grants` document
/// still authorizes the signed-in tutor, so a revoked or stale scope fails
/// closed instead of rendering an empty or stale learner.
///
/// The validation is the one `_watchActiveAccountAndProfile`
/// (`lib/data/firestore/repository_providers.dart`) applies to a single
/// tutored selection: `state == 'active'`, `tutor_uid` is the signed-in uid,
/// and `parent_uid` / `child_profile_id` match the scope.
///
/// Pure Dart (AD-35): no Firestore, Flutter or Riverpod import.
library;

import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

/// Why a tutor may not read a [LearnerScope].
enum TutorScopeDenialReason {
  /// No account is signed in, so there is no tutor uid to check.
  notSignedIn,

  /// No `tutor_grants` document names this tutor, owner and profile.
  noGrant,

  /// A matching grant exists, but none is `active` (pending, revoked,
  /// resigned, expired, ...).
  grantNotActive,

  /// The server refused a read (`permission-denied`): the access index was
  /// removed, so the grant is gone even if the client has not seen it yet.
  permissionDenied,
}

/// The live verdict for one [LearnerScope].
sealed class TutorScopeGrantVerdict {
  const TutorScopeGrantVerdict();
}

/// An active grant authorizes the signed-in tutor to read the scope.
final class TutorScopeGranted extends TutorScopeGrantVerdict {
  /// Creates the verdict for the authorizing grant [grantId].
  const TutorScopeGranted(this.grantId);

  /// The `tutor_grants` document id that authorizes the read.
  final String grantId;

  @override
  bool operator ==(Object other) =>
      other is TutorScopeGranted && other.grantId == grantId;

  @override
  int get hashCode => Object.hash(TutorScopeGranted, grantId);

  @override
  String toString() => 'TutorScopeGranted($grantId)';
}

/// The signed-in tutor may not read the scope.
final class TutorScopeDenied extends TutorScopeGrantVerdict {
  /// Creates the verdict for [reason].
  const TutorScopeDenied(this.reason);

  /// Why the read is refused.
  final TutorScopeDenialReason reason;

  @override
  bool operator ==(Object other) =>
      other is TutorScopeDenied && other.reason == reason;

  @override
  int get hashCode => Object.hash(TutorScopeDenied, reason);

  @override
  String toString() => 'TutorScopeDenied(${reason.name})';
}

/// The error a grant-scoped learner read surfaces when the tutor has no
/// (or has lost) access to [scope]. A consumer that sees it must drop
/// everything it holds for that scope (DNI-512).
final class TutorScopeAccessDeniedException implements Exception {
  /// Creates the exception.
  const TutorScopeAccessDeniedException(this.scope, this.reason);

  /// The scope that may not be read.
  final LearnerScope scope;

  /// Why.
  final TutorScopeDenialReason reason;

  @override
  bool operator ==(Object other) =>
      other is TutorScopeAccessDeniedException &&
      other.scope == scope &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(scope, reason);

  @override
  String toString() =>
      'TutorScopeAccessDeniedException(${reason.name}): $scope';
}

/// One `tutor_grants` document in storage form: its id and its fields.
typedef TutorGrantRecord = ({String id, Map<String, Object?> data});

/// The verdict for [scope] given the `tutor_grants` documents [grants] that
/// the signed-in [tutorUid] can see.
///
/// A record counts only when its `tutor_uid`, `parent_uid` and
/// `child_profile_id` all match; any matching record whose `state` is
/// `'active'` grants (the lowest such id, for a stable result). Matching
/// records that are all inactive give [TutorScopeDenialReason.grantNotActive];
/// no matching record gives [TutorScopeDenialReason.noGrant].
TutorScopeGrantVerdict evaluateTutorScopeGrants({
  required String tutorUid,
  required LearnerScope scope,
  required Iterable<TutorGrantRecord> grants,
}) {
  if (tutorUid.isEmpty) {
    return const TutorScopeDenied(TutorScopeDenialReason.notSignedIn);
  }
  String? grantedId;
  var anyMatch = false;
  for (final grant in grants) {
    final data = grant.data;
    if (data['tutor_uid'] != tutorUid ||
        data['parent_uid'] != scope.ownerUid ||
        data['child_profile_id'] != scope.profileId) {
      continue;
    }
    anyMatch = true;
    if (data['state'] == 'active' &&
        (grantedId == null || grant.id.compareTo(grantedId) < 0)) {
      grantedId = grant.id;
    }
  }
  if (grantedId != null) return TutorScopeGranted(grantedId);
  return TutorScopeDenied(
    anyMatch
        ? TutorScopeDenialReason.grantNotActive
        : TutorScopeDenialReason.noGrant,
  );
}

/// Live authorization of the signed-in tutor over learner scopes.
abstract interface class TutorScopeGrantSource {
  /// The verdict for [scope], re-emitted whenever a matching grant changes.
  ///
  /// Emits nothing until the first complete read (no emission means
  /// loading). A `permission-denied` read is a [TutorScopeDenied] with
  /// [TutorScopeDenialReason.permissionDenied], not an error; any other
  /// failure is an error event, and the stream keeps listening.
  Stream<TutorScopeGrantVerdict> watch(LearnerScope scope);
}
