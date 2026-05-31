import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/points_balance.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart'
    show OutboxEntityKind;
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'points_balance_dao.g.dart';

/// Sink that ships locally-mutated points rows to the cloud sync outbox.
///
/// WS9 Wave-B (C#2): the points tables now sync. The DAO lives in `core/` and
/// cannot import the outbox facade (which is in `features/sync/`), so the
/// features layer registers a concrete sink on [PointsBalanceDao.syncSink].
/// The DAO calls back after every ledger insert and every redemption mutation
/// so the rows reach Firestore via the outbox.
abstract class PointsSyncSink {
  /// Enqueue a reward-redemption state-machine doc for push to
  /// `users/{uid}/learner_profiles/{profileId}/reward_redemptions/{ulid}`.
  Future<void> enqueueRewardRedemption(Map<String, dynamic> payload);

  /// D14: kick the outbox processor so rows the DAO enqueued *inside* its own
  /// transaction (atomically with the ledger write) are pushed promptly,
  /// without the DAO needing to know about the processor. Best-effort —
  /// failures are swallowed; the row is durable and a later trigger retries.
  Future<void> requestSyncDrain();
}

/// DAO for managing the stored debitable points balance (WS7.balance).
///
/// All balance mutations are atomic: they update [PointsBalance] and insert a
/// [PointsLedger] row in a single transaction. Callers must not manipulate
/// either table directly.
///
/// Adults never have balance rows (Rule 3). Callers that award points should
/// confirm the profile is a child before calling this DAO.
///
/// **Cloud sync (WS9 Wave-B, C#2).** Every ledger insert is stamped with a
/// [PointsLedger.ulid] (deterministic Firestore doc-id) and pushed as an
/// append-only event. Every redemption mutation is pushed as an LWW
/// state-machine doc keyed by [RewardRedemptions.ulid]. The mutable
/// [PointsBalance] row is NEVER synced — it is re-derived locally from the
/// merged ledger so two devices converge without the classic counter LWW
/// lost-update.
@DriftAccessor(tables: [PointsBalance, PointsLedger, RewardRedemptions])
class PointsBalanceDao extends DatabaseAccessor<UserDatabase>
    with _$PointsBalanceDaoMixin {
  PointsBalanceDao(super.db);

  /// Optional cloud-sync sink, set by the features layer for cloud-born
  /// accounts. `null` for local-born accounts (no cloud push).
  PointsSyncSink? syncSink;

  // ─── Balance reads ──────────────────────────────────────────────────────────

  /// Current balance for [profileId]. Returns 0 if no row exists.
  Future<int> getBalance(int profileId) async {
    final row = await (select(
      pointsBalance,
    )..where((t) => t.profileId.equals(profileId))).getSingleOrNull();
    return row?.balance ?? 0;
  }

  /// Watch the balance as a stream (for reactive UI).
  Stream<int> watchBalance(int profileId) {
    return (select(pointsBalance)..where((t) => t.profileId.equals(profileId)))
        .map((row) => row.balance)
        .watchSingleOrNull()
        .map((b) => b ?? 0);
  }

  // ─── Balance mutations (atomic: ledger + balance) ───────────────────────────

  /// Credit [amount] points to [profileId] on completion.
  ///
  /// [amount] must be > 0.
  Future<void> creditCompletion(
    int profileId,
    int amount, {
    String? note,
  }) async {
    assert(amount > 0, 'Credit amount must be positive');
    await _applyDelta(
      profileId: profileId,
      delta: amount,
      entryKind: 'completion',
      note: note,
    );
  }

  /// Parent manual adjustment. Positive [delta] = add; negative [delta] = deduct.
  ///
  /// Deductions clamp at 0 (balance never goes below zero). The read + clamp +
  /// write happen inside a single transaction so a concurrent mutation cannot
  /// race the read-modify-write (R4o-M2).
  Future<void> parentAdjust(int profileId, int delta, {String? note}) async {
    assert(delta != 0, 'Adjustment delta must be non-zero');
    final entryKind = delta > 0 ? 'parent_add' : 'parent_deduct';
    PointsLedgerData? ledgerRow;
    await db.transaction(() async {
      final now = DateTimeFactory.nowUtc();
      if (delta < 0) {
        final current = await _readBalanceInTransaction(profileId);
        final deductible = delta.abs() > current ? current : delta.abs();
        if (deductible == 0) return;
        ledgerRow = await _applyDeltaInTransaction(
          profileId: profileId,
          delta: -deductible,
          entryKind: entryKind,
          note: note,
          now: now,
        );
      } else {
        ledgerRow = await _applyDeltaInTransaction(
          profileId: profileId,
          delta: delta,
          entryKind: entryKind,
          note: note,
          now: now,
        );
      }
    });
    // D14: the outbox row was enqueued atomically inside the transaction; just
    // kick the drain so it pushes promptly.
    if (ledgerRow != null) await _requestDrain();
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
      final current = await _readBalanceInTransaction(profileId);
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
          ulid: Value(newUlid(now)),
        ),
      );
      result = await (select(
        rewardRedemptions,
      )..where((t) => t.id.equals(id))).getSingle();

      // Debit the balance in the same transaction. The debit's ledger outbox
      // row is enqueued atomically inside _applyDeltaInTransaction (D14).
      await _applyDeltaInTransaction(
        profileId: profileId,
        delta: -pointsCost,
        entryKind: 'redemption_debit',
        note: rewardTitle,
        redemptionId: id,
        now: now,
      );
    });
    final redemption = result;
    if (redemption != null) {
      // _pushRedemption enqueues the redemption doc AND kicks the drain, so the
      // in-transaction debit-ledger row is pushed in the same round.
      await _pushRedemption(redemption);
    }
    return result;
  }

  /// Fulfil a pending redemption (parent approves).
  Future<void> fulfilRedemption(int redemptionId) async {
    // D5: only a still-pending redemption may be fulfilled. Mirrors
    // declineRedemption's guard so a late/concurrent fulfil cannot overwrite an
    // already-declined (and refunded) row — which would grant the reward AND
    // keep the refund — nor double-fulfil. Without this guard fulfil was an
    // unconditional write (no status check, unlike decline).
    final existing = await (select(
      rewardRedemptions,
    )..where((t) => t.id.equals(redemptionId))).getSingleOrNull();
    if (existing == null || existing.status != 'pending_fulfilment') return;

    final now = DateTimeFactory.nowUtc();
    await (update(
      rewardRedemptions,
    )..where((t) => t.id.equals(redemptionId))).write(
      RewardRedemptionsCompanion(
        status: const Value('fulfilled'),
        updatedAt: Value(now),
      ),
    );
    final row = await (select(
      rewardRedemptions,
    )..where((t) => t.id.equals(redemptionId))).getSingleOrNull();
    if (row != null) await _pushRedemption(row);
  }

  /// Decline a pending redemption (parent rejects) and refund points.
  Future<void> declineRedemption(int redemptionId) async {
    final row = await (select(
      rewardRedemptions,
    )..where((t) => t.id.equals(redemptionId))).getSingleOrNull();
    if (row == null || row.status != 'pending_fulfilment') return;

    RewardRedemption? updated;
    await db.transaction(() async {
      final now = DateTimeFactory.nowUtc();
      await (update(
        rewardRedemptions,
      )..where((t) => t.id.equals(redemptionId))).write(
        RewardRedemptionsCompanion(
          status: const Value('declined'),
          updatedAt: Value(now),
        ),
      );
      // The refund's ledger outbox row is enqueued atomically inside
      // _applyDeltaInTransaction (D14).
      await _applyDeltaInTransaction(
        profileId: row.profileId,
        delta: row.pointsCost,
        entryKind: 'redemption_refund',
        note: 'Refund: ${row.rewardTitle}',
        redemptionId: redemptionId,
        now: now,
      );
      updated = await (select(
        rewardRedemptions,
      )..where((t) => t.id.equals(redemptionId))).getSingle();
    });
    final u = updated;
    // _pushRedemption kicks the drain, pushing the in-transaction refund-ledger
    // row in the same round.
    if (u != null) await _pushRedemption(u);
  }

  // ─── Ledger reads ───────────────────────────────────────────────────────────

  /// Full ledger history for [profileId], newest first.
  Future<List<PointsLedgerData>> getLedger(int profileId) async {
    return (select(pointsLedger)
          ..where((t) => t.profileId.equals(profileId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  // ─── Cloud sync (WS9 Wave-B) ─────────────────────────────────────────────────

  /// Insert a pulled remote ledger row if its [PointsLedger.ulid] is not
  /// already present locally, then re-derive the balance from the full ledger.
  ///
  /// Append-only / INSERT-OR-IGNORE semantics keyed on `ulid`. Returns `true`
  /// when a new row was inserted (so the caller can decide whether a balance
  /// re-derivation is needed).
  Future<bool> insertRemoteLedgerEntryIfAbsent({
    required int profileId,
    required String ulid,
    required String entryKind,
    required int delta,
    String? note,
    int? redemptionId,
    required DateTime createdAt,
  }) async {
    final existing =
        await (select(pointsLedger)
              ..where((t) => t.ulid.equals(ulid))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return false;
    await into(pointsLedger).insert(
      PointsLedgerCompanion.insert(
        profileId: profileId,
        entryKind: entryKind,
        delta: delta,
        note: Value(note),
        redemptionId: Value(redemptionId),
        createdAt: createdAt,
        ulid: Value(ulid),
        // D14: a pulled row is already on the cloud — stamp it enqueued so the
        // reconciliation never echoes it back to Firestore.
        syncEnqueuedAt: Value(createdAt),
      ),
    );
    return true;
  }

  /// Re-derive and persist the [PointsBalance] for [profileId] from the sum of
  /// all ledger deltas. Clamped at 0 (balance is never negative).
  ///
  /// Called after merging pulled ledger entries so the local denormalised
  /// balance stays consistent with the append-only ledger (the balance itself
  /// is never synced — avoids the counter LWW lost-update).
  Future<void> reDeriveBalanceFromLedger(int profileId) async {
    await db.transaction(() async {
      final deltaExpr = pointsLedger.delta.sum();
      final row =
          await (selectOnly(pointsLedger)
                ..addColumns([deltaExpr])
                ..where(pointsLedger.profileId.equals(profileId)))
              .getSingle();
      final sum = row.read(deltaExpr) ?? 0;
      final newBalance = sum.clamp(0, 1 << 30);
      final now = DateTimeFactory.nowUtc();
      final existing = await (select(
        pointsBalance,
      )..where((t) => t.profileId.equals(profileId))).getSingleOrNull();
      if (existing == null) {
        await into(pointsBalance).insert(
          PointsBalanceCompanion.insert(
            profileId: Value(profileId),
            balance: Value(newBalance),
            updatedAt: now,
          ),
        );
      } else if (existing.balance != newBalance) {
        await (update(
          pointsBalance,
        )..where((t) => t.profileId.equals(profileId))).write(
          PointsBalanceCompanion(
            balance: Value(newBalance),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  /// Upsert a pulled remote redemption row (LWW by `updated_at`). Returns
  /// `true` when the local row was created or overwritten.
  Future<bool> upsertRemoteRedemption({
    required int profileId,
    required String ulid,
    required String rewardTitle,
    required int iconIndex,
    required int pointsCost,
    required String status,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) async {
    final existing =
        await (select(rewardRedemptions)
              ..where((t) => t.ulid.equals(ulid))
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      await into(rewardRedemptions).insert(
        RewardRedemptionsCompanion.insert(
          profileId: profileId,
          rewardTitle: rewardTitle,
          iconIndex: Value(iconIndex),
          pointsCost: pointsCost,
          status: Value(status),
          createdAt: createdAt,
          updatedAt: updatedAt,
          ulid: Value(ulid),
        ),
      );
      return true;
    }
    // LWW: only overwrite when the remote row is strictly newer.
    if (!updatedAt.isAfter(existing.updatedAt)) return false;
    await (update(
      rewardRedemptions,
    )..where((t) => t.id.equals(existing.id))).write(
      RewardRedemptionsCompanion(
        rewardTitle: Value(rewardTitle),
        iconIndex: Value(iconIndex),
        pointsCost: Value(pointsCost),
        status: Value(status),
        updatedAt: Value(updatedAt),
      ),
    );
    return true;
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  /// Apply a delta in a new transaction (used for single-operation mutations),
  /// then push the resulting ledger row to the sync outbox.
  Future<void> _applyDelta({
    required int profileId,
    required int delta,
    required String entryKind,
    String? note,
    int? redemptionId,
  }) async {
    PointsLedgerData? ledgerRow;
    await db.transaction(() async {
      ledgerRow = await _applyDeltaInTransaction(
        profileId: profileId,
        delta: delta,
        entryKind: entryKind,
        note: note,
        redemptionId: redemptionId,
        now: DateTimeFactory.nowUtc(),
      );
    });
    // D14: the outbox row was enqueued atomically inside the transaction; just
    // kick the drain so it pushes promptly.
    if (ledgerRow != null) await _requestDrain();
  }

  /// Read the current balance inside an already-open transaction.
  Future<int> _readBalanceInTransaction(int profileId) async {
    final row = await (select(
      pointsBalance,
    )..where((t) => t.profileId.equals(profileId))).getSingleOrNull();
    return row?.balance ?? 0;
  }

  /// Apply a delta inside an already-open transaction. Returns the inserted
  /// ledger row so the caller can push it to the sync outbox after commit.
  Future<PointsLedgerData> _applyDeltaInTransaction({
    required int profileId,
    required int delta,
    required String entryKind,
    required DateTime now,
    String? note,
    int? redemptionId,
  }) async {
    // Upsert the balance row (create if first credit, update otherwise).
    final existing = await (select(
      pointsBalance,
    )..where((t) => t.profileId.equals(profileId))).getSingleOrNull();

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
      await (update(
        pointsBalance,
      )..where((t) => t.profileId.equals(profileId))).write(
        PointsBalanceCompanion(
          balance: Value(newBalance),
          updatedAt: Value(now),
        ),
      );
    }

    // Append the ledger entry — stamped with a ULID for cross-device sync.
    final ledgerId = await into(pointsLedger).insert(
      PointsLedgerCompanion.insert(
        profileId: profileId,
        entryKind: entryKind,
        delta: delta,
        note: Value(note),
        redemptionId: Value(redemptionId),
        createdAt: now,
        ulid: Value(newUlid(now)),
      ),
    );
    final row = await (select(
      pointsLedger,
    )..where((t) => t.id.equals(ledgerId))).getSingle();

    // D14: enqueue the cloud-sync outbox row IN THE SAME TRANSACTION as the
    // ledger write so the two commit (or roll back) atomically — eliminating
    // the crash window where the ledger row was durable but its outbox enqueue
    // (previously run after the transaction) was lost.
    await _enqueueLedgerInTransaction(row);
    return row;
  }

  /// Enqueue [row] onto the cloud-sync outbox **within the caller's open
  /// transaction** and stamp `sync_enqueued_at` so the reconciliation
  /// ([reEnqueueUnsyncedLedgerRows]) never re-queues it.
  ///
  /// No-op when no sync sink is wired (local-born account, or a cloud-born
  /// account before the features layer registers the sink — the latter is
  /// recovered by the reconciliation on wire).
  Future<void> _enqueueLedgerInTransaction(PointsLedgerData row) async {
    if (syncSink == null || row.ulid == null) return;
    await db.outboxDao.insertOutboxRow(
      OutboxCompanion(
        profileId: Value(row.profileId),
        entityKind: const Value(OutboxEntityKind.pointsLedgerEntry),
        entityKey: Value(row.ulid!),
        payload: Value(jsonEncode(await _ledgerPayload(row))),
        createdAt: Value(row.createdAt),
      ),
    );
    await (update(pointsLedger)..where((t) => t.id.equals(row.id))).write(
      PointsLedgerCompanion(syncEnqueuedAt: Value(row.createdAt)),
    );
  }

  /// The Firestore push payload for a ledger [row] (deterministic doc-id =
  /// `ulid`). Shared by the in-transaction enqueue and the reconciliation.
  Future<Map<String, dynamic>> _ledgerPayload(PointsLedgerData row) async {
    return {
      'ulid': row.ulid,
      'profile_id': row.profileId,
      'entry_kind': row.entryKind,
      'delta': row.delta,
      'note': row.note,
      'redemption_ulid': await _redemptionUlidFor(row.redemptionId),
      'created_at': row.createdAt.toIso8601String(),
    };
  }

  /// Ask the sink to drain the outbox after an in-transaction enqueue, so the
  /// freshly-committed ledger row is pushed promptly. Best-effort.
  Future<void> _requestDrain() async {
    await syncSink?.requestSyncDrain();
  }

  /// D14 reconciliation — re-enqueue every ledger row for [profileId] that was
  /// never queued for push (`sync_enqueued_at IS NULL`). Recovers rows written
  /// while no sync sink was wired (a cloud-born account's first credit before
  /// the features layer registered the sink). Idempotent: once a row is
  /// enqueued its marker is set, so subsequent runs skip it; and even a
  /// re-pushed row is a no-op merge on the receiver (deterministic doc-id =
  /// `ulid`). No-op when no sink is wired (local-born — nothing to push to).
  ///
  /// Call right after wiring [syncSink] (cloud session start / profile switch).
  Future<void> reEnqueueUnsyncedLedgerRows(int profileId) async {
    if (syncSink == null) return;
    final unsynced =
        await (select(pointsLedger)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.syncEnqueuedAt.isNull() &
                    t.ulid.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    if (unsynced.isEmpty) return;

    await db.transaction(() async {
      for (final row in unsynced) {
        await _enqueueLedgerInTransaction(row);
      }
    });
    await _requestDrain();
  }

  /// Resolve the stable [RewardRedemptions.ulid] for a local redemption id so
  /// the synced ledger row references a cross-device-stable redemption id
  /// rather than the device-local autoincrement primary key.
  Future<String?> _redemptionUlidFor(int? redemptionId) async {
    if (redemptionId == null) return null;
    final row =
        await (select(rewardRedemptions)
              ..where((t) => t.id.equals(redemptionId))
              ..limit(1))
            .getSingleOrNull();
    return row?.ulid;
  }

  Future<void> _pushRedemption(RewardRedemption row) async {
    final sink = syncSink;
    if (sink == null || row.ulid == null) return;
    await sink.enqueueRewardRedemption({
      'ulid': row.ulid,
      'profile_id': row.profileId,
      'reward_title': row.rewardTitle,
      'icon_index': row.iconIndex,
      'points_cost': row.pointsCost,
      'status': row.status,
      'created_at': row.createdAt.toIso8601String(),
      'updated_at': row.updatedAt.toIso8601String(),
    });
  }
}
