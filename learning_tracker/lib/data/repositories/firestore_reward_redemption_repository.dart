/// Firestore implementation for the child prize-redemption workflow
/// (Phase 3 task #15, owner-approved "build it now"). `reward_redemptions`
/// (the collection) and `DocIds.rewardRedemptionDocId` both already
/// existed — an earlier wave scaffolded the rules/doc-id formula ahead of
/// this repository. No Cloud Function exists for this collection
/// (confirmed via grep of functions/src/) — firestore.rules already allows
/// plain client create/update (`allow create, update: if isOwner(uid)`, no
/// field whitelist — an open-bag collection like `settings`/`preferences`).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/firestore/write_ack.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_redemption.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

/// Firestore-backed reward-redemption repository:
/// `users/{uid}/learner_profiles/{profileId}/reward_redemptions/{ulid}`
/// (`firestore.rules` `match /reward_redemptions/{redemptionId}`).
///
/// Composes [FirestorePointsLedgerRepository] internally (same
/// firestore/uid/profileId scope) rather than taking it as a constructor
/// dependency — both are stateless, scope-only repositories, and every
/// redemption mutation needs the ledger in lockstep (a debit on create, a
/// refund on decline), so there is no scenario where a caller would want a
/// different ledger instance injected here.
///
/// **Balance-check-then-debit is plain sequential client code, not a
/// Firestore transaction.** This matches the Drift-era client-side
/// implementation's existing risk profile exactly (a concurrent redemption
/// from two devices could theoretically both read a stale balance and both
/// succeed) — not a new race introduced here, and not a pre-existing one
/// this task set out to close either.
class FirestoreRewardRedemptionRepository {
  FirestoreRewardRedemptionRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    AppLogger? logger,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _logger = logger ?? AppLogger.instance;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final AppLogger _logger;

  FirestorePointsLedgerRepository get _ledger =>
      FirestorePointsLedgerRepository(
        firestore: _firestore,
        uid: _uid,
        profileId: _profileId,
      );

  CollectionReference<Map<String, dynamic>> get _redemptions => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('reward_redemptions');

  DocumentReference<Map<String, dynamic>> _doc(String ulid) {
    final docId = DocIds.rewardRedemptionDocId({'ulid': ulid})!;
    return _redemptions.doc(docId);
  }

  RewardRedemptionEntity? _decode(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) return null;
    return rewardRedemptionFromFirestore(data);
  }

  List<RewardRedemptionEntity> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <RewardRedemptionEntity>[];
    for (final doc in docs) {
      try {
        results.add(rewardRedemptionFromFirestore(doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_reward_redemptions_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  Query<Map<String, dynamic>> get _pendingQuery => _redemptions.where(
    'status',
    isEqualTo: RewardRedemptionStatus.pendingFulfilment,
  );

  /// Creates a redemption request for [rewardTitle] (cost [pointsCost]) if
  /// the current balance covers it — debits the balance via a
  /// `redemption_debit` ledger entry and creates the
  /// `pending_fulfilment` redemption doc. Returns `null` (no write at all)
  /// when the balance is insufficient — mirrors the Drift-era
  /// `PointsBalanceDao.createRedemption`'s `null` = "declined for
  /// insufficient funds" contract exactly, so the child screen's existing
  /// "not enough points" branch needs no behavior change.
  Future<RewardRedemptionEntity?> createRedemption({
    required String rewardTitle,
    required int iconIndex,
    required int pointsCost,
  }) async {
    final balance = await _ledger.getBalance();
    if (balance < pointsCost) return null;

    final ulid = newUlid();
    final now = DateTimeFactory.nowUtc();

    await _ledger.append(
      ulid: ulid,
      entryKind: 'redemption_debit',
      delta: -pointsCost,
      createdAt: now,
      redemptionUlid: ulid,
      source: CompletionSource.live,
    );

    final entry = RewardRedemptionEntity(
      ulid: ulid,
      rewardTitle: rewardTitle,
      iconIndex: iconIndex,
      pointsCost: pointsCost,
      status: RewardRedemptionStatus.pendingFulfilment,
      createdAt: now,
    );
    await _doc(ulid).set(entry.toFirestore()).orQueuedOffline;
    return entry;
  }

  /// Every pending (`pending_fulfilment`) redemption request.
  Future<List<RewardRedemptionEntity>> getPendingRedemptions() async {
    final snapshot = await _pendingQuery.get();
    return _decodeAll(snapshot.docs);
  }

  /// Live updates for the pending-redemption list. Resubscribes with
  /// bounded exponential backoff on a stream-level error
  /// (`resilientQueryStream`).
  Stream<List<RewardRedemptionEntity>> watchPendingRedemptions() {
    return resilientQueryStream<RewardRedemptionEntity>(
      openStream: () => _pendingQuery.snapshots(),
      decode: (doc) => rewardRedemptionFromFirestore(doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_reward_redemptions_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'profile_id': _profileId},
      ),
    );
  }

  /// Marks [ulid]'s redemption as fulfilled (the parent handed over the
  /// physical prize) — no balance change.
  Future<void> fulfilRedemption(String ulid) async {
    await _doc(ulid).set({
      'status': RewardRedemptionStatus.fulfilled,
      'resolved_at': DateTimeFactory.nowUtc().toIso8601String(),
    }, SetOptions(merge: true)).orQueuedOffline;
  }

  /// Declines [ulid]'s redemption and refunds its points via a
  /// `redemption_refund` ledger entry.
  ///
  /// Throws [StateError] if the redemption document cannot be found — a
  /// not-ready/deleted-document inconsistency, never silently skipped (a
  /// skipped refund would leave the child's balance short with no trace).
  Future<void> declineRedemption(String ulid) async {
    final snapshot = await _doc(ulid).get();
    final redemption = _decode(snapshot);
    if (redemption == null) {
      throw StateError(
        'FirestoreRewardRedemptionRepository.declineRedemption: no '
        'redemption document found for ulid=$ulid — refusing to silently '
        'skip the refund.',
      );
    }

    final now = DateTimeFactory.nowUtc();
    await _ledger.append(
      ulid: newUlid(),
      entryKind: 'redemption_refund',
      delta: redemption.pointsCost,
      createdAt: now,
      redemptionUlid: ulid,
      source: CompletionSource.live,
    );
    await _doc(ulid).set({
      'status': RewardRedemptionStatus.declined,
      'resolved_at': now.toIso8601String(),
    }, SetOptions(merge: true)).orQueuedOffline;
  }
}
