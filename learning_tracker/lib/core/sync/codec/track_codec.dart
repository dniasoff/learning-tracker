/// Codec for Firestore `curriculum_tracks/{id}` documents.
///
/// W3.22: trackType removed from the schema — one track per (profileId, curriculumId).
/// W3.28/W3.29: isActive/deactivatedAt replaced by unified `state` enum + stateChangedAt.
library;

import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a curriculum track row (W3.22/W3.28).
class TrackRow {
  const TrackRow({
    required this.profileId,
    required this.trackId,
    required this.curriculumId,
    required this.state,
    required this.activatedAt,
    required this.stateChangedAt,
    this.paceResetDate,
    this.syncedAt,
  });

  /// Local profile id (FK: learner_profiles.id).
  final int profileId;

  /// Local track id (FK: curriculum_tracks.id).
  final int trackId;

  final String curriculumId;

  /// Lifecycle state: 'active' | 'retired' | 'archived' | 'deleted'.
  final String state;

  final DateTime activatedAt;

  /// LWW timestamp — when `state` was last changed.
  final DateTime stateChangedAt;

  final DateTime? paceResetDate;

  /// Firestore server timestamp set by `FieldValue.serverTimestamp()` at
  /// push time. Used as the ±5 s clock-skew tie-breaker by mergers.
  final DateTime? syncedAt;
}

/// Codec for the `curriculum_tracks` Firestore collection.
///
/// Natural key: `curriculumId` (one track per profile+curriculum, W3.22).
/// LWW: remote wins when `state_changed_at` is strictly newer than local.
class TrackCodec extends EntityCodec<TrackRow> {
  const TrackCodec();

  @override
  String get kind => EntityKind.trackConfig;

  @override
  TrackRow? decode(Map<String, dynamic> raw) {
    final curriculumId = raw['curriculum_id'] as String?;
    final activatedAt = FirestoreCodec.parseDateTime(raw['activated_at']);

    if (curriculumId == null || activatedAt == null) return null;

    // Back-compat: old docs carry `is_active` instead of `state`.
    final String state;
    final rawState = raw['state'] as String?;
    if (rawState != null && rawState.isNotEmpty) {
      state = rawState;
    } else {
      final isActive = FirestoreCodec.parseBool(raw['is_active']) ?? true;
      state = isActive ? 'active' : 'retired';
    }

    final stateChangedAt =
        FirestoreCodec.parseDateTime(raw['state_changed_at']) ??
        FirestoreCodec.parseDateTime(raw['deactivated_at']) ??
        activatedAt;

    // profile_id / track_id are local FK values injected at push time;
    // Firestore documents don't carry the local autoincrement id (they use
    // the stored profile_id from the push payload). Parse them from raw if
    // present (pull side), otherwise default to 0 — the merger ignores these
    // fields for the upsert path (it uses the injected profileId param).
    //
    // AUD-core-sync-05: these fields must go through FirestoreCodec.parseInt
    // rather than an unguarded nullable-int type cast — an unguarded cast
    // throws on a malformed/wrong-typed value (e.g. a String from a
    // hand-edited doc) instead of returning null, which violates the
    // decode() contract (EntityCodec.decode — "returns null when required
    // fields are missing or malformed") and would crash the whole
    // pull-on-launch pass.
    final profileId = FirestoreCodec.parseInt(raw['profile_id']) ?? 0;
    final trackId = FirestoreCodec.parseInt(raw['track_id']) ?? 0;

    return TrackRow(
      profileId: profileId,
      trackId: trackId,
      curriculumId: curriculumId,
      state: state,
      activatedAt: activatedAt,
      stateChangedAt: stateChangedAt,
      paceResetDate: FirestoreCodec.parseDateTime(raw['pace_reset_date']),
      syncedAt: FirestoreCodec.parseDateTime(raw['synced_at']),
    );
  }

  @override
  Map<String, dynamic> encode(TrackRow model) => {
    'profile_id': model.profileId,
    'track_id': model.trackId,
    'curriculum_id': model.curriculumId,
    'state': model.state,
    'activated_at': FirestoreCodec.encodeDateTime(model.activatedAt),
    'state_changed_at': FirestoreCodec.encodeDateTime(model.stateChangedAt),
    if (model.paceResetDate != null)
      'pace_reset_date': FirestoreCodec.encodeDateTime(model.paceResetDate),
  };
}
