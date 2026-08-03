import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/core/sync/codec/learning_ledger_codec.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart'
    show OutboxEntityKind;
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';

/// Implementation of [LearningLedgerRepository] using Drift database and the
/// outbox-backed [OutboxSyncWriteFacade] for ledger pushes.
///
/// Phase 1 — was bypassing the outbox via a direct FirestoreGateway push,
/// which silently dropped writes when offline. Every ledger entry now lands
/// in the outbox in the same call so the next drain (write-tee, pull-complete,
/// connectivity, periodic) ships it to Firestore.
///
/// AUD-learning-03 (DB-2): the ledger insert and its outbox row are written
/// inside the SAME `_database.transaction()`, so a crash between the two
/// steps can never strand a ledger row without a matching outbox row. The
/// outbox insert goes straight to `_database.outboxDao` — never through
/// [OutboxSyncWriteFacade.enqueueLedgerEntry], whose own class doc states the
/// local write and the outbox insert are "not transactional at this layer".
/// [OutboxSyncWriteFacade.requestSyncDrain] is called once the transaction
/// has committed so the freshly-written rows still push promptly (mirrors
/// the D14 fix in `PointsBalanceDao` and the RC1 fix in `CompletionWriter`).
class LearningLedgerRepositoryImpl implements LearningLedgerRepository {
  final UserDatabase _database;
  final OutboxSyncWriteFacade? _outboxFacade;
  final int _activeProfileId;
  final ProfileMode _activeProfileMode;

  /// When true, parent PIN was verified this session for [_activeProfileId].
  final bool parentPinSessionMatchesActiveProfile;

  LearningLedgerRepositoryImpl({
    required UserDatabase database,
    required OutboxSyncWriteFacade? outboxFacade,
    required int activeProfileId,
    required ProfileMode activeProfileMode,
    this.parentPinSessionMatchesActiveProfile = false,
  }) : _database = database,
       _outboxFacade = outboxFacade,
       _activeProfileId = activeProfileId,
       _activeProfileMode = activeProfileMode;

  void _assertManualMarkPermission({
    required int markedBy,
    required bool isManual,
  }) {
    if (isManual &&
        _activeProfileMode.isChild &&
        markedBy == _activeProfileId &&
        !parentPinSessionMatchesActiveProfile) {
      throw const ChildSelfMarkException();
    }
  }

  static const _codec = LearningLedgerCodec();

  Map<String, dynamic> _ledgerDataToSyncMap(LearningLedgerData entry) =>
      _codec.encode(
        LearningLedgerRow(
          ulid: entry.ulid,
          profileId: entry.profileId,
          curriculumId: entry.curriculumId,
          entryScope: entry.entryScope,
          unitIdentifier: entry.unitIdentifier,
          unitDisplayNameHe: entry.unitDisplayNameHe,
          unitDisplayNameEn: entry.unitDisplayNameEn,
          trackType: entry.trackType,
          trackId: entry.trackId,
          completedAt: entry.completedAt,
          completionNumber: entry.completionNumber,
          markedBy: entry.markedBy,
          isManual: entry.isManual,
        ),
      );

  /// Builds the outbox row that pushes [entry] to Firestore, stamped
  /// [enqueuedAt].
  ///
  /// Mirrors the kind/key/payload shape
  /// [OutboxSyncWriteFacade.enqueueLedgerEntry] would have produced. Callers
  /// insert the result directly via `_database.outboxDao.insertOutboxRow`
  /// (or a `_database.batch()`) INSIDE their own open transaction — see the
  /// AUD-learning-03 class doc above.
  OutboxCompanion _outboxRowFor(
    LearningLedgerData entry,
    DateTime enqueuedAt,
  ) => OutboxCompanion.insert(
    profileId: entry.profileId,
    entityKind: OutboxEntityKind.learningLedgerEntry,
    entityKey: entry.unitIdentifier,
    payload: jsonEncode(_ledgerDataToSyncMap(entry)),
    createdAt: enqueuedAt,
  );

