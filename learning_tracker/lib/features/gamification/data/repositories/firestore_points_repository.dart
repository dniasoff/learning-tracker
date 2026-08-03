/// Firestore-backed points-balance read facade — the gamification-side
/// counterpart to `PointsService`
/// (`lib/features/gamification/domain/services/points_service.dart`).
///
/// **Blocked, not built** — see [PointsRepositoryUnavailableException]'s
/// doc comment for exactly what is missing and why every method here throws
/// unconditionally. This file exists to (a) hold the one piece that CAN be
/// finished today — [FirestorePointsRepository.deriveBalance], the pure
/// derivation rule a real implementation will need — and (b) give the
/// eventual real adapter a fixed shape and a single, named, well-documented
/// failure to replace once its dependency lands.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Thrown by every [FirestorePointsRepository] method — there is no
/// Firestore repository for `points_ledger` to delegate to yet.
///
/// **What's missing, concretely:**
/// - No `FirestorePointsLedgerRepository` class exists under
///   `lib/data/repositories/` (compare `firestore_learning_ledger_repository.dart`
///   / `firestore_streak_event_repository.dart`, which this task DID find
///   built and used).
/// - No `firestorePointsLedgerRepositoryProvider` exists in
///   `lib/data/firestore/repository_providers.dart` (compare
///   `firestoreLearningLedgerRepositoryProvider` /
///   `firestoreStreakEventRepositoryProvider`, both present).
/// - No Firestore-shaped `PointsLedgerEntry` domain entity exists anywhere
///   in `lib/` (compare `LearningLedgerEntry` / `StreakEventEntry`, both
///   present alongside their repositories).
///
/// `firestore.rules` already has a `points_ledger` collection block
/// (`match /points_ledger/{entryId}`, SR-1/SR-3/SR-4 all present) and
/// `DocIds.pointsLedgerDocId` already has its doc-id formula — the SCHEMA
/// is ready, only the client-side repository layer is not. Building that
/// repository is out of this task's scope: it belongs under
/// `lib/data/repositories/` and `lib/data/firestore/`, both explicitly
/// off-limits here (see this task's brief — those directories are owned by
/// a separate, concurrent task).
///
/// **Once that lands**, [FirestorePointsRepository]'s methods become a thin
/// wrapper: fetch every `points_ledger` entry for the profile (paginated,
/// same shape as [FirestorePointsRepository.deriveBalance]'s `deltas`
/// parameter expects), then call [FirestorePointsRepository.deriveBalance]
/// on the result. The derivation itself needs no further design work — it
/// is already written, and already tested, below.
class PointsRepositoryUnavailableException implements Exception {
  const PointsRepositoryUnavailableException(this.method);

  /// Name of the [FirestorePointsRepository] method that cannot be served.
  final String method;

  @override
  String toString() =>
      'PointsRepositoryUnavailableException: $method cannot be served — no '
      'FirestorePointsLedgerRepository exists yet under '
      'lib/data/repositories/, and no provider for it exists in '
      'lib/data/firestore/repository_providers.dart. See this exception\'s '
      'doc comment for what is missing and what unblocks it.';
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
/// `[0, 1 << 30]` — "balance is never negative." [deriveBalance] below
/// applies the exact same clamp to the summed deltas, so a real
/// implementation built on it produces the SAME balance value the Drift
/// column would have held for the same ledger contents — this is not a
/// behavior change, it is a faithful re-derivation. The one behavioral
/// difference worth flagging explicitly: the Drift balance is
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

  // ignore: unused_field
  final Ref _ref;

  /// Current debitable balance for [curriculumId] — see
  /// [PointsRepositoryUnavailableException].
  Future<int> getCurriculumTotal(String curriculumId) async {
    throw const PointsRepositoryUnavailableException('getCurriculumTotal');
  }

  /// Current debitable balance across every curriculum — see
  /// [PointsRepositoryUnavailableException].
  Future<int> getGlobalTotal() async {
    throw const PointsRepositoryUnavailableException('getGlobalTotal');
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
