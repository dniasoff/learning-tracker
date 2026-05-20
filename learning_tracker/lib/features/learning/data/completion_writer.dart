import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';

/// Result of a [CompletionWriter.commit] call.
///
/// `completion` is always the persisted row. `isNew` is `true` when the
/// transaction inserted a new completion + outbox row; `false` when the
/// command was a duplicate of an existing completion and no outbox row was
/// enqueued.
class CompletionWriteResult {
  const CompletionWriteResult({required this.completion, required this.isNew});

  final Completion completion;
  final bool isNew;
}

/// Single, authoritative path for recording a completion (FR15, T2.7).
///
/// [commit] opens one Drift transaction that atomically inserts two rows:
///  1. `completion_events` — canonical FR5 event log (DNI-336 / AC 25.15).
///  2. `outbox` — drives the cloud push pipeline.
///
/// Both rows commit or both roll back. The `completions` table is no longer
/// written to after schema v20 (C1); it is now a legacy projection and the
/// Drift view `completions_view` is the read surface.
///
/// Idempotency: both [commit] and [commitBatch] check for an existing
/// `(profileId, sefariaRef, stageId, trackType)` row in `completion_events`
/// BEFORE inserting. A duplicate command returns the existing row with
/// `isNew = false` and does NOT enqueue a second outbox push. The `outbox`
/// table has no UNIQUE index, so this pre-insert existence check — not
/// `INSERT OR IGNORE` — is what prevents duplicate pushes.
///
/// Out of scope for this writer:
///  - Streak-event tee (moved into CompletionWriter by DNI-337).
///  - Reader-screen `completionCommittedProvider` notifier swap (Story 26.13).
///
/// Incoming Firestore pulls MUST NOT use this writer — pulled completions
/// must not generate outbox rows (that would loop remote writes back into
/// the push pipeline).
class CompletionWriter {
  CompletionWriter(this._db, {AnalyticsService? analytics})
    : _analytics = analytics ?? const NullAnalyticsService();

  final UserDatabase _db;
  final AnalyticsService _analytics;

