import 'package:learning_tracker/core/database/user/user_database.dart';

/// Repository interface for learning ledger operations.
///
/// The learning ledger is an append-only record of lifetime learning
/// completions. Entries are never updated or deleted.
abstract class LearningLedgerRepository {
  /// Record a unit completion in the ledger.
  ///
  /// Auto-calculates [completionNumber] (existing count + 1).
  /// Validates permissions based on profile mode (AC 5).
  /// Pushes to sync queue after insert.
  ///
  /// Throws [ChildSelfMarkException] if a child profile attempts to self-mark
  /// without an active parent PIN session for this profile.
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
  });

  /// Batch-insert manual ledger rows (e.g. lifetime marking UI).
  ///
  /// Same permission rules as [recordCompletion]. Uses one DB transaction and
  /// a single cloud sync batch so large selections stay responsive.
  Future<List<LearningLedgerData>> recordCompletionsBatch(
    List<LedgerManualBatchItem> items,
  );

  /// Get the full lifetime ledger for a profile.
  Future<List<LearningLedgerData>> getLifetimeLedger(int profileId);

  /// Get completion stats for a curriculum.
  ///
  /// Returns a map with keys: 'total', 'manual', 'auto'.
  Future<Map<String, int>> getCompletionStats(
    int profileId,
    String curriculumId,
  );
}

/// One row for [LearningLedgerRepository.recordCompletionsBatch].
class LedgerManualBatchItem {
  const LedgerManualBatchItem({
    required this.curriculumId,
    required this.unitType,
    required this.unitIdentifier,
    required this.unitDisplayNameHe,
    required this.unitDisplayNameEn,
    required this.trackType,
    this.trackId,
    required this.markedBy,
    required this.isManual,
  });

  final String curriculumId;
  final String unitType;
  final String unitIdentifier;
  final String unitDisplayNameHe;
  final String unitDisplayNameEn;
  final String trackType;
  final int? trackId;
  final int markedBy;
  final bool isManual;
}

/// Thrown when a child profile attempts to self-mark a manual completion.
class ChildSelfMarkException implements Exception {
  final String message;
  const ChildSelfMarkException([
    this.message = 'Children cannot mark their own completions',
  ]);

  @override
  String toString() => 'ChildSelfMarkException: $message';
}
