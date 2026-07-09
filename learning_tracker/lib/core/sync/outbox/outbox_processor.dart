import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/logging/logger.dart';
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
  static const stageDefinition = 'stage_definition'; // W2.29

  // W2.31 — outbox-backed SyncWriteFacade kinds ──────────────────────────────
  static const goal = 'goal';
  static const goalDelete = 'goal_delete';
  static const learnerProfile = 'learner_profile';
  static const learnerProfileDelete = 'learner_profile_delete';
  static const gamificationSettings = 'gamification_settings';

  // W2.32 — pushAllLocalData outbox kinds ────────────────────────────────────
  static const notificationSettings = 'notification_settings';
  static const uiPreferences = 'ui_preferences';
  static const profileProgram = 'profile_program';
  static const learningLedgerEntry = 'learning_ledger_entry';

  // Phase 1 — study-day config enrolment in the sync pipeline.
  static const studyDayConfig = 'study_day_config';

  // WS9 Wave-B (C#2) — points spend economy sync.
  static const pointsLedgerEntry = 'points_ledger_entry';
  static const rewardRedemption = 'reward_redemption';
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
    // W7.7: optional analytics — fires outbox_dead_lettered when a row hits
    // the max-attempts ceiling and is silently skipped forever.
    AnalyticsService? analytics,
    // Overridable for tests so the timeout/guard paths can be exercised
    // without real-time waits. Production uses the defaults.
    Duration pushTimeout = const Duration(seconds: 20),
    Duration drainStaleAfter = const Duration(seconds: 90),
    // T1.isolation — optional async guard: returns true when [profileId]
    // belongs to a tutored-mirror profile that must never be drained into
    // the tutor's own Firestore namespace.  Defaults to always-false (no
    // tutored profiles exist) when omitted.
    Future<bool> Function(int profileId)? isTutoredProfile,
    // Identity guard: returns true when the live Firebase token belongs to a
    // DIFFERENT account than the active one (the user switched into a second
    // cloud account on this device without re-authenticating). Every push
    // would be denied by Firestore rules / Cloud Functions, so the whole
    // drain is skipped — doomed rows must NOT burn their retry budget and
    // dead-letter. Defaults to always-matched when omitted. Wired for ALL
    // drain triggers (orchestrator + write-tee facade kicks) by injecting it
    // at the single processor construction site.
    bool Function()? isIdentityMismatched,
  }) : _dao = outboxDao,
       _pipeline = pipeline,
       _clock = clock,
       _analytics = analytics,
       _pushTimeout = pushTimeout,
       _drainStaleAfter = drainStaleAfter,
       _isTutoredProfile = isTutoredProfile,
       _isIdentityMismatched = isIdentityMismatched;

  final OutboxDao _dao;
  final PushPipeline _pipeline;
  final LocalDayClock _clock;
  final AnalyticsService? _analytics;

  // T1.isolation — tutored-profile guard injected at construction time.
  final Future<bool> Function(int profileId)? _isTutoredProfile;

  // Identity guard injected at construction time — see constructor doc.
  final bool Function()? _isIdentityMismatched;

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

  /// Single-flight guard: when a [drain] is already running, subsequent calls
  /// return 0 immediately so the five drain triggers (write-tee, pull-complete,
  /// connectivity online, lifecycle resume, periodic safety net) cannot stampede
  /// the push pipeline on near-simultaneous fires. Per-process state — safe for
  /// the Flutter single-Isolate runtime.
  bool _draining = false;

  /// When the in-flight drain started. Used to reclaim a wedged guard: a push
  /// that hangs (online-but-unreachable network, no clean error) would leave
  /// [_draining] stuck `true` forever and silently block ALL future drains.
  DateTime? _drainingSince;

  /// If a drain has held the single-flight guard longer than this, treat it as
  /// stale and let a new drain reclaim it. Must exceed [_pushTimeout] so a
  /// healthy (timed-out-and-retrying) drain is never pre-empted.
  final Duration _drainStaleAfter;

  /// Hard timeout on a single push operation. Firestore writes do NOT reliably
  /// error when the device is online-but-unreachable (e.g. broken IPv6 to
  /// firestore.googleapis.com) — the Future just hangs. Without this, one hung
  /// push wedges the whole outbox drain indefinitely.
  final Duration _pushTimeout;

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
  ///
  /// **Single-flight:** if a drain is already in flight for this processor,
  /// returns 0 immediately. The five wired triggers can fire in quick
  /// succession (write-tee + connectivity-online + lifecycle-resume +
  /// pull-complete all coinciding on app launch); this guard collapses them
  /// to one push round.
  Future<int> drain(int profileId) async {
    // Identity guard: when the live Firebase token belongs to a different
    // account than the active one, EVERY push is denied by Firestore rules
    // (UID ≠ auth.uid) and every Cloud Function call returns UNAUTHENTICATED.
    // Skip the entire drain so these permanently-doomed rows do not increment
    // their attempt count toward [_maxAttempts] and dead-letter — they would
    // wedge sync forever. The Backup & Sync banner prompts a re-auth instead;
    // once the matching account is signed in, the next drain flushes them.
    if (_isIdentityMismatched?.call() ?? false) return 0;
    if (_draining) {
      final since = _drainingSince;
      // Reclaim a wedged guard: if the in-flight drain has been held past the
      // stale threshold (a push that hung with no error/timeout), allow this
      // drain to proceed instead of no-opping forever.
      if (since != null &&
          _clock.nowUtc().difference(since) < _drainStaleAfter) {
        return 0;
      }
      // The in-flight drain is wedged (elapsed >= _drainStaleAfter, or
      // _drainingSince was null). Reset both guard fields so the new drain
      // establishes a clean, fresh single-flight state — without this reset
      // the two fields stay out-of-sync for the duration of the new drain,
      // and any concurrent caller entering this branch before the new drain
      // finishes could incorrectly reclaim the guard a second time.
      _draining = false;
      _drainingSince = null;
    }
    _draining = true;
    _drainingSince = _clock.nowUtc();
    try {
      return await _doDrain(profileId);
    } finally {
      _draining = false;
      _drainingSince = null;
    }
  }

  /// Drains the active [profileId], then sweeps account-level rows enqueued
  /// under profile 0. The initial `learner_profile` push is queued before any
  /// profile is active (facade `_profileId == 0`), so without this sweep that
  /// row never matches the active-profile drain and the profile never uploads
  /// (SYNC-2 — cloud `learner_profiles` stays empty).
  Future<int> _doDrain(int profileId) async {
    var pushed = await _drainForProfile(profileId);
    if (profileId != 0) {
      pushed += await _drainForProfile(0);
    }
    return pushed;
  }

  Future<int> _drainForProfile(int profileId) async {
    // T1.isolation — never push tutored-mirror data into the tutor's own
    // Firestore namespace.  The guard is called per-profile so the profile-0
    // sweep in _doDrain() is also protected (profile 0 is never tutored, but
    // the guard is O(1) so the defensive check is worth it).
    final guard = _isTutoredProfile;
    if (guard != null && await guard(profileId)) return 0;

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
      if (row.attempts >= _maxAttempts) {
        // W7.7: fire analytics for every dead-lettered completion row.
        // AUD-core-analytics-01 (PV-1): entity_key is dropped — it embeds
        // `${profileId}:${sefariaRef}:${stageId}:${trackType}:${curriculumId}`
        // (see completion_writer.dart), combining a per-child identifier
        // with the exact content the child was studying in one string.
        final future = _analytics?.logEvent(
          AnalyticsEvent.syncOutboxDeadLettered,
          parameters: {
            'entity_kind': OutboxEntityKind.completion,
            'attempts': row.attempts,
          },
        );
        if (future != null) unawaited(future);
        return false; // dead-lettered
      }
      return _nextAttemptAt(row.attempts, row.lastAttemptAt).isBefore(now);
    }).toList();

    if (eligibleCompletions.isNotEmpty) {
      // The `outbox` table has no UNIQUE index on `entityKey`, so two (or
      // more) eligible rows can share one key — they represent the SAME
      // completion (its Firestore doc ID is derived from the natural key, so
      // re-pushing is idempotent). De-duplicate by `entityKey` BEFORE
      // building the push entries: push exactly one representative row per
      // key (so each key lands in exactly one chunk and `BatchPushException`
      // accounting is unambiguous), while tracking every row id that shares
      // that key so commit/retry is applied to ALL of them.
      final rowIdsByKey = <String, List<int>>{};
      final representativePayload = <String, Map<String, dynamic>>{};
      final orderedKeys = <String>[];
      for (final row in eligibleCompletions) {
        final ids = rowIdsByKey.putIfAbsent(row.entityKey, () {
          orderedKeys.add(row.entityKey);
          representativePayload[row.entityKey] = _decodePayload(row.payload);
          return <int>[];
        });
        ids.add(row.id);
      }

      final entries = orderedKeys
          .map((key) => (entityKey: key, payload: representativePayload[key]!))
          .toList();

      // committed = entityKeys whose documents genuinely reached Firestore;
      // failedError = the error to record on the rows that did NOT commit.
      List<String> committed;
      Object? failedError;
      try {
        committed = await _pipeline
            .pushCompletionsBatch(profileId: profileId, entries: entries)
            .timeout(_pushTimeout);
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

      // Surface push failures in Send Diagnostic Logs (previously a denied
      // push was silent — only recorded in the on-device outbox.last_error,
      // requiring a DB pull to diagnose).
      if (failedError != null) {
        AppLogger.instance.warning(
          event: 'sync_outbox_push_failed',
          fields: {
            'kind': OutboxEntityKind.completion,
            'error': failedError.toString(),
          },
        );
      }

      final committedKeys = committed.toSet();
      for (final key in orderedKeys) {
        final ids = rowIdsByKey[key]!;
        if (committedKeys.contains(key)) {
          // The completion landed — delete EVERY outbox row carrying this
          // key (duplicates all describe the same idempotent completion).
          for (final id in ids) {
            await _dao.deleteRow(id);
          }
          successCount++;
        } else if (failedError != null) {
          // Not committed — mark every row with this key as attempted so the
          // whole group is retried together on the next drain.
          for (final id in ids) {
            await _dao.markAttempted(id, error: failedError.toString());
          }
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
        if (row.attempts >= _maxAttempts) {
          // W7.7: fire analytics for every dead-lettered non-completion row.
          // AUD-core-analytics-01 (PV-1): entity_key dropped, see above.
          final future = _analytics?.logEvent(
            AnalyticsEvent.syncOutboxDeadLettered,
            parameters: {'entity_kind': kind, 'attempts': row.attempts},
          );
          if (future != null) unawaited(future);
          continue; // dead-lettered
        }
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
          ).timeout(_pushTimeout);
          await _dao.deleteRow(row.id);
          successCount++;
        } catch (e) {
          AppLogger.instance.warning(
            event: 'sync_outbox_push_failed',
            fields: {
              'kind': kind,
              'entity_key': row.entityKey,
              'attempts': row.attempts + 1,
              'error': e.toString(),
            },
          );
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
    OutboxEntityKind.stageDefinition, // W2.29
    // W2.31 — outbox-backed SyncWriteFacade kinds
    OutboxEntityKind.goal,
    OutboxEntityKind.goalDelete,
    OutboxEntityKind.learnerProfile,
    OutboxEntityKind.learnerProfileDelete,
    OutboxEntityKind.gamificationSettings,
    // W2.32 — pushAllLocalData outbox kinds
    OutboxEntityKind.notificationSettings,
    OutboxEntityKind.uiPreferences,
    OutboxEntityKind.profileProgram,
    OutboxEntityKind.learningLedgerEntry,
    // Phase 1 — study-day config enrolment (placed late: it is a config-style
    // entity, drained after time-sensitive entities and other preferences).
    OutboxEntityKind.studyDayConfig,
    // WS9 Wave-B (C#2) — points spend economy.
    OutboxEntityKind.pointsLedgerEntry,
    OutboxEntityKind.rewardRedemption,
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
    final jitterFactor = 1.0 + (_random.nextDouble() * 2 - 1) * _backoffJitter;
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
      case OutboxEntityKind.stageDefinition: // W2.29
        return _pipeline.pushStageDefinition(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      // W2.31 — outbox-backed SyncWriteFacade kinds ──────────────────────────
      case OutboxEntityKind.goal:
        return _pipeline.pushGoal(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.goalDelete:
        return _pipeline.deleteGoal(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.learnerProfile:
        return _pipeline.pushLearnerProfile(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.learnerProfileDelete:
        return _pipeline.deleteLearnerProfile(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.gamificationSettings:
        return _pipeline.pushGamificationSettings(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      // W2.32 — pushAllLocalData outbox kinds ──────────────────────────────
      case OutboxEntityKind.notificationSettings:
        return _pipeline.pushNotificationSettings(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.uiPreferences:
        return _pipeline.pushUiPreferences(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.profileProgram:
        return _pipeline.pushProfileProgram(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.learningLedgerEntry:
        return _pipeline.pushLearningLedgerEntry(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.studyDayConfig:
        return _pipeline.pushStudyDayConfig(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.pointsLedgerEntry:
        return _pipeline.pushPointsLedgerEntry(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      case OutboxEntityKind.rewardRedemption:
        return _pipeline.pushRewardRedemption(
          profileId: profileId,
          entityKey: entityKey,
          payload: payload,
        );
      default:
        throw ArgumentError(
          'Unknown outbox entity kind for single dispatch: $kind',
        );
    }
  }
}
