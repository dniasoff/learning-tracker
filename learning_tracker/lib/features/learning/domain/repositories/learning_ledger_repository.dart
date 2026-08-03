import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

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
  ///
  /// [source] controls whether the sentinel date (DateTime.utc(2000, 1, 1)) is
  /// written instead of the real timestamp. Non-live sources (bulkInTrack /
  /// lifetimeOnly) write the sentinel so a siyum triggered by a bulk mark does
  /// not surface as today's recent activity or inflate streak/points-per-day
  /// reads (Rule 4 / DEC-19). Defaults to [CompletionSource.live].
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
  });

  /// Batch-insert manual ledger rows (e.g. lifetime marking UI).
  ///
  /// Same permission rules as [recordCompletion]. Uses one DB transaction and
  /// a single cloud sync batch so large selections stay responsive.
  ///
  /// [source] controls which tier of side effects fire and whether the sentinel
  /// date (DateTime.utc(2000, 1, 1)) is written instead of the real timestamp.
  /// Defaults to [CompletionSource.lifetimeOnly] so historical imports never
  /// inflate streak, points, or recent-activity reads.
  Future<List<LearningLedgerData>> recordCompletionsBatch(
    List<LedgerManualBatchItem> items, {
    CompletionSource source = CompletionSource.lifetimeOnly,
  });

  /// Get the full lifetime ledger for a profile.
  Future<List<LearningLedgerData>> getLifetimeLedger(int profileId);

  /// Get the lifetime ledger for a profile, filtered to one curriculum.
  Future<List<LearningLedgerData>> getLedgerByCurriculum(
    int profileId,
    String curriculumId,
  );

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
    required this.entryScope,
    required this.unitIdentifier,
    required this.unitDisplayNameHe,
    required this.unitDisplayNameEn,
    required this.trackType,
    this.trackId,
    required this.markedBy,
    required this.isManual,
  });

  final String curriculumId;
  final String entryScope;
  final String unitIdentifier;
  final String unitDisplayNameHe;
  final String unitDisplayNameEn;
  final String trackType;
  final int? trackId;
  final int markedBy;
  final bool isManual;
}

/// Thrown when a child profile attempts to self-mark a manual completion.
class ChildSelfMarkException extends PermissionException {
  const ChildSelfMarkException([
    super.message = 'Children cannot mark their own completions',
  ]);
}