  @override
  Future<LearningLedgerData> recordCompletion({
    required String curriculumId,
    required String entryScope,
    required String unitIdentifier,
    required String unitDisplayNameHe,
    required String unitDisplayNameEn,
    required String trackType,
    int? trackId,
    required int markedBy,
    required bool isManual,
    CompletionSource source = CompletionSource.live,
  }) async {
    _assertManualMarkPermission(markedBy: markedBy, isManual: isManual);

    final existingCount = await _database.learningLedgerDao.getCompletionCount(
      _activeProfileId,
      curriculumId,
      unitIdentifier,
    );
    final completionNumber = existingCount + 1;

    final now = DateTimeFactory.nowUtc();
    // Rule 4 / DEC-19: non-live sources (bulkInTrack / lifetimeOnly) write the
    // sentinel date so a siyum ledger row produced by a bulk-in-track mark is
    // not dated today (which would inflate streak / recent-activity reads).
    // Mirrors recordCompletionsBatch.
    final completedAt = source.creditsEngagement ? now : kBulkPriorSentinelDate;

    // AUD-learning-03 (DB-2): the ledger insert and its outbox row commit or
    // roll back together — a crash between the two would otherwise strand a
    // ledger row (e.g. a manual siyum mark) that never reaches Firestore or a
    // second device, since nothing re-derives a missing outbox row from an
    // existing ledger row.
    final entry = await _database.transaction(() async {
      final id = await _database.learningLedgerDao.insertEntry(
        LearningLedgerCompanion.insert(
          profileId: _activeProfileId,
          ulid: drift.Value(newUlid(now)),
          curriculumId: curriculumId,
          entryScope: entryScope,
          unitIdentifier: unitIdentifier,
          unitDisplayNameHe: unitDisplayNameHe,
          unitDisplayNameEn: unitDisplayNameEn,
          trackType: trackType,
          trackId: drift.Value(trackId),
          completedAt: completedAt,
          completionNumber: completionNumber,
          markedBy: markedBy,
          isManual: drift.Value(isManual),
        ),
      );

      final inserted = await _database.learningLedgerDao.getEntryById(id);
      if (inserted == null) {
        throw StateError('Failed to load ledger row after insert (id=$id)');
      }

      if (_outboxFacade != null) {
        await _database.outboxDao.insertOutboxRow(_outboxRowFor(inserted, now));
      }

      return inserted;
    });

    // Write-tee: kick the drain now that the row has actually committed
    // (mirrors the D14 pattern in PointsBalanceDao).
    await _outboxFacade?.requestSyncDrain();

    return entry;
  }

  @override
  Future<List<LearningLedgerData>> recordCompletionsBatch(
    List<LedgerManualBatchItem> items, {
    CompletionSource source = CompletionSource.lifetimeOnly,
  }) async {
    if (items.isEmpty) return const [];

    for (final item in items) {
      _assertManualMarkPermission(
        markedBy: item.markedBy,
        isManual: item.isManual,
      );
    }

    final results = <LearningLedgerData>[];

    // Non-live sources (bulkInTrack, lifetimeOnly) use the sentinel date so
    // engagement reads (streak, points-per-day) are never credited for them.
    final completedAt = source.creditsEngagement
        ? DateTimeFactory.nowUtc()
        : kBulkPriorSentinelDate;

    // AUD-learning-03 (DB-2): every ledger row AND its outbox row commit or
    // roll back together as one unit. Previously the outbox enqueue ran in a
    // separate loop AFTER this transaction closed, so a crash mid-loop could
    // leave some of [items] durably in learning_ledger with no matching
    // outbox row — nothing re-derives a missing outbox row from an existing
    // ledger row.
    await _database.transaction(() async {
      // Outbox: one row per entry (the push pipeline batches contiguous
      // learning_ledger_entry rows on drain), collected here and flushed via
      // one batch() below — DB-3: bulk same-shape writes use batch(), never
      // a loop of individually awaited inserts.
      final outboxRows = <OutboxCompanion>[];

      for (final item in items) {
        final existingCount = await _database.learningLedgerDao
            .getCompletionCount(
              _activeProfileId,
              item.curriculumId,
              item.unitIdentifier,
            );
        final completionNumber = existingCount + 1;

        final now = DateTimeFactory.nowUtc();

        final id = await _database.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: _activeProfileId,
            ulid: drift.Value(newUlid(now)),
            curriculumId: item.curriculumId,
            entryScope: item.entryScope,
            unitIdentifier: item.unitIdentifier,
            unitDisplayNameHe: item.unitDisplayNameHe,
            unitDisplayNameEn: item.unitDisplayNameEn,
            trackType: item.trackType,
            trackId: drift.Value(item.trackId),
            completedAt: completedAt,
            completionNumber: completionNumber,
            markedBy: item.markedBy,
            isManual: drift.Value(item.isManual),
          ),
        );

        final entry = await _database.learningLedgerDao.getEntryById(id);
        if (entry == null) {
          throw StateError('Failed to load ledger row after insert (id=$id)');
        }
        results.add(entry);
        if (_outboxFacade != null) {
          outboxRows.add(_outboxRowFor(entry, now));
        }
      }

      if (outboxRows.isNotEmpty) {
        await _database.batch((b) {
          _database.outboxDao.batchInsertOutboxRows(b, outboxRows);
        });
      }
    });

    // Write-tee: kick the drain now that the batch has actually committed
    // (mirrors the D14 pattern in PointsBalanceDao).
    if (results.isNotEmpty) {
      await _outboxFacade?.requestSyncDrain();
    }

    return results;
  }

  @override
  Future<List<LearningLedgerData>> getLifetimeLedger(int profileId) {
    return _database.learningLedgerDao.getEntriesByProfile(profileId);
  }

  @override
  Future<List<LearningLedgerData>> getLedgerByCurriculum(
    int profileId,
    String curriculumId,
  ) {
    return _database.learningLedgerDao.getEntriesByCurriculum(
      profileId,
      curriculumId,
    );
  }

  @override
  Future<Map<String, int>> getCompletionStats(
    int profileId,
    String curriculumId,
  ) async {
    final entries = await _database.learningLedgerDao.getEntriesByCurriculum(
      profileId,
      curriculumId,
    );

    final manual = entries.where((e) => e.isManual).length;
    final auto = entries.where((e) => !e.isManual).length;

    return {'total': entries.length, 'manual': manual, 'auto': auto};
  }
}
