import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
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

  Map<String, dynamic> _ledgerDataToSyncMap(LearningLedgerData entry) => {
    'ulid': entry.ulid,
    'curriculum_id': entry.curriculumId,
    'entry_scope': entry.entryScope,
    'unit_identifier': entry.unitIdentifier,
    'unit_display_name_he': entry.unitDisplayNameHe,
    'unit_display_name_en': entry.unitDisplayNameEn,
    'track_type': entry.trackType,
    'track_id': entry.trackId,
    'completed_at': entry.completedAt.toIso8601String(),
    'completion_number': entry.completionNumber,
    'marked_by': entry.markedBy,
    'is_manual': entry.isManual,
  };

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
  }) async {
    _assertManualMarkPermission(markedBy: markedBy, isManual: isManual);

    final existingCount = await _database.learningLedgerDao.getCompletionCount(
      _activeProfileId,
      curriculumId,
      unitIdentifier,
    );
    final completionNumber = existingCount + 1;

    final now = DateTimeFactory.nowUtc();

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
        completedAt: now,
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

  @override
  Future<List<LearningLedgerData>> recordCompletionsBatch(
    List<LedgerManualBatchItem> items,
  ) async {
    if (items.isEmpty) return const [];

    for (final item in items) {
      _assertManualMarkPermission(
        markedBy: item.markedBy,
        isManual: item.isManual,
      );
    }

    final results = <LearningLedgerData>[];

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
            completedAt: now,
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
