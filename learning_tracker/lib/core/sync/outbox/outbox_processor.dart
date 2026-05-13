import 'dart:convert';

import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';

/// Known entity kinds stored in the outbox.
///
/// Kept as a plain class of constants so [OutboxProcessor] can switch on
/// them without a hard dependency on any feature package.
class OutboxEntityKind {
  const OutboxEntityKind._();

  static const completion = 'completion';
  static const streak = 'streak';
  static const settings = 'settings';
  static const track = 'track';
  static const learningOrder = 'learning_order';
  static const bookmark = 'bookmark';
}

/// Drains pending outbox rows for a given profile, dispatching each mutation
/// to the appropriate [PushPipeline] method.
///
/// The processor operates on one [entityKind] at a time so that a large
/// backlog of completions does not starve streak or settings pushes.
/// Callers should invoke [drain] for each kind they wish to flush.
///
/// **Batch limit:** at most [_batchSize] rows are drained per [drain] call to
/// avoid holding the network for an unbounded duration.
///
/// **Error handling:** if a push fails, the row is NOT deleted — instead
/// [OutboxDao.markAttempted] records the error so the next drain attempt
/// retries it.
class OutboxProcessor {
  OutboxProcessor({
    required OutboxDao outboxDao,
    required PushPipeline pipeline,
  })  : _dao = outboxDao,
        _pipeline = pipeline;

  final OutboxDao _dao;
  final PushPipeline _pipeline;

  static const int _batchSize = 50;

  /// Drain up to [_batchSize] pending outbox rows for [profileId].
  ///
  /// Each entity kind is fetched and flushed in a deterministic order so
  /// upstream callers get predictable behaviour. Returns the number of rows
  /// successfully pushed.
  Future<int> drain(int profileId) async {
    var successCount = 0;

    for (final kind in _orderedKinds) {
      final rows = await _dao.getPendingByKind(
        kind,
        profileId,
        limit: _batchSize,
      );

      for (final row in rows) {
        final payload = _decodePayload(row.payload);
        try {
          await _dispatch(
            kind: kind,
            profileId: profileId,
            entityKey: row.entityKey,
            payload: payload,
          );
          await _dao.deleteRow(row.id);
          successCount++;
        } catch (e) {
          await _dao.markAttempted(row.id, error: e.toString());
          // Continue draining other rows — don't abort the whole batch on
          // a single failure.
        }
      }
    }

    return successCount;
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Deterministic drain order so that time-sensitive entities (completions,
  /// streaks) are flushed before cosmetic ones (settings, order).
  static const _orderedKinds = [
    OutboxEntityKind.completion,
    OutboxEntityKind.streak,
    OutboxEntityKind.track,
    OutboxEntityKind.learningOrder,
    OutboxEntityKind.bookmark,
    OutboxEntityKind.settings,
  ];

  Map<String, dynamic> _decodePayload(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException('Outbox payload is not a JSON object: $raw');
  }

  Future<void> _dispatch({
    required String kind,
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) {
    switch (kind) {
      case OutboxEntityKind.completion:
        return _pipeline.pushCompletion(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.streak:
        return _pipeline.pushStreak(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.settings:
        return _pipeline.pushSettings(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.track:
        return _pipeline.pushTrack(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.learningOrder:
        return _pipeline.pushLearningOrder(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.bookmark:
        return _pipeline.pushBookmark(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      default:
        throw ArgumentError('Unknown outbox entity kind: $kind');
    }
  }
}
