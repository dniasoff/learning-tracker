// TutorGrant — top-level Firestore document model (W3.38)
//
// Firestore collection: tutor_grants/{grantId}
//
// Deterministic doc-id strategy (from tutor-mode-brief.md):
//   {tutorUidOrEmailHash}_{parentUid}_{childProfileId}
//
// This is the raw data transfer object; the TutorGrant aggregate root
// (with sealed GrantState, business methods, and invariants) is
// introduced in W4.27.

/// State lifecycle for a tutor grant.
///
/// Transitions (single-direction, no reversal):
///   pending → active (tutor accepts)
///   pending → declined (tutor declines)
///   pending → rescinded (parent rescinds before acceptance)
///   pending → expired (7-day TTL — enforced server-side)
///   active → revoked_by_parent (parent revokes)
///   active → revoked_by_tutor (tutor resigns)
enum TutorGrantState {
  pending,
  active,
  declined,
  rescinded,
  revokedByParent,
  revokedByTutor,
  expired;

  String toJson() => switch (this) {
    TutorGrantState.pending => 'pending',
    TutorGrantState.active => 'active',
    TutorGrantState.declined => 'declined',
    TutorGrantState.rescinded => 'rescinded',
    TutorGrantState.revokedByParent => 'revoked_by_parent',
    TutorGrantState.revokedByTutor => 'revoked_by_tutor',
    TutorGrantState.expired => 'expired',
  };

  static TutorGrantState fromJson(String value) => switch (value) {
    'pending' => TutorGrantState.pending,
    'active' => TutorGrantState.active,
    'declined' => TutorGrantState.declined,
    'rescinded' => TutorGrantState.rescinded,
    'revoked_by_parent' => TutorGrantState.revokedByParent,
    'revoked_by_tutor' => TutorGrantState.revokedByTutor,
    'expired' => TutorGrantState.expired,
    _ => throw ArgumentError('Unknown TutorGrantState: $value'),
  };

  /// True when the tutor currently has access to the child's profile.
  bool get isActive => this == TutorGrantState.active;

  /// True when the grant is in a terminal state.
  bool get isTerminal => switch (this) {
    TutorGrantState.declined ||
    TutorGrantState.rescinded ||
    TutorGrantState.revokedByParent ||
    TutorGrantState.revokedByTutor ||
    TutorGrantState.expired => true,
    _ => false,
  };
}

/// Raw Firestore document for a tutor grant.
///
/// See [TutorGrantState] for lifecycle semantics.
/// The aggregate root (W4.27) wraps this with domain methods.
class TutorGrantDoc {
  const TutorGrantDoc({
    required this.grantId,
    required this.parentUid,
    required this.childProfileId,
    required this.tutorEmail,
    required this.state,
    required this.invitedAt,
    required this.updatedAt,
    this.tutorUid,
    this.inviteToken,
    this.acceptedAt,
    this.declinedAt,
    this.revokedAt,
    this.expiresAt,
  });

  /// Matches the Firestore document ID.
  final String grantId;

  /// UID of the parent who issued the invite.
  final String parentUid;

  /// Profile ID of the child being shared.
  final String childProfileId;

  /// Canonical lower-cased tutor email.
  final String tutorEmail;

  /// Firebase Auth UID of the tutor — null until acceptance.
  final String? tutorUid;

  /// Current lifecycle state.
  final TutorGrantState state;

  /// Single-use invite token — present only in [TutorGrantState.pending].
  final String? inviteToken;

  final DateTime invitedAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? revokedAt;

  /// When the pending invite expires (7-day default from invitation).
  final DateTime? expiresAt;

  final DateTime updatedAt;

