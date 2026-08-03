/// Firestore-backed points-balance read facade — the gamification-side
/// counterpart to `PointsService`
/// (`lib/features/gamification/domain/services/points_service.dart`).
///
/// **Partially unblocked.** `FirestorePointsLedgerRepository`
/// (`lib/data/repositories/firestore_points_ledger_repository.dart`) and
/// `firestorePointsLedgerRepositoryProvider`
/// (`lib/data/firestore/repository_providers.dart`) have since landed —
/// [getGlobalTotal] delegates to [FirestorePointsLedgerRepository.getBalance]
/// directly (that method already does the owner-decision-5 derive-and-clamp
/// work; [FirestorePointsRepository.deriveBalance] below is kept only for its
/// existing callers/tests, not reused internally here to avoid summing the
/// ledger twice).
///
/// [getCurriculumTotal], [getCurriculumBreakdown], and [getDerivedTotal]
/// still throw [PointsRepositoryUnavailableException] — see that exception's
/// doc comment for exactly why: `PointsLedgerEntry`
/// (`lib/data/repositories/points_ledger_entry.dart`) carries no
/// `curriculumId` field at all (by design — see that class's own doc
/// comment), so a per-curriculum breakdown has no data to compute it from
/// through this collection. This is a genuine schema gap, not a missing
/// wiring step; do not paper over it with a guess.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';

/// Thrown by [FirestorePointsRepository.getCurriculumTotal],
/// [FirestorePointsRepository.getCurriculumBreakdown], and
/// [FirestorePointsRepository.getDerivedTotal] — NOT by [getGlobalTotal],
/// which is served (see the class doc comment).
///
/// **What's missing, concretely:** `PointsLedgerEntry`
/// (`lib/data/repositories/points_ledger_entry.dart`) has no `curriculumId`
/// field — every entry is `(ulid, entryKind, delta, note, redemptionUlid,
/// createdAt, source)`, scoped only by profile (the collection path), never
/// by curriculum. There is therefore no honest way to compute a
/// per-curriculum breakdown or total from this collection alone; doing so
/// would mean fabricating a curriculum attribution this repository was never
/// given. Fixing this requires adding a `curriculum_id` field to
/// `points_ledger` documents (a `firestore.rules` + write-path change), out
/// of this file's scope — it belongs under `lib/data/repositories/` and
/// `lib/data/firestore/`, both off-limits to this task (owned by a separate,
/// concurrent task).
///
/// [getDerivedTotal]'s Drift original (`PointsService.getDerivedTotal`) also
/// filters to "reward-eligible tracks" (`RewardMilestoneService
/// .trackCountsTowardRewardPoints`) — a second, independent gap: that
/// eligibility check itself has no Firestore mapping (see
/// `reward_milestone_service.dart`'s call sites, left un-migrated for the
/// same `int trackId` reason documented in this task's report). Even once
/// `curriculum_id` lands on `points_ledger`, [getDerivedTotal] would still
/// need that eligibility answer from somewhere.
class PointsRepositoryUnavailableException implements Exception {
  const PointsRepositoryUnavailableException(this.method);

  /// Name of the [FirestorePointsRepository] method that cannot be served.
  final String method;

  @override
  String toString() =>
      'PointsRepositoryUnavailableException: $method cannot be served — '
      'PointsLedgerEntry (lib/data/repositories/points_ledger_entry.dart) '
      'carries no curriculumId field, so this collection alone cannot answer '
      'a per-curriculum question. See this exception\'s doc comment for the '
      'full reasoning and what would need to change to unblock it.';
}

