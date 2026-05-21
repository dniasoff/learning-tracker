/// Codec for Firestore `learner_profiles/{id}` documents.
library;

import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a learner profile document.
class LearnerProfileRow {
  const LearnerProfileRow({
    required this.profileId,
    required this.accountId,
    required this.displayName,
    required this.mode,
    required this.updatedAt,
    required this.createdAt,
    this.avatarIndex = 0,
    this.syncedAt,
  });

  final int profileId;
  final int accountId;
  final String displayName;
  final String mode;
  final DateTime updatedAt;
  final DateTime createdAt;
  final int avatarIndex;

  /// Firestore server timestamp set by `FieldValue.serverTimestamp()` at
  /// push time. Used as the ±5 s clock-skew tie-breaker by mergers.
  final DateTime? syncedAt;
}

/// Codec for the `learner_profiles` Firestore collection.
///
/// Natural key: `profileId`.
/// LWW: remote wins when `updated_at` is strictly newer.
class LearnerProfileCodec extends EntityCodec<LearnerProfileRow> {
  const LearnerProfileCodec();

  @override
  String get kind => EntityKind.learnerProfile;

  @override
  LearnerProfileRow? decode(Map<String, dynamic> raw) {
    final profileId = FirestoreCodec.parseInt(raw['profile_id']);
    final accountId = FirestoreCodec.parseInt(raw['account_id']);
    final displayName = raw['display_name'] as String?;
    final mode = raw['mode'] as String?;
    final updatedAt = FirestoreCodec.parseDateTime(raw['updated_at']);
    final createdAt = FirestoreCodec.parseDateTime(raw['created_at']);

    if (profileId == null ||
        accountId == null ||
        displayName == null ||
        mode == null ||
        updatedAt == null ||
        createdAt == null) {
      return null;
    }

    return LearnerProfileRow(
      profileId: profileId,
      accountId: accountId,
      displayName: displayName,
      mode: mode,
      updatedAt: updatedAt,
      createdAt: createdAt,
      avatarIndex: FirestoreCodec.parseInt(raw['avatar_index']) ?? 0,
      syncedAt: FirestoreCodec.parseDateTime(raw['synced_at']),
    );
  }

  @override
  Map<String, dynamic> encode(LearnerProfileRow model) => {
    'profile_id': model.profileId,
    'account_id': model.accountId,
    'display_name': model.displayName,
    'mode': model.mode,
    'avatar_index': model.avatarIndex,
    'updated_at': FirestoreCodec.encodeDateTime(model.updatedAt),
    'created_at': FirestoreCodec.encodeDateTime(model.createdAt),
  };
}
