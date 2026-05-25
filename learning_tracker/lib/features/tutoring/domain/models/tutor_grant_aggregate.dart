// TutorGrant — aggregate root (W4.27)
//
// Wraps [TutorGrantDoc] (the raw Firestore DTO from W3.38) with:
//   - Sealed [GrantState] for type-safe pattern matching
//   - Business invariants and transition guards
//   - Domain methods for lifecycle transitions
//
// All state transitions are server-side (Cloud Functions). The aggregate root
// exists on the client to enforce business rules before dispatching a request.

import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';

export 'package:learning_tracker/features/tutoring/domain/models/tutor_grant.dart'
    show TutorGrantDoc, TutorGrantState;

// ── Sealed grant state ──────────────────────────────────────────────────────

/// Type-safe sealed representation of the tutor grant lifecycle state.
///
/// Mirrors [TutorGrantState] but as a sealed class hierarchy so code can
/// exhaustively pattern-match and access state-specific fields.
sealed class GrantState {
  const GrantState();

  /// Convert back to the raw [TutorGrantState] enum value.
  TutorGrantState get rawState;

  /// True when this state represents an active grant.
  bool get isActive => this is ActiveGrant;

  /// True when the grant has reached a terminal state.
  bool get isTerminal => rawState.isTerminal;
}

/// Grant is awaiting the tutor's accept/decline decision.
final class PendingGrant extends GrantState {
  const PendingGrant({required this.expiresAt});

  final DateTime expiresAt;

  @override
  TutorGrantState get rawState => TutorGrantState.pending;
}

/// Tutor has accepted and currently has access.
final class ActiveGrant extends GrantState {
  const ActiveGrant({required this.acceptedAt, required this.permissions});

  final DateTime acceptedAt;

  /// The permissions configured for this grant.
  final TutorPermissions permissions;

  @override
  TutorGrantState get rawState => TutorGrantState.active;
}

/// Tutor declined the invite.
final class DeclinedGrant extends GrantState {
  const DeclinedGrant({required this.declinedAt});
  final DateTime declinedAt;

  @override
  TutorGrantState get rawState => TutorGrantState.declined;
}

/// Parent rescinded before tutor accepted.
final class RescindedGrant extends GrantState {
  const RescindedGrant({required this.revokedAt});
  final DateTime revokedAt;

  @override
  TutorGrantState get rawState => TutorGrantState.rescinded;
}

/// Parent revoked an active grant.
final class RevokedByParentGrant extends GrantState {
  const RevokedByParentGrant({required this.revokedAt});
  final DateTime revokedAt;

  @override
  TutorGrantState get rawState => TutorGrantState.revokedByParent;
}

/// Tutor resigned from an active grant.
final class RevokedByTutorGrant extends GrantState {
  const RevokedByTutorGrant({required this.revokedAt});
  final DateTime revokedAt;

  @override
  TutorGrantState get rawState => TutorGrantState.revokedByTutor;
}

/// Pending invite expired (7-day TTL).
final class ExpiredGrant extends GrantState {
  const ExpiredGrant({required this.expiresAt});
  final DateTime expiresAt;

  @override
  TutorGrantState get rawState => TutorGrantState.expired;
}

// ── Aggregate root ──────────────────────────────────────────────────────────

/// TutorGrant aggregate root — wraps [TutorGrantDoc] with domain behaviour.
///
/// Invariants enforced:
///   - Only [PendingGrant] can transition to [ActiveGrant] (accept path).
///   - Only [PendingGrant] can transition to [RescindedGrant] or [DeclinedGrant].
///   - Only [ActiveGrant] can transition to [RevokedByParentGrant] or
///     [RevokedByTutorGrant].
///   - All actual state mutations go to Cloud Functions (Admin SDK); these
///     methods validate the precondition so the client can surface errors
///     before the network round-trip.
class TutorGrant {
  TutorGrant({required this.doc, required this.grantState});

  /// Raw Firestore document.
  final TutorGrantDoc doc;

  /// Sealed state, derived from [doc.state].
  final GrantState grantState;

  /// Convenient accessors delegated from [doc].
  String get grantId => doc.grantId;
  String get parentUid => doc.parentUid;
  String get childProfileId => doc.childProfileId;
  String get tutorEmail => doc.tutorEmail;
  String? get tutorUid => doc.tutorUid;

  /// M3: denormalised child display name (from the server), or null.
  String? get childName => doc.childName;

  /// M3: denormalised parent display name (from the server), or null.
  String? get parentName => doc.parentName;

  /// M3: best human-readable child label — the denormalised [childName] when
  /// present, otherwise a friendly generic label (never the raw Firestore id).
  String get childDisplayLabel {
    final name = doc.childName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Talmid';
  }

  /// M3: best human-readable parent label — the denormalised [parentName] when
  /// present, otherwise a friendly generic label (never the raw UID).
  String get parentDisplayLabel {
    final name = doc.parentName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Parent account';
  }

  // ── Business guards ───────────────────────────────────────────────────────

  /// True when the parent can rescind this invite (only while pending).
  bool get canRescind => grantState is PendingGrant;

  /// True when the tutor can resign from this grant (only while active).
  bool get canResign => grantState is ActiveGrant;

  /// True when the parent can revoke this grant (only while active).
  bool get canRevoke => grantState is ActiveGrant;

  /// True when the tutor can accept this invite (only while pending).
  bool get canAccept => grantState is PendingGrant;

  /// True when the tutor can decline this invite (only while pending).
  bool get canDecline => grantState is PendingGrant;

  // ── Factory ───────────────────────────────────────────────────────────────

  /// Build a [TutorGrant] from a raw [TutorGrantDoc].
  ///
  /// [permissions] is required when the grant is active; the caller is
  /// responsible for supplying the correct value (e.g. from Firestore or a
  /// default for newly accepted grants).
  factory TutorGrant.fromDoc(
    TutorGrantDoc doc, {
    TutorPermissions? permissions,
  }) {
    final grantState = _buildState(doc, permissions);
    return TutorGrant(doc: doc, grantState: grantState);
  }

  static GrantState _buildState(TutorGrantDoc doc, TutorPermissions? perms) {
    switch (doc.state) {
      case TutorGrantState.pending:
        return PendingGrant(
          expiresAt:
              doc.expiresAt ?? doc.invitedAt.add(const Duration(days: 7)),
        );
      case TutorGrantState.active:
        return ActiveGrant(
          acceptedAt: doc.acceptedAt ?? doc.updatedAt,
          permissions: perms ?? TutorPermissions.defaults(),
        );
      case TutorGrantState.declined:
        return DeclinedGrant(declinedAt: doc.declinedAt ?? doc.updatedAt);
      case TutorGrantState.rescinded:
        return RescindedGrant(revokedAt: doc.revokedAt ?? doc.updatedAt);
      case TutorGrantState.revokedByParent:
        return RevokedByParentGrant(revokedAt: doc.revokedAt ?? doc.updatedAt);
      case TutorGrantState.revokedByTutor:
        return RevokedByTutorGrant(revokedAt: doc.revokedAt ?? doc.updatedAt);
      case TutorGrantState.expired:
        return ExpiredGrant(expiresAt: doc.expiresAt ?? doc.updatedAt);
    }
  }
}
