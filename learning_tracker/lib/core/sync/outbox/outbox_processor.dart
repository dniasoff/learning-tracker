import 'dart:convert';
import 'dart:math' as math;

import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';

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
/// **Completion batching:** all pending completion rows are collected and
/// dispatched in a single [PushPipeline.pushCompletionsBatch] call (which
/// internally chunks into ≤500-op Firestore WriteBatches). This eliminates
/// the N-round-trip problem that caused RC3.
///
/// **Non-completion batch limit:** at most [_batchSize] rows are drained per
/// [drain] call to avoid holding the network for an unbounded duration.
///
/// **Exponential backoff:** rows that have already failed are skipped when
/// their computed [_nextAttemptAt] is still in the future. A row is
/// dead-lettered (permanently skipped) once it reaches [_maxAttempts]. The
/// delay is capped at [_maxBackoff] and randomly jittered to avoid a
/// thundering-herd retry.
///
/// **Error handling:** if a push fails, the row is NOT deleted — instead
/// [OutboxDao.markAttempted] records the error so the next drain attempt
/// retries it with backoff. A partially-successful completion batch deletes
/// exactly the rows that committed and marks only the rest as attempted.
class OutboxProcessor {
  OutboxProcessor({
    required OutboxDao outboxDao,
    required PushPipeline pipeline,
    required LocalDayClock clock,
  }) : _dao = outboxDao,
       _pipeline = pipeline,
       _clock = clock;

  final OutboxDao _dao;
  final PushPipeline _pipeline;
  final LocalDayClock _clock;

  /// Maximum number of push attempts before a row is dead-lettered.
  static const int _maxAttempts = 10;

  /// Non-completion entity batch limit.
  static const int _batchSize = 50;

  /// Base delay for exponential backoff (first retry: ~30 s).
  static const Duration _backoffBase = Duration(seconds: 30);

  /// Hard ceiling on the exponential-backoff delay. Without a cap, an
  /// attempt count near [_maxAttempts] would push the retry window out to
  /// hours; one hour is the longest a stuck row should wait between tries.
  static const Duration _maxBackoff = Duration(hours: 1);

  /// Jitter fraction applied to the computed backoff delay (±20%) so that a
  /// fleet of devices that all failed at once do not retry in lockstep.
  static const double _backoffJitter = 0.2;

  /// Upper bound on the number of completion rows collected for a single
  /// [drain]. Completions are dispatched in one [PushPipeline.pushCompletionsBatch]
  /// call (internally chunked into ≤500-op WriteBatches); this constant is an
  /// intentional hard ceiling guarding against an unbounded query, not a
  /// page size. It is far above any realistic offline backlog.
  static const int _completionDrainCeiling = 100000;

  /// Source of randomness for [_backoffJitter]. Jitter only perturbs a retry
  /// window, so a plain (non-cryptographic) PRNG is appropriate.
  final math.Random _random = math.Random();

