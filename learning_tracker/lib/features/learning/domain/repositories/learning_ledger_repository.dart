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

    /// Who marked this entry, as a learner-profile ULID (AD-24).
    ///
    /// OPTIONAL: when omitted the implementation stamps the ACTIVE profile.
    /// This exists because the only callers that do not already hold a ULID are
    /// domain services, and the active-profile ULID lives in the data-access
    /// ring, which `check_dependency_direction` (AD-23/AD-28) forbids domain
    /// and presentation code from importing. Rather than smuggle the ring into
    /// the domain, the repository implementation — which is allowed to know —
    /// fills it in.
    String? markedBy,
    required bool isManual,
    CompletionSource source = CompletionSource.live,

    /// Optional DETERMINISTIC document id, making this write idempotent.
    ///
    /// When supplied, a replay of the same logical siyum lands on the SAME
    /// document instead of appending a duplicate. `firestore.rules` accepts
    /// that: an identical replay affects no keys, which is the SR-1 case the
    /// rules permit.
    ///
    /// When omitted the implementation mints a random id, so an entry that has
    /// no natural key (a genuinely new manual mark) still appends.
    String? ulid,
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

  /// Tombstone a learning-ledger entry (D-M / siyum retraction).
  ///
  /// Delegates to `FirestoreLearningLedgerRepository.purgeEntry`, stamping
  /// `purged_at` on the entry keyed by [ulid]. Throws [StateError] when the
  /// entry is absent — a retraction that cannot find its target fails loudly,
  /// never a silent no-op (owner ruling D-E).
  Future<void> purgeEntry({
    required String ulid,
    required DateTime purgedAt,
  });
}

/// Thrown when a child profile attempts to self-mark a manual completion.
class ChildSelfMarkException extends PermissionException {
  const ChildSelfMarkException([
    super.message = 'Children cannot mark their own completions',
  ]);
}
