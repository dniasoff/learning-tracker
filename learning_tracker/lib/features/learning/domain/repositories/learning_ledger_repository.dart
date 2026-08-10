import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';

/// Repository interface for learning ledger operations.
///
/// The learning ledger is an append-only record of lifetime learning
/// completions. `firestore.rules` denies `delete` on the collection outright,
/// so an entry is never removed: retraction is a `purged_at` tombstone (owner
/// ruling D-M, 2026-08-10), and tombstoned entries are invisible to every read
/// declared below.
///
/// **Every method is scoped to the ACTIVE profile.** The Firestore ledger lives
/// at `learner_profiles/{profileId}/learning_ledger`, so the profile is part of
/// the collection path and can never be a parameter. The Drift-era
/// `int profileId` arguments are gone for that reason, not by oversight — and
/// `markedBy` is now a profile ULID `String` (AD-24), not a Drift row id.
///
/// `trackId` is likewise gone: the Firestore ledger is keyed by unit, not by a
/// per-device track row (AD-25).
abstract class LearningLedgerRepository {
  /// Record a unit completion in the ledger.
  ///
  /// Auto-calculates `completionNumber` (existing count + 1).
  /// Validates permissions based on profile mode (AC 5).
  ///
  /// Throws [ChildSelfMarkException] if a child profile attempts to self-mark
  /// without an active parent PIN session for this profile.
  ///
  /// [source] controls whether the sentinel date (DateTime.utc(2000, 1, 1)) is
  /// written instead of the real timestamp. Non-live sources (bulkInTrack /
  /// lifetimeOnly) write the sentinel so a siyum triggered by a bulk mark does
  /// not surface as today's recent activity or inflate streak/points-per-day
  /// reads (Rule 4 / DEC-19). Defaults to [CompletionSource.live].
  Future<LearningLedgerEntry> recordCompletion({
    required CurriculumId curriculumId,
    required String entryScope,
    required String unitIdentifier,
    required String unitDisplayNameHe,
    required String unitDisplayNameEn,
    required String trackType,
    required String markedBy,
    required bool isManual,
    CompletionSource source = CompletionSource.live,
  });

  /// Batch-insert manual ledger rows (e.g. the lifetime marking UI).
  ///
  /// Same permission rules as [recordCompletion]. Chunked into Firestore
  /// `WriteBatch`es so large selections stay responsive.
  ///
  /// Takes [LedgerEntryDraft] — the Firestore-shaped replacement for the
  /// Drift-era `LedgerManualBatchItem`, which this migration deletes.
  ///
  /// [source] controls which tier of side effects fire and whether the sentinel
  /// date is written instead of the real timestamp. Defaults to
  /// [CompletionSource.lifetimeOnly] so historical imports never inflate
  /// streak, points, or recent-activity reads.
  Future<List<LearningLedgerEntry>> recordCompletionsBatch(
    List<LedgerEntryDraft> items, {
    CompletionSource source = CompletionSource.lifetimeOnly,
  });

  /// The full lifetime ledger for the active profile.
  Future<List<LearningLedgerEntry>> getLifetimeLedger();

  /// The lifetime ledger for the active profile, filtered to one curriculum.
  Future<List<LearningLedgerEntry>> getLedgerByCurriculum(
    CurriculumId curriculumId,
  );

  /// Completion stats for a curriculum.
  ///
  /// Returns a map with keys: 'total', 'manual', 'auto'.
  Future<Map<String, int>> getCompletionStats(CurriculumId curriculumId);
}

/// Thrown when a child profile attempts to self-mark a manual completion.
class ChildSelfMarkException extends PermissionException {
  const ChildSelfMarkException([
    super.message = 'Children cannot mark their own completions',
  ]);
}