/// Firestore-backed points-balance read facade.
///
/// ## The balance is DERIVED, never stored — and what that changes
///
/// `docs/firestore-rewrite-map.md`: "`PointsBalance` — derived by summing
/// `points_ledger` — never a stored counter." The Drift-era
/// `PointsBalanceDao.getBalance` reads a STORED, eagerly-maintained
/// `PointsBalance.balance` column, kept in sync with `PointsLedger` by
/// `PointsBalanceDao._applyDeltaInTransaction` /
/// `.reDeriveBalanceFromLedger` on every mutation. Once a real
/// `points_ledger` reader exists, this class must instead sum every ledger
/// entry's `delta` on each read — no stored counter survives the rewrite
/// (see the map doc's "Deleted outright" table: `PointsBalance` is listed
/// explicitly).
///
/// **The clamped-at-zero rule survives unchanged.**
/// `PointsBalanceDao._applyDeltaInTransaction` and
/// `.reDeriveBalanceFromLedger` both clamp the stored balance to
/// `[0, 1 << 30]` — "balance is never negative."
/// [FirestorePointsLedgerRepository.getBalance] (which [getGlobalTotal]
/// delegates to) applies the exact same clamp — see that method's own doc
/// comment — so [getGlobalTotal] produces the SAME balance value the Drift
/// column would have held for the same ledger contents; this is not a
/// behavior change, it is a faithful re-derivation. [deriveBalance] below
/// documents that same clamp rule as a standalone pure function and is kept
/// for its existing callers/tests, but [getGlobalTotal] itself calls
/// [FirestorePointsLedgerRepository.getBalance] directly rather than
/// re-deriving from [deriveBalance], to avoid two independent sums (and two
/// independent negative-raw-sum warnings) over the same ledger read. The one
/// behavioral difference worth flagging explicitly: the Drift balance is
/// transactionally consistent with its own ledger at every instant (each
/// write updates both atomically); a derive-on-read balance computed from a
/// Firestore query is consistent with whatever the query observed at that
/// moment, which — under concurrent writes from two devices, or while an
/// offline-queued write is still in flight — can transiently lag the
/// "true" total until the next read. This is the same derived-vs-stored
/// tradeoff `docs/firestore-rewrite-map.md`'s "Invariants that survive"
/// section accepts globally ("Balances and streaks are derived... never
/// stored counters"), not something specific to this repository.
class FirestorePointsRepository {
  FirestorePointsRepository({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestorePointsLedgerRepositoryProvider`, resolving to `null`
  /// exactly when it does (no active account, or no active learner
  /// profile). Re-resolved on every call rather than cached — see
  /// `FirestoreBookmarkRepositoryAdapter`'s class doc comment (point 3,
  /// `lib/features/learning/data/repositories/bookmark_repository_impl.dart`)
  /// for why.
  Future<FirestorePointsLedgerRepository?> _resolveOrNull() {
    return _ref.read(firestorePointsLedgerRepositoryProvider.future);
  }

  /// Current debitable balance for [curriculumId] — see
  /// [PointsRepositoryUnavailableException].
  Future<int> getCurriculumTotal(String curriculumId) async {
    throw const PointsRepositoryUnavailableException('getCurriculumTotal');
  }

  /// Current debitable balance across every curriculum — delegates to
  /// [FirestorePointsLedgerRepository.getBalance] (owner decision 5: derived
  /// by summing the append-only `points_ledger`, clamped to `[0, 1 << 30]`).
  /// Not-ready (no active account/profile yet) reads as `0` — the same
  /// natural-empty-value convention `FirestoreProgressRepositoryAdapter`
  /// uses for its `int`-returning methods, rather than throwing.
  Future<int> getGlobalTotal() async {
    final repo = await _resolveOrNull();
    if (repo == null) return 0;
    return repo.getBalance();
  }

  /// Derived sum of completion points (no clamp — see
  /// `PointsService.getDerivedTotal`'s own doc comment for why this differs
  /// from [getGlobalTotal]) — see [PointsRepositoryUnavailableException].
  Future<int> getDerivedTotal() async {
    throw const PointsRepositoryUnavailableException('getDerivedTotal');
  }

  /// Per-curriculum points breakdown — see
  /// [PointsRepositoryUnavailableException].
  Future<Map<CurriculumId, int>> getCurriculumBreakdown() async {
    throw const PointsRepositoryUnavailableException('getCurriculumBreakdown');
  }

  /// Re-derives a debitable balance from a flat list of ledger `delta`
  /// values, applying the exact clamp
  /// `PointsBalanceDao._applyDeltaInTransaction` /
  /// `.reDeriveBalanceFromLedger` use (`[0, 1 << 30]`, "balance is never
  /// negative") — see the class doc comment's "clamped-at-zero rule
  /// survives unchanged" section.
  ///
  /// Pure and Firestore-independent by design: once a real
  /// `points_ledger` reader exists, feeding its entries' `delta` fields
  /// through this function is the entire implementation of
  /// [getGlobalTotal]/[getCurriculumTotal] — no further design work is
  /// needed on the derivation itself, only on fetching [deltas].
  static int deriveBalance(Iterable<int> deltas) {
    final sum = deltas.fold<int>(0, (total, delta) => total + delta);
    return sum.clamp(0, 1 << 30);
  }
}
