import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/sync/codec/learning_ledger_codec.dart';
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

  Future<void> _syncLedgerEntry(LearningLedgerData entry) async {
    await _outboxFacade?.enqueueLedgerEntry(_ledgerDataToSyncMap(entry));
  }

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
    final completedAt = source.creditsEngagement ? now : _kSentinelDate;

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

    final entry = await _database.learningLedgerDao.getEntryById(id);
    if (entry == null) {
      throw StateError('Failed to load ledger row after insert (id=$id)');
    }

    await _syncLedgerEntry(entry);

    return entry;
  }

  /// Sentinel date written for non-live batch marks so that streak,
  /// points-per-day, and recent-activity reads are not inflated by
  /// historical or bulk imports.
  static final DateTime _kSentinelDate = DateTime.utc(2000, 1, 1);

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
        : _kSentinelDate;

    await _database.transaction(() async {
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
      }
    });

    if (results.isNotEmpty) {
      // Outbox: one row per entry. The push pipeline batches contiguous
      // learning_ledger_entry rows when it drains (gateway already has a
      // batched writer), so per-entry enqueue still results in a single
      // Firestore WriteBatch on the wire.
      final facade = _outboxFacade;
      if (facade != null) {
        for (final entry in results) {
          await facade.enqueueLedgerEntry(_ledgerDataToSyncMap(entry));
        }
      }
    }

    return results;
  }

  @override
  Future<List<LearningLedgerData>> getLifetimeLedger(int profileId) {
    return _database.learningLedgerDao.getEntriesByProfile(profileId);
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