  /// Batch-commit [commands] in a SINGLE Drift transaction (RC1 fix).
  ///
  /// Behaviour mirrors [commit]'s correctness, batched:
  ///  1. [commands] are de-duplicated on the natural key
  ///     `(profileId, sefariaRef, stageId, trackType)` — two commands with the
  ///     same key collapse to one event + at most one outbox row.
  ///  2. The natural keys that ALREADY exist in `completion_events` are
  ///     snapshotted before any insert. The `outbox` table has NO unique
  ///     index, so an `outbox` row is enqueued ONLY for genuinely-new
  ///     completions; pre-existing ones enqueue NO outbox row and resolve
  ///     with `isNew = false`. This prevents duplicate pushes when
  ///     `commitBatch` is re-run (e.g. `pushAllLocalData` on cloud upgrade,
  ///     or bulk-marking overlapping sets).
  ///  3. All inserts and read-backs run inside one `db.transaction()`.
  ///
  /// Behavioural trade-off — re-pushing drained completions is out of scope:
  /// the enqueue decision is driven purely by presence in `completion_events`.
  /// A completion already in `completion_events` is treated as already-queued,
  /// so if its `outbox` row was previously drained and deleted, `commitBatch`
  /// will NOT regenerate it (it returns `isNew = false` and enqueues nothing).
  /// This is deliberate — it keeps `commitBatch` idempotent and avoids
  /// duplicate pushes; re-pushing an already-drained completion must be
  /// handled by a dedicated path, not by this method.
  ///
  /// Returns one [CompletionWriteResult] per input command, in the same
  /// order. Duplicate input commands all map to the same resolved result.
  Future<List<CompletionWriteResult>> commitBatch(
    List<CompletionCommand> commands,
  ) async {
    if (commands.isEmpty) return const [];

    // ── De-duplicate the input on the natural key ──────────────────────────
    // Two commands with the same natural key must produce one event + one
    // outbox row. Keep the FIRST occurrence as the canonical command; remember
    // each input command's natural key so the per-command results can be
    // reconstructed in input order afterwards.
    final uniqueByKey = <String, CompletionCommand>{};
    for (final cmd in commands) {
      uniqueByKey.putIfAbsent(_naturalKey(cmd), () => cmd);
    }
    final distinctCommands = uniqueByKey.values.toList();

    final results = await _db.transaction(() async {
      // ── 1. Snapshot which natural keys ALREADY exist (active rows only) ──
      // Bounded: one SELECT over completion_events filtered to the batch keys.
      // Only active (purgedAt IS NULL) rows count as pre-existing — tombstoned
      // rows must be resurrected, not silently ignored (H1 bug fix).
      final activeEvents = await _selectEventsForBatch(distinctCommands);
      final activeByKey = <String, CompletionEvent>{
        for (final e in activeEvents) _naturalKeyForEvent(e): e,
      };
      final preExisting = activeByKey.keys.toSet();

      // ── 1b. Detect tombstoned rows that need resurrection (H1 fix) ───────
      // A command whose natural key matches a tombstoned row is NOT in
      // preExisting (because _selectEventsForBatch excludes tombstones), so it
      // would fall into newCommands and hit INSERT OR IGNORE — which is a no-op
      // because the unique-key row still exists. We must explicitly resurrect
      // these rows instead.
      final tombstoned = await _selectTombstonedEventsForBatch(
        distinctCommands,
      );
      final tombstoneByKey = <String, CompletionEvent>{
        for (final e in tombstoned) _naturalKeyForEvent(e): e,
      };
      // Separate commands into: brand-new inserts, resurrections, and B8 upgrades.
      final commandsToResurrect = <CompletionCommand>[];
      final commandsToInsert = <CompletionCommand>[];
      // B8: real-learning commands that hit an existing prior-mark-only row
      // must upgrade the row (clear priorMarkOnly, update timestamp).
      final commandsToUpgrade = <CompletionCommand>[];
      for (final cmd in distinctCommands) {
        final key = _naturalKey(cmd);
        if (preExisting.contains(key)) {
          // Truly pre-existing active row. B8: if the existing row is
          // priorMarkOnly AND this command is a real-learning write, upgrade
          // the row so a subsequent expunge does not delete it.
          final existingRow = activeByKey[key]!;
          if (existingRow.priorMarkOnly && !cmd.priorMarkOnly) {
            commandsToUpgrade.add(cmd);
          }
          // Otherwise: truly pre-existing real-learning row — no action needed.
        } else if (tombstoneByKey.containsKey(key)) {
          commandsToResurrect.add(cmd);
        } else {
          commandsToInsert.add(cmd);
        }
      }

      // Resurrect tombstoned rows (clears purgedAt + enqueues outbox push).
      for (final cmd in commandsToResurrect) {
        await _resurrectTombstone(tombstoneByKey[_naturalKey(cmd)]!, cmd);
      }

      // B8 upgrade: promote prior-mark-only rows to real-learning rows.
      for (final cmd in commandsToUpgrade) {
        await _upgradePriorMarkRow(activeByKey[_naturalKey(cmd)]!, cmd);
      }

      final newCommands = [...commandsToInsert]; // brand-new only

      // ── 2. Batch-insert completion_events (INSERT OR IGNORE) ─────────────
      // INSERT OR IGNORE remains correct: the natural-key UNIQUE index makes
      // pre-existing rows no-op, and the de-dup above ensures one row per key.
      // Resurrected and upgraded commands are intentionally excluded — they
      // already have a row (now active again); inserting them would be a no-op
      // anyway, but excluding them keeps the intent explicit.
      if (commandsToInsert.isNotEmpty) {
        await _db.batch((b) {
          b.insertAll(
            _db.completionEvents,
            commandsToInsert.map(
              (cmd) => CompletionEventsCompanion.insert(
                profileId: cmd.profileId,
                curriculumId: cmd.curriculumId,
                sefariaRef: cmd.sefariaRef,
                stageId: cmd.stageId,
                trackType: cmd.trackType,
                trackId: Value<int?>(cmd.trackId),
                points: Value(cmd.points),
                eventTimestamp: cmd.completedAt,
                // B8: persist the prior-mark flag so expunge can target only
                // prior-mark rows (priorMarkOnly = true) and leave real-learning
                // rows (priorMarkOnly = false) untouched.
                priorMarkOnly: Value(cmd.priorMarkOnly),
              ),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        });
      }

      // ── 3. Batch-insert outbox rows for GENUINELY-NEW completions only ───
      // The outbox table has no unique index, so enqueuing a row for a
      // pre-existing completion would pile up duplicate pushes.
      // Resurrected completions already had their outbox rows enqueued inside
      // _resurrectTombstone above, so they are excluded here.
      if (newCommands.isNotEmpty) {
        await _db.batch((b) {
          _db.outboxDao.batchInsertOutboxRows(
            b,
            newCommands
                .map(
                  (cmd) => OutboxCompanion.insert(
                    profileId: cmd.profileId,
                    entityKind: OutboxEntityKind.completion,
                    entityKey: _outboxEntityKey(cmd),
                    payload: jsonEncode(_outboxPayload(cmd)),
                    createdAt: cmd.completedAt,
                  ),
                )
                .toList(),
          );
        });
      }

      // ── 4. Resolve results with bounded queries (no per-command query) ───
      // One SELECT over completion_events filtered to the batch keys, one
      // SELECT over completions_view by the collected event ids.
      final events = await _selectEventsForBatch(distinctCommands);
      final eventByKey = <String, CompletionEvent>{
        for (final e in events) _naturalKeyForEvent(e): e,
      };

      final eventIds = events.map((e) => e.id).toList();
      final viewRows = eventIds.isEmpty
          ? const <CompletionsViewData>[]
          : await (_db.select(
              _db.completionsView,
            )..where((t) => t.id.isIn(eventIds))).get();
      final viewById = <int, CompletionsViewData>{
        for (final v in viewRows) v.id: v,
      };

      // ── 5. Build a result per DISTINCT natural key ───────────────────────
      final resultByKey = <String, CompletionWriteResult>{};
      for (final cmd in distinctCommands) {
        final key = _naturalKey(cmd);
        final event = eventByKey[key];
        if (event == null) {
          throw StateError(
            'CompletionWriter.commitBatch: event not found after insert '
            'for ${cmd.sefariaRef}:${cmd.stageId}:${cmd.trackType}',
          );
        }
        // isNew is true for brand-new inserts AND for resurrected tombstones
        // (both are absent from preExisting, which only contains active rows).
        final isNew = !preExisting.contains(key);
        final viewRow = viewById[event.id];
        if (viewRow != null) {
          resultByKey[key] = CompletionWriteResult(
            completion: _completionFromView(viewRow),
            isNew: isNew,
          );
        } else {
          // Fallback: view row absent — reconstruct from raw event row.
          // This branch is only reached if resurrection failed to clear
          // purgedAt (should not happen in practice), or for a genuinely
          // new insert whose view refresh hasn't propagated yet.
          resultByKey[key] = CompletionWriteResult(
            completion: _completionFromEvent(event),
            isNew: isNew,
          );
        }
      }

      // Return one result per INPUT command, in input order (duplicate input
      // commands all resolve to the same natural-key result).
      return commands.map((cmd) => resultByKey[_naturalKey(cmd)]!).toList();
    });

    // ── Analytics fired AFTER the transaction commits (G7) ─────────────────
    // Telemetry must not be emitted for a write that then rolls back. Fire
    // once per genuinely-new DISTINCT completion (not once per input command).
    final firedKeys = <String>{};
    for (final result in results) {
      if (!result.isNew) continue;
      final c = result.completion;
      final key = _naturalKeyForCompletion(c);
      if (!firedKeys.add(key)) continue;
      unawaited(
        _analytics.logCompletionRecorded(
          sefariaRef: c.sefariaRef,
          trackType: c.trackType,
        ),
      );
    }

    return results;
  }

  /// Delimiter for natural-key composites: the NUL character (`\u0000`). NUL
  /// cannot occur in a sefariaRef, curriculumId, or trackType, so the
  /// five-part composite key is collision-proof even though a sefariaRef
  /// contains spaces and colons. The composed key is only ever used as an
  /// in-memory `Map` key — never persisted — so embedding a NUL byte is safe.
  static const String _keyDelim = '\u0000';

  /// Natural-key string for a command — the idempotency key for completions.
  ///
  /// Includes `curriculumId` so that two completions with the same
  /// (profileId, sefariaRef, stageId, trackType) but different curricula are
  /// treated as distinct completions (per-curriculum isolation, Option B).
  static String _naturalKey(CompletionCommand cmd) => _composeKey(
    cmd.profileId,
    cmd.sefariaRef,
    cmd.stageId,
    cmd.trackType,
    cmd.curriculumId,
  );

  /// Natural-key string for a persisted event row.
  static String _naturalKeyForEvent(CompletionEvent e) => _composeKey(
    e.profileId,
    e.sefariaRef,
    e.stageId,
    e.trackType,
    e.curriculumId,
  );

  /// Natural-key string for a resolved [Completion] row.
  static String _naturalKeyForCompletion(Completion c) => _composeKey(
    c.profileId,
    c.sefariaRef,
    c.stageId,
    c.trackType,
    c.curriculumId,
  );

  static String _composeKey(
    int profileId,
    String sefariaRef,
    int stageId,
    String trackType,
    String curriculumId,
  ) =>
      [profileId, sefariaRef, stageId, trackType, curriculumId].join(_keyDelim);

  /// One bounded SELECT over `completion_events` matching any of [commands]'
  /// natural keys. Only returns **active** (non-tombstoned) rows
  /// (`purgedAt IS NULL`). Tombstoned rows must not participate in the
  /// idempotency pre-check — if they did, a re-mark after expunge would be
  /// silently swallowed (H1 bug fix).
  ///
  /// The IN-list filters over-fetch slightly (the cross-product of the five
  /// columns); callers index the result by the full natural key so an
  /// over-fetched row is never mistaken for a batch member.
  Future<List<CompletionEvent>> _selectEventsForBatch(
    List<CompletionCommand> commands,
  ) {
    final profileIds = {for (final c in commands) c.profileId}.toList();
    final sefariaRefs = {for (final c in commands) c.sefariaRef}.toList();
    final stageIds = {for (final c in commands) c.stageId}.toList();
    final trackTypes = {for (final c in commands) c.trackType}.toList();
    final curriculumIds = {for (final c in commands) c.curriculumId}.toList();
    return (_db.select(_db.completionEvents)..where(
          (t) =>
              t.profileId.isIn(profileIds) &
              t.sefariaRef.isIn(sefariaRefs) &
              t.stageId.isIn(stageIds) &
              t.trackType.isIn(trackTypes) &
              t.curriculumId.isIn(curriculumIds) &
              t.purgedAt.isNull(),
        ))
        .get();
  }

  /// One bounded SELECT over `completion_events` matching any of [commands]'
  /// natural keys, returning ONLY tombstoned rows (`purgedAt IS NOT NULL`).
  /// Used by [commitBatch] to detect re-marks after expunge (H1 fix).
  Future<List<CompletionEvent>> _selectTombstonedEventsForBatch(
    List<CompletionCommand> commands,
  ) {
    final profileIds = {for (final c in commands) c.profileId}.toList();
    final sefariaRefs = {for (final c in commands) c.sefariaRef}.toList();
    final stageIds = {for (final c in commands) c.stageId}.toList();
    final trackTypes = {for (final c in commands) c.trackType}.toList();
    final curriculumIds = {for (final c in commands) c.curriculumId}.toList();
    return (_db.select(_db.completionEvents)..where(
          (t) =>
              t.profileId.isIn(profileIds) &
              t.sefariaRef.isIn(sefariaRefs) &
              t.stageId.isIn(stageIds) &
              t.trackType.isIn(trackTypes) &
              t.curriculumId.isIn(curriculumIds) &
              t.purgedAt.isNotNull(),
        ))
        .get();
  }

  /// Resurrects a tombstoned [event] for the given [cmd]:
  ///  - Clears `purgedAt` and updates `eventTimestamp` to the new command's
  ///    timestamp (so the re-mark reflects the current instant).
  ///  - Enqueues an outbox row so Firestore receives the re-activation push.
  Future<void> _resurrectTombstone(
    CompletionEvent event,
    CompletionCommand cmd,
  ) async {
    await (_db.update(
      _db.completionEvents,
    )..where((t) => t.id.equals(event.id))).write(
      CompletionEventsCompanion(
        purgedAt: const Value(null),
        eventTimestamp: Value(cmd.completedAt),
      ),
    );
    await _db.outboxDao.insertOutboxRow(
      OutboxCompanion.insert(
        profileId: cmd.profileId,
        entityKind: OutboxEntityKind.completion,
        entityKey: _outboxEntityKey(cmd),
        payload: jsonEncode(_outboxPayload(cmd)),
        createdAt: cmd.completedAt,
      ),
    );
  }

  /// B8: Upgrades a prior-mark-only [event] to a real-learning row when a
  /// genuine in-app learning [cmd] hits the same natural key:
  ///  - Clears `priorMarkOnly` (sets it to `false`).
  ///  - Updates `eventTimestamp` to the real-learning timestamp.
  ///  - Enqueues an outbox row so Firestore receives the update.
  ///
  /// After this call, [BulkPriorCompletionService.expungePriorCompletions] will
  /// skip this row (its `priorMarkOnly` is now `false`), so the item correctly
  /// survives an un-tick in the onboarding bulk-mark screen.
  Future<void> _upgradePriorMarkRow(
    CompletionEvent event,
    CompletionCommand cmd,
  ) async {
    await (_db.update(
      _db.completionEvents,
    )..where((t) => t.id.equals(event.id))).write(
      CompletionEventsCompanion(
        priorMarkOnly: const Value(false),
        eventTimestamp: Value(cmd.completedAt),
      ),
    );
    await _db.outboxDao.insertOutboxRow(
      OutboxCompanion.insert(
        profileId: cmd.profileId,
        entityKind: OutboxEntityKind.completion,
        entityKey: _outboxEntityKey(cmd),
        payload: jsonEncode(_outboxPayload(cmd)),
        createdAt: cmd.completedAt,
      ),
    );
  }

  /// Maps a `completions_view` row to a [Completion] (purgedAt IS NULL row).
  static Completion _completionFromView(CompletionsViewData v) => Completion(
    id: v.id,
    profileId: v.profileId,
    curriculumId: v.curriculumId,
    sefariaRef: v.sefariaRef,
    stageId: v.stageId,
    trackType: v.trackType,
    trackId: v.trackId ?? 0,
    completedAt: v.eventTimestamp,
    points: v.points,
    derivedFromEvents: true,
  );

  /// Reconstructs a [Completion] from a raw event row — used when the
  /// `completions_view` has no row (C3 tombstone, purgedAt IS NOT NULL).
  static Completion _completionFromEvent(CompletionEvent e) => Completion(
    id: e.id,
    profileId: e.profileId,
    curriculumId: e.curriculumId,
    sefariaRef: e.sefariaRef,
    stageId: e.stageId,
    trackType: e.trackType,
    trackId: e.trackId ?? 0,
    completedAt: e.eventTimestamp,
    points: e.points,
    derivedFromEvents: true,
  );

  Future<CompletionWriteResult> commit(CompletionCommand cmd) async {
    final result = await _db.transaction(() async {
      // Idempotency check on completion_events (UNIQUE canonical table).
      // getSingleOrNull() is safe because the UNIQUE constraint guarantees
      // at most one row per natural key (profileId, sefariaRef, stageId,
      // trackType, curriculumId). curriculumId MUST be included here so that
      // two completions for the same section in different curricula are treated
      // as distinct rows (per-curriculum isolation, Option B).
      final existingEvent =
          await (_db.select(_db.completionEvents)..where(
                (t) =>
                    t.profileId.equals(cmd.profileId) &
                    t.sefariaRef.equals(cmd.sefariaRef) &
                    t.stageId.equals(cmd.stageId) &
                    t.trackType.equals(cmd.trackType) &
                    t.curriculumId.equals(cmd.curriculumId),
              ))
              .getSingleOrNull();

      if (existingEvent != null) {
        if (existingEvent.purgedAt != null) {
          // C3 tombstone — this is a re-mark after expunge (H1 bug fix).
          // Resurrect the row: clear purgedAt, update timestamp, push outbox.
          await _resurrectTombstone(existingEvent, cmd);
          final resurrected = await _db.completionDao.getCompletionById(
            existingEvent.id,
          );
          if (resurrected != null) {
            return CompletionWriteResult(completion: resurrected, isNew: true);
          }
          // View refresh edge-case — reconstruct from the event row directly.
          final rebuilt = Completion(
            id: existingEvent.id,
            profileId: existingEvent.profileId,
            curriculumId: existingEvent.curriculumId,
            sefariaRef: existingEvent.sefariaRef,
            stageId: existingEvent.stageId,
            trackType: existingEvent.trackType,
            trackId: existingEvent.trackId ?? 0,
            completedAt: cmd.completedAt,
            points: existingEvent.points,
            derivedFromEvents: true,
          );
          return CompletionWriteResult(completion: rebuilt, isNew: true);
        }
        // B8: if the existing active row is a prior-mark-only row AND this
        // command is a real-learning event, upgrade the row so a later
        // expungePriorCompletions call will leave it intact.
        if (existingEvent.priorMarkOnly && !cmd.priorMarkOnly) {
          await _upgradePriorMarkRow(existingEvent, cmd);
          final upgraded = await _db.completionDao.getCompletionById(
            existingEvent.id,
          );
          if (upgraded != null) {
            return CompletionWriteResult(completion: upgraded, isNew: false);
          }
          // Fallback — reconstruct from the event row.
          final upgradedCompletion = Completion(
            id: existingEvent.id,
            profileId: existingEvent.profileId,
            curriculumId: existingEvent.curriculumId,
            sefariaRef: existingEvent.sefariaRef,
            stageId: existingEvent.stageId,
            trackType: existingEvent.trackType,
            trackId: existingEvent.trackId ?? 0,
            completedAt: cmd.completedAt,
            points: existingEvent.points,
            derivedFromEvents: true,
          );
          return CompletionWriteResult(
            completion: upgradedCompletion,
            isNew: false,
          );
        }
        // Active event already recorded — read from the view (purgedAt IS NULL).
        final existing = await _db.completionDao.getCompletionById(
          existingEvent.id,
        );
        if (existing != null) {
          return CompletionWriteResult(completion: existing, isNew: false);
        }
        // Unexpected: view row missing for an active event. Reconstruct and
        // return isNew=false so we don't double-push.
        final activeCompletion = Completion(
          id: existingEvent.id,
          profileId: existingEvent.profileId,
          curriculumId: existingEvent.curriculumId,
          sefariaRef: existingEvent.sefariaRef,
          stageId: existingEvent.stageId,
          trackType: existingEvent.trackType,
          trackId: existingEvent.trackId ?? 0,
          completedAt: existingEvent.eventTimestamp,
          points: existingEvent.points,
          derivedFromEvents: true,
        );
        return CompletionWriteResult(
          completion: activeCompletion,
          isNew: false,
        );
      } else {
        // No event yet — also guard against legacy completions rows that
        // predate v20 (derivedFromEvents = false) so we don't double-count.
        final legacy =
            await (_db.select(_db.completions)..where(
                  (t) =>
                      t.profileId.equals(cmd.profileId) &
                      t.sefariaRef.equals(cmd.sefariaRef) &
                      t.stageId.equals(cmd.stageId) &
                      t.trackType.equals(cmd.trackType) &
                      t.derivedFromEvents.equals(false),
                ))
                .getSingleOrNull();
        if (legacy != null) {
          return CompletionWriteResult(completion: legacy, isNew: false);
        }
      }

      // Write canonical event (INSERT OR IGNORE — idempotent on natural key).
      // trackId is included so the completions_view can serve track-scoped queries.
      // B8: persist priorMarkOnly from the command so expunge can target only
      // prior-mark rows and leave real-learning rows untouched.
      final eventId = await _db.completionEventDao.appendEvent(
        CompletionEventsCompanion.insert(
          profileId: cmd.profileId,
          curriculumId: cmd.curriculumId,
          sefariaRef: cmd.sefariaRef,
          stageId: cmd.stageId,
          trackType: cmd.trackType,
          trackId: Value<int?>(cmd.trackId),
          points: Value(cmd.points),
          eventTimestamp: cmd.completedAt,
          priorMarkOnly: Value(cmd.priorMarkOnly),
        ),
      );

      await _db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: cmd.profileId,
          entityKind: OutboxEntityKind.completion,
          entityKey: _outboxEntityKey(cmd),
          payload: jsonEncode(_outboxPayload(cmd)),
          createdAt: cmd.completedAt,
        ),
      );

      final inserted = await _db.completionDao.getCompletionById(eventId);
      if (inserted == null) {
        throw StateError(
          'CompletionWriter: event id=$eventId not found in completions_view',
        );
      }
      return CompletionWriteResult(completion: inserted, isNew: true);
    });

    // Story 27.14 (DNI-390): fire analytics event for new completions only.
    // Fired AFTER the transaction commits (G7) so telemetry is never emitted
    // for a write that then rolls back.
    if (result.isNew) {
      unawaited(
        _analytics.logCompletionRecorded(
          sefariaRef: result.completion.sefariaRef,
          trackType: result.completion.trackType,
        ),
      );
    }
    return result;
  }

  static String _outboxEntityKey(CompletionCommand cmd) =>
      '${cmd.profileId}:${cmd.sefariaRef}:${cmd.stageId}:${cmd.trackType}:${cmd.curriculumId}';

  /// Builds the Firestore completion-document payload.
  ///
  /// Keys are **snake_case** — the canonical Firestore schema convention. The
  /// merge path (`_mergeCompletions`) and `firestore.rules` both read
  /// snake_case keys; emitting camelCase here causes every pulled completion
  /// to be skipped (`insertedCount:0`).
  static Map<String, Object?> _outboxPayload(CompletionCommand cmd) => {
    'profile_id': cmd.profileId,
    'curriculum_id': cmd.curriculumId,
    'sefaria_ref': cmd.sefariaRef,
    'stage_id': cmd.stageId,
    'track_type': cmd.trackType,
    'track_id': cmd.trackId,
    'completed_at': cmd.completedAt.toUtc().toIso8601String(),
    'points': cmd.points,
  };
}
