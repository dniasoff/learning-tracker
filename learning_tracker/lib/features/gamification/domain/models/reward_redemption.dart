import 'package:learning_tracker/core/codec/firestore_codec.dart';

/// A child's prize-redemption request and its state-machine status.
///
/// Firestore doc: `reward_redemptions/{ulid}`
/// (`DocIds.rewardRedemptionDocId`, `firestore.rules` `match
/// /reward_redemptions/{redemptionId}` — an open-bag collection, no field
/// whitelist). `status` moves `pending_fulfilment` -> `fulfilled` (parent
/// hands over the prize) or `pending_fulfilment` -> `declined` (parent
/// refunds the points) — never deleted (`allow delete: if false`).
class RewardRedemptionStatus {
  static const pendingFulfilment = 'pending_fulfilment';
  static const fulfilled = 'fulfilled';
  static const declined = 'declined';
}

class RewardRedemptionEntity {
  const RewardRedemptionEntity({
    required this.ulid,
    required this.rewardTitle,
    required this.iconIndex,
    required this.pointsCost,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  final String ulid;
  final String rewardTitle;
  final int iconIndex;
  final int pointsCost;

  /// One of [RewardRedemptionStatus]'s values.
  final String status;
  final DateTime createdAt;

  /// When the parent fulfilled or declined this request — `null` while
  /// still `pending_fulfilment`.
  final DateTime? resolvedAt;
}

/// Firestore codec for [RewardRedemptionEntity].
extension RewardRedemptionFirestoreCodec on RewardRedemptionEntity {
  Map<String, dynamic> toFirestore() {
    return {
      'ulid': ulid,
      'reward_title': rewardTitle,
      'icon_index': iconIndex,
      'points_cost': pointsCost,
      'status': status,
      'created_at': FirestoreCodec.encodeDateTime(createdAt),
      if (resolvedAt != null)
        'resolved_at': FirestoreCodec.encodeDateTime(resolvedAt),
    };
  }
}

/// Decodes a `reward_redemptions/{ulid}` document into a
/// [RewardRedemptionEntity]. Throws [FormatException] for a document
/// missing required fields — a caller-visible decode failure by design,
/// never silently defaulted.
RewardRedemptionEntity rewardRedemptionFromFirestore(
  Map<String, dynamic> data,
) {
  final ulid = data['ulid'] as String?;
  final rewardTitle = data['reward_title'] as String?;
  final status = data['status'] as String?;
  if (ulid == null || rewardTitle == null || status == null) {
    throw FormatException(
      'reward_redemptions document missing a required field: $data',
    );
  }
  final createdAt =
      DateTime.tryParse(data['created_at']?.toString() ?? '') ??
      (throw FormatException(
        'reward_redemptions document has an unparseable created_at: $data',
      ));
  final resolvedAtRaw = data['resolved_at'];
  final resolvedAt = resolvedAtRaw == null
      ? null
      : DateTime.tryParse(resolvedAtRaw.toString());

  return RewardRedemptionEntity(
    ulid: ulid,
    rewardTitle: rewardTitle,
    iconIndex: FirestoreCodec.parseInt(data['icon_index']) ?? 0,
    pointsCost: FirestoreCodec.parseInt(data['points_cost']) ?? 0,
    status: status,
    createdAt: createdAt,
    resolvedAt: resolvedAt,
  );
}
