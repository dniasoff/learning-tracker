import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

/// Implementation of [LearningLedgerRepository] using Drift database and sync engine.
class LearningLedgerRepositoryImpl implements LearningLedgerRepository {
  final UserDatabase _database;
  final SyncEngine _syncEngine;
  final int _activeProfileId;
  final String _activeProfileMode;

  LearningLedgerRepositoryImpl({
    required UserDatabase database,
    required SyncEngine syncEngine,
    required int activeProfileId,
    required String activeProfileMode,
  }) : _database = database,
       _syncEngine = syncEngine,
       _activeProfileId = activeProfileId,
       _activeProfileMode = activeProfileMode;

  @override
  Future<LearningLedgerData> recordCompletion({
    required String curriculumId,
    required String unitType,
    required String unitIdentifier,
    required String unitDisplayNameHe,
    required String unitDisplayNameEn,
    required String trackType,
    int? trackId,
    required int markedBy,
    required bool isManual,
  }) async {
    // Permission check: children cannot self-mark
    if (isManual &&
        _activeProfileMode == 'child' &&
        markedBy == _activeProfileId) {
      throw const ChildSelfMarkException();
    }

    // Auto-calculate completion number
    final existingCount = await _database.learningLedgerDao.getCompletionCount(
      _activeProfileId,
      curriculumId,
      unitIdentifier,
    );
    final completionNumber = existingCount + 1;

    final now = DateTimeFactory.nowUtc();

    final id = await _database.learningLedgerDao.insertEntry(
      LearningLedgerCompanion.insert(
        profileId: drift.Value(_activeProfileId),
        curriculumId: curriculumId,
        unitType: unitType,
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

    // Retrieve the created entry
    final entries = await _database.learningLedgerDao.getEntriesByProfile(
      _activeProfileId,
    );
    final entry = entries.firstWhere((e) => e.id == id);

    // Push to sync queue
    await _syncLedgerEntry(entry);

    return entry;
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

  Future<void> _syncLedgerEntry(LearningLedgerData entry) async {
    final data = {
      'curriculumId': entry.curriculumId,
      'unitType': entry.unitType,
      'unitIdentifier': entry.unitIdentifier,
      'unitDisplayNameHe': entry.unitDisplayNameHe,
      'unitDisplayNameEn': entry.unitDisplayNameEn,
      'trackType': entry.trackType,
      'trackId': entry.trackId,
      'completedAt': entry.completedAt.toIso8601String(),
      'completionNumber': entry.completionNumber,
      'markedBy': entry.markedBy,
      'isManual': entry.isManual,
    };

    await _syncEngine.pushLedgerEntry(data);
  }
}
