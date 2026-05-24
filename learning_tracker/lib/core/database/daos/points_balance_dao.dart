import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/points_balance.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'points_balance_dao.g.dart';

/// DAO for managing the stored debitable points balance (WS7.balance).
///
/// All balance mutations are atomic: they update [PointsBalance] and insert a
/// [PointsLedger] row in a single transaction. Callers must not manipulate
/// either table directly.
///
/// Adults never have balance rows (Rule 3). Callers that award points should
/// confirm the profile is a child before calling this DAO.
@DriftAccessor(tables: [PointsBalance, PointsLedger, RewardRedemptions])
class PointsBalanceDao extends DatabaseAccessor<UserDatabase>
    with _$PointsBalanceDaoMixin {
  PointsBalanceDao(super.db);

  // ─── Balance reads ──────────────────────────────────────────────────────────

  /// Current balance for [profileId]. Returns 0 if no row exists.
  Future<int> getBalance(int profileId) async {
    final row = await (select(pointsBalance)
          ..where((t) => t.profileId.equals(profileId)))
        .getSingleOrNull();
    return row?.balance ?? 0;
  }

  /// Watch the balance as a stream (for reactive UI).
  Stream<int> watchBalance(int profileId) {
    return (select(pointsBalance)
          ..where((t) => t.profileId.equals(profileId)))
        .map((row) => row.balance)
        .watchSingleOrNull()
        .map((b) => b ?? 0);
  }

  // ─── Balance mutations (atomic: ledger + balance) ───────────────────────────

  /// Credit [amount] points to [profileId] on completion.
  ///
  /// [amount] must be > 0.
  Future<void> creditCompletion(int profileId, int amount,
      {String? note}) async {
    assert(amount > 0, 'Credit amount must be positive');
    await _applyDelta(
      profileId: profileId,
      delta: amount,
      entryKind: 'completion',
      note: note,
    );
  }

  /// Debit [amount] points from [profileId] for a redemption.
  ///
  /// Returns `false` if the balance would go below 0 (insufficient funds);
  /// `true` on success.
  Future<bool> debitRedemption(
    int profileId,
    int amount, {
    required int redemptionId,
    String? note,
  }) async {
    assert(amount > 0, 'Debit amount must be positive');
    final current = await getBalance(profileId);
    if (current < amount) return false;
    await _applyDelta(
      profileId: profileId,
      delta: -amount,
      entryKind: 'redemption_debit',
      note: note,
      redemptionId: redemptionId,
    );
    return true;
  }

  /// Refund [amount] points to [profileId] when a redemption is declined.
  Future<void> refundRedemption(
    int profileId,
    int amount, {
    required int redemptionId,
    String? note,
  }) async {
    assert(amount > 0, 'Refund amount must be positive');
    await _applyDelta(
      profileId: profileId,
      delta: amount,
      entryKind: 'redemption_refund',
      note: note,
      redemptionId: redemptionId,
    );
  }

  /// Parent manual adjustment. Positive [delta] = add; negative [delta] = deduct.
  ///
  /// Deductions clamp at 0 (balance never goes below zero).
  Future<void> parentAdjust(int profileId, int delta, {String? note}) async {
    assert(delta != 0, 'Adjustment delta must be non-zero');
    final entryKind = delta > 0 ? 'parent_add' : 'parent_deduct';
    if (delta < 0) {
      final current = await getBalance(profileId);
      final deductible = delta.abs() > current ? current : delta.abs();
      if (deductible == 0) return;
      await _applyDelta(
        profileId: profileId,
        delta: -deductible,
        entryKind: entryKind,
        note: note,
      );
    } else {
      await _applyDelta(
        profileId: profileId,
        delta: delta,
        entryKind: entryKind,
        note: note,
      );
    }
  }

  // ─── Redemption CRUD ────────────────────────────────────────────────────────

  /// Pending redemptions for [profileId] (child browses own redemptions).
  Future<List<RewardRedemption>> getPendingRedemptions(int profileId) async {
    return (select(rewardRedemptions)
          ..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.status.equals('pending_fulfilment'),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// All redemptions for [profileId] (history).
  Future<List<RewardRedemption>> getAllRedemptions(int profileId) async {
    return (select(rewardRedemptions)
          ..where((t) => t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Watch pending redemptions as a stream (for parent approval screen).
  Stream<List<RewardRedemption>> watchPendingRedemptions(int profileId) {
    return (select(rewardRedemptions)
          ..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.status.equals('pending_fulfilment'),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Create a redemption and debit the balance atomically.
  ///
  /// Returns the new [RewardRedemption] row, or `null` if the balance is
  /// insufficient.
  Future<RewardRedemption?> createRedemption({
    required int profileId,
    required String rewardTitle,
    required int iconIndex,
    required int pointsCost,
  }) async {
    RewardRedemption? result;
    await db.transaction(() async {
      final current = await getBalance(profileId);
      if (current < pointsCost) return;

      final now = DateTimeFactory.nowUtc();
      final id = await into(rewardRedemptions).insert(
        RewardRedemptionsCompanion.insert(
          profileId: profileId,
          rewardTitle: rewardTitle,
          iconIndex: Value(iconIndex),
          pointsCost: pointsCost,
          createdAt: now,
          updatedAt: now,
        ),
      );
      result = await (select(rewardRedemptions)
            ..where((t) => t.id.equals(id)))
          .getSingle();

      // Debit the balance in the same transaction.
      await _applyDeltaInTransaction(
        profileId: profileId,
        delta: -pointsCost,
        entryKind: 'redemption_debit',
        note: rewardTitle,
        redemptionId: id,
        now: now,
      );
    });
    return result;
  }

  /// Fulfil a pending redemption (parent approves).
  Future<void> fulfilRedemption(int redemptionId) async {
    final now = DateTimeFactory.nowUtc();
    await (update(rewardRedemptions)..where((t) => t.id.equals(redemptionId)))
        .write(
          RewardRedemptionsCompanion(
            status: const Value('fulfilled'),
            updatedAt: Value(now),
          ),
        );
  }

  /// Decline a pending redemption (parent rejects) and refund points.
  Future<void> declineRedemption(int redemptionId) async {
    final row = await (select(rewardRedemptions)
          ..where((t) => t.id.equals(redemptionId)))
        .getSingleOrNull();
    if (row == null || row.status != 'pending_fulfilment') return;

    await db.transaction(() async {
      final now = DateTimeFactory.nowUtc();
      await (update(rewardRedemptions)
            ..where((t) => t.id.equals(redemptionId)))
          .write(
            RewardRedemptionsCompanion(
              status: const Value('declined'),
              updatedAt: Value(now),
            ),
          );
      await _applyDeltaInTransaction(
        profileId: row.profileId,
        delta: row.pointsCost,
        entryKind: 'redemption_refund',
        note: 'Refund: ${row.rewardTitle}',
        redemptionId: redemptionId,
        now: now,
      );
    });
  }

  // ─── Ledger reads ───────────────────────────────────────────────────────────

  /// Full ledger history for [profileId], newest first.
  Future<List<PointsLedgerData>> getLedger(int profileId) async {
    return (select(pointsLedger)
          ..where((t) => t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  /// Apply a delta in a new transaction (used for single-operation mutations).
  Future<void> _applyDelta({
    required int profileId,
    required int delta,
    required String entryKind,
    String? note,
    int? redemptionId,
  }) async {
    await db.transaction(() async {
      await _applyDeltaInTransaction(
        profileId: profileId,
        delta: delta,
        entryKind: entryKind,
        note: note,
        redemptionId: redemptionId,
        now: DateTimeFactory.nowUtc(),
      );
    });
  }

  /// Apply a delta inside an already-open transaction.
  Future<void> _applyDeltaInTransaction({
    required int profileId,
    required int delta,
    required String entryKind,
    required DateTime now,
    String? note,
    int? redemptionId,
  }) async {
    // Upsert the balance row (create if first credit, update otherwise).
    final existing = await (select(pointsBalance)
          ..where((t) => t.profileId.equals(profileId)))
        .getSingleOrNull();

    final current = existing?.balance ?? 0;
    final newBalance = (current + delta).clamp(0, 1 << 30);

    if (existing == null) {
      await into(pointsBalance).insert(
        PointsBalanceCompanion.insert(
          profileId: Value(profileId),
          balance: Value(newBalance),
          updatedAt: now,
        ),
      );
    } else {
      await (update(pointsBalance)
            ..where((t) => t.profileId.equals(profileId)))
          .write(
            PointsBalanceCompanion(
              balance: Value(newBalance),
              updatedAt: Value(now),
            ),
          );
    }

    // Append the ledger entry.
    await into(pointsLedger).insert(
      PointsLedgerCompanion.insert(
        profileId: profileId,
        entryKind: entryKind,
        delta: delta,
        note: Value(note),
        redemptionId: Value(redemptionId),
        createdAt: now,
      ),
    );
  }
}