  /// Deterministic doc ID from the three key identifiers.
  ///
  /// Using `tutorEmail` (not tutorUid) so the document can be created
  /// before the tutor has a Firebase account. On acceptance, the tutor_uid
  /// field is filled in and the client can do an O(1) look-up.
  static String buildGrantId({
    required String tutorEmail,
    required String parentUid,
    required String childProfileId,
  }) {
    // Simple concatenation with separator (colons are not valid in doc IDs;
    // underscores are safe). Email special chars are URL-encoded.
    final encodedEmail = tutorEmail.toLowerCase().replaceAll(
      // ignore: unnecessary_raw_strings — raw string is clearer for regex char classes
      RegExp(r'[^a-zA-Z0-9]'),
      '_',
    );
    // Braces required: `$encodedEmail__` would parse as identifier `encodedEmail__`.
    // ignore: unnecessary_brace_in_string_interps
    return '${encodedEmail}__${parentUid}__${childProfileId}';
  }

  Map<String, dynamic> toFirestore() => {
    'grant_id': grantId,
    'parent_uid': parentUid,
    'child_profile_id': childProfileId,
    'tutor_email': tutorEmail,
    if (tutorUid != null) 'tutor_uid': tutorUid,
    'state': state.toJson(),
    if (inviteToken != null) 'invite_token': inviteToken,
    'invited_at': invitedAt.toUtc().toIso8601String(),
    if (acceptedAt != null)
      'accepted_at': acceptedAt!.toUtc().toIso8601String(),
    if (declinedAt != null)
      'declined_at': declinedAt!.toUtc().toIso8601String(),
    if (revokedAt != null) 'revoked_at': revokedAt!.toUtc().toIso8601String(),
    if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory TutorGrantDoc.fromFirestore(Map<String, dynamic> data) {
    DateTime? parseTs(dynamic v) {
      if (v == null) return null;
      if (v is String) return DateTime.parse(v).toLocal();
      // Firestore Timestamp from the SDK has a toDate() method.
      // Cast through dynamic to avoid importing firebase packages outside core/.
      try {
        // ignore: avoid_dynamic_calls — Firebase Timestamp.toDate() is not
        // importable outside core/sync/ per layering rules. We use dynamic
        // to bridge the gap without a firebase import in domain code.
        final ts = v as dynamic;
        // ignore: avoid_dynamic_calls
        final dt = ts.toDate() as DateTime?;
        return dt?.toLocal();
      } catch (_) {
        return null;
      }
    }

    return TutorGrantDoc(
      grantId: data['grant_id'] as String,
      parentUid: data['parent_uid'] as String,
      childProfileId: data['child_profile_id'] as String,
      tutorEmail: data['tutor_email'] as String,
      tutorUid: data['tutor_uid'] as String?,
      state: TutorGrantState.fromJson(data['state'] as String),
      inviteToken: data['invite_token'] as String?,
      invitedAt: DateTime.parse(data['invited_at'] as String).toLocal(),
      acceptedAt: parseTs(data['accepted_at']),
      declinedAt: parseTs(data['declined_at']),
      revokedAt: parseTs(data['revoked_at']),
      expiresAt: parseTs(data['expires_at']),
      updatedAt: DateTime.parse(data['updated_at'] as String).toLocal(),
    );
  }

  TutorGrantDoc copyWith({
    String? tutorUid,
    TutorGrantState? state,
    String? inviteToken,
    DateTime? acceptedAt,
    DateTime? declinedAt,
    DateTime? revokedAt,
    DateTime? expiresAt,
    DateTime? updatedAt,
  }) => TutorGrantDoc(
    grantId: grantId,
    parentUid: parentUid,
    childProfileId: childProfileId,
    tutorEmail: tutorEmail,
    tutorUid: tutorUid ?? this.tutorUid,
    state: state ?? this.state,
    inviteToken: inviteToken ?? this.inviteToken,
    invitedAt: invitedAt,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    declinedAt: declinedAt ?? this.declinedAt,
    revokedAt: revokedAt ?? this.revokedAt,
    expiresAt: expiresAt ?? this.expiresAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
