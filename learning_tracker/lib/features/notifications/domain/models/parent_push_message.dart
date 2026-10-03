/// Wire and session values of the parent push (sub-tracks Story 4.7 /
/// DNI-515, AD-39): the data-only FCM payload `onChangeLogCreated` sends, the
/// local parent-session marker that decides whether it may be shown, and the
/// notification-tap payload that leads to the learner's Change history.
library;

import 'dart:convert';

/// The change kinds the trigger reports (`functions/src/notifications.ts`
/// `PushKind`). Unknown wire values parse to [other], which still shows a
/// generic line rather than dropping a real tutor change.
enum ParentPushKind {
  deadline,
  pace,
  mainTrack,
  mainTrackOrder,
  mainTrackProgram,
  mainTrackStudyDays,
  other;

  /// Parses a wire `kind`.
  static ParentPushKind fromWire(String? wire) => ParentPushKind.values
      .firstWhere((k) => k != other && k.name == wire, orElse: () => other);
}

/// The data payload `type` of a tutor-change push.
const String kParentPushType = 'tutor_change';

/// A parsed tutor-change push.
final class ParentPushMessage {
  /// Creates a message.
  const ParentPushMessage({
    required this.ownerUid,
    required this.profileId,
    required this.actionId,
    required this.kind,
    required this.tutorName,
    required this.learnerName,
  });

  /// Parses an FCM data map, or returns null when it is not a well-formed
  /// tutor-change push (any other data message is ignored).
  static ParentPushMessage? tryParse(Map<String, dynamic> data) {
    if (data['type'] != kParentPushType) return null;
    final owner = data['owner_uid'];
    final profile = data['profile_id'];
    final action = data['action_id'];
    if (owner is! String || owner.isEmpty) return null;
    if (profile is! String || profile.isEmpty) return null;
    if (action is! String || action.isEmpty) return null;
    final tutor = data['tutor_name'];
    final learner = data['learner_name'];
    return ParentPushMessage(
      ownerUid: owner,
      profileId: profile,
      actionId: action,
      kind: ParentPushKind.fromWire(data['kind'] as String?),
      tutorName: tutor is String ? tutor : '',
      learnerName: learner is String ? learner : '',
    );
  }

  /// Firestore path uid of the account that owns the learner.
  final String ownerUid;

  /// The learner's profile id (AD-24 ULID).
  final String profileId;

  /// The tutor action this push reports (one push per action).
  final String actionId;

  /// What the tutor changed.
  final ParentPushKind kind;

  /// The tutor's display name (may be empty).
  final String tutorName;

  /// The learner's display name (may be empty).
  final String learnerName;

  /// The tap payload of the local notification posted for this message.
  ParentPushTap get tap =>
      ParentPushTap(ownerUid: ownerUid, profileId: profileId);
}

/// Where a tapped parent push leads: the Change history of [profileId] in
/// the account [ownerUid] — still behind the route's parent PIN gate.
final class ParentPushTap {
  /// Creates a tap target.
  const ParentPushTap({required this.ownerUid, required this.profileId});

  /// Prefix that marks a local-notification payload as a parent push.
  static const String payloadPrefix = 'parent_push:';

  /// Parses a local-notification payload, or null when it is not a parent
  /// push tap.
  static ParentPushTap? tryParsePayload(String? payload) {
    if (payload == null || !payload.startsWith(payloadPrefix)) return null;
    try {
      final map = jsonDecode(payload.substring(payloadPrefix.length));
      if (map is! Map) return null;
      final owner = map['o'];
      final profile = map['p'];
      if (owner is! String || owner.isEmpty) return null;
      if (profile is! String || profile.isEmpty) return null;
      return ParentPushTap(ownerUid: owner, profileId: profile);
    } on FormatException {
      return null;
    }
  }

  /// Owning account's path uid.
  final String ownerUid;

  /// Learner profile id.
  final String profileId;

  /// The local-notification payload string.
  String toPayload() =>
      '$payloadPrefix${jsonEncode({'o': ownerUid, 'p': profileId})}';

  /// Whether this tap may open the Change history right now: only in the
  /// owning account, in an own (not tutored) session, with this learner
  /// selected. The route's own guards then still require the parent PIN.
  bool opensHistory({
    required String? currentOwnerUid,
    required String? selectedProfileId,
    required bool isTutoredSession,
  }) =>
      !isTutoredSession &&
      currentOwnerUid == ownerUid &&
      selectedProfileId == profileId;

  @override
  bool operator ==(Object other) =>
      other is ParentPushTap &&
      other.ownerUid == ownerUid &&
      other.profileId == profileId;

  @override
  int get hashCode => Object.hash(ownerUid, profileId);
}

/// The durable local marker of an unlocked parent PIN session on this
/// install. Written on parent unlock, cleared synchronously on every lock
/// (and at cold start, when the in-memory PIN session is always locked).
/// A push is shown only while it names the push's owner and learner (AC-5).
final class ParentPushSession {
  /// Creates a session marker.
  const ParentPushSession({
    required this.accountId,
    required this.ownerUid,
    required this.profileId,
  });

  /// Parses a stored marker, or null when absent or malformed.
  static ParentPushSession? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final account = map['account_id'];
      final owner = map['owner_uid'];
      final profile = map['profile_id'];
      if (account is! String || owner is! String || profile is! String) {
        return null;
      }
      return ParentPushSession(
        accountId: account,
        ownerUid: owner,
        profileId: profile,
      );
    } on FormatException {
      return null;
    }
  }

  /// Device-registry account id that registered the token.
  final String accountId;

  /// Firestore path uid of that account.
  final String ownerUid;

  /// The learner whose parent PIN is unlocked.
  final String profileId;

  /// The stored form.
  String encode() => jsonEncode({
    'account_id': accountId,
    'owner_uid': ownerUid,
    'profile_id': profileId,
  });

  /// Whether [message] may be shown while this session is unlocked.
  bool allows(ParentPushMessage message) =>
      message.ownerUid == ownerUid && message.profileId == profileId;

  @override
  bool operator ==(Object other) =>
      other is ParentPushSession &&
      other.accountId == accountId &&
      other.ownerUid == ownerUid &&
      other.profileId == profileId;

  @override
  int get hashCode => Object.hash(accountId, ownerUid, profileId);
}