  /// Drain pending outbox rows for [profileId].
  ///
  /// Completions are collected all at once and dispatched via
  /// [PushPipeline.pushCompletionsBatch]. All other kinds are drained up to
  /// [_batchSize] rows each.
  ///
  /// Each entity kind is processed in a deterministic order so that
  /// time-sensitive entities (completions, streaks) are flushed before
  /// cosmetic ones (settings, order). Returns the number of rows successfully
  /// pushed.
  Future<int> drain(int profileId) async {
    final now = _clock.nowUtc();
    var successCount = 0;

    // ── completions — batched ────────────────────────────────────────────────
    final completionRows = await _dao.getPendingByKind(
      OutboxEntityKind.completion,
      profileId,
      // Collect (effectively) ALL pending completions so they can be sent in
      // a single pushCompletionsBatch call (≤500-op WriteBatch chunks).
      // [_completionDrainCeiling] is an intentional hard upper bound.
      limit: _completionDrainCeiling,
    );

    // Filter rows that are eligible for a retry attempt.
    final eligibleCompletions = completionRows.where((row) {
      if (row.attempts >= _maxAttempts) return false; // dead-lettered
      return _nextAttemptAt(row.attempts, row.lastAttemptAt).isBefore(now);
    }).toList();

    if (eligibleCompletions.isNotEmpty) {
      final entries = eligibleCompletions
          .map(
            (row) => (
              entityKey: row.entityKey,
              payload: _decodePayload(row.payload),
            ),
          )
          .toList();

      // committed = entityKeys whose documents genuinely reached Firestore;
      // failedError = the error to record on the rows that did NOT commit.
      List<String> committed;
      Object? failedError;
      try {
        committed = await _pipeline.pushCompletionsBatch(
          profileId: profileId,
          entries: entries,
        );
      } on BatchPushException catch (e) {
        // Partial failure: the chunks listed in `e.committed` are durable —
        // delete exactly those rows; the remaining rows are marked attempted
        // so only they are retried (committed rows are never re-pushed or
        // dead-lettered — H3).
        committed = e.committed;
        failedError = e.cause;
      } catch (e) {
        // Total failure (e.g. unauthenticated before any chunk committed) —
        // nothing committed; every eligible row is retried.
        committed = const [];
        failedError = e;
      }

      final committedKeys = committed.toSet();
      for (final row in eligibleCompletions) {
        if (committedKeys.contains(row.entityKey)) {
          await _dao.deleteRow(row.id);
          successCount++;
        } else if (failedError != null) {
          await _dao.markAttempted(row.id, error: failedError.toString());
        }
      }
    }

    // ── non-completion kinds — one at a time with backoff ────────────────────
    for (final kind in _nonCompletionKinds) {
      final rows = await _dao.getPendingByKind(
        kind,
        profileId,
        limit: _batchSize,
      );

      for (final row in rows) {
        if (row.attempts >= _maxAttempts) continue; // dead-lettered
        if (_nextAttemptAt(row.attempts, row.lastAttemptAt).isAfter(now)) {
          continue; // backoff window not yet elapsed
        }

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

  /// Deterministic drain order for non-completion kinds — time-sensitive
  /// entities (streaks) are flushed before cosmetic ones (settings, order).
  static const _nonCompletionKinds = [
    OutboxEntityKind.streak,
    OutboxEntityKind.track,
    OutboxEntityKind.learningOrder,
    OutboxEntityKind.bookmark,
    OutboxEntityKind.settings,
  ];

  /// Compute the earliest time at which the [attempts]-th row may be retried.
  ///
  /// Uses capped, jittered exponential backoff:
  ///   raw   = base * 2^(attempts - 1)
  ///   delay = min(raw, [_maxBackoff]) perturbed by ±[_backoffJitter]
  ///
  /// The cap stops the delay from growing to hours near [_maxAttempts]; the
  /// jitter spreads a fleet of simultaneously-failed devices so they do not
  /// all retry in lockstep (thundering herd).
  ///
  /// When [lastAttemptAt] is null (never attempted), the row is immediately
  /// eligible.
  DateTime _nextAttemptAt(int attempts, DateTime? lastAttemptAt) {
    if (attempts == 0 || lastAttemptAt == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    final multiplier = math.pow(2, attempts - 1).toDouble();
    final rawMs = _backoffBase.inMilliseconds * multiplier;
    // Cap before applying jitter so the jittered value never exceeds the
    // ceiling by more than the jitter band.
    final cappedMs = math.min(rawMs, _maxBackoff.inMilliseconds.toDouble());
    // Jitter factor in [1 - jitter, 1 + jitter].
    final jitterFactor =
        1.0 + (_random.nextDouble() * 2 - 1) * _backoffJitter;
    final delay = Duration(milliseconds: (cappedMs * jitterFactor).round());
    return lastAttemptAt.add(delay);
  }

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
        throw ArgumentError('Unknown outbox entity kind for single dispatch: $kind');
    }
  }
}
