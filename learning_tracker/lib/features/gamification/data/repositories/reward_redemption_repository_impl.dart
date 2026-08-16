import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_redemption.dart';

/// Thrown when `firestoreRewardRedemptionRepositoryProvider` resolves to
/// `null` — see `StudyDayWriteRepositoryNotReadyException`'s doc comment
/// for the pattern this mirrors.
class RewardRedemptionRepositoryNotReadyException implements Exception {
  const RewardRedemptionRepositoryNotReadyException();

  @override
  String toString() =>
      'RewardRedemptionRepositoryNotReadyException: '
      'firestoreRewardRedemptionRepositoryProvider resolved to null (no '
      'active account, or no active learner profile, yet).';
}

/// Feature-scoped adapter over [FirestoreRewardRedemptionRepository] --
/// presentation/** (child_redemption_screen.dart,
/// parent_pending_redemptions_screen.dart) cannot reach
/// `lib/data/firestore/repository_providers.dart` directly (AD-23/AD-28);
/// this file's own path (`.../data/repositories/`) is the sanctioned seam.
class FirestoreRewardRedemptionRepositoryAdapter {
  FirestoreRewardRedemptionRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Returns `null` when the balance is insufficient (matching the
  /// underlying repository's D-E-honest contract) -- throws only when the
  /// backend itself is not ready.
  Future<RewardRedemptionEntity?> createRedemption({
    required String rewardTitle,
    required int iconIndex,
    required int pointsCost,
  }) async {
    final repo = await _ref.read(
      firestoreRewardRedemptionRepositoryProvider.future,
    );
    if (repo == null) {
      throw const RewardRedemptionRepositoryNotReadyException();
    }
    return repo.createRedemption(
      rewardTitle: rewardTitle,
      iconIndex: iconIndex,
      pointsCost: pointsCost,
    );
  }

  Stream<List<RewardRedemptionEntity>> watchPendingRedemptions() async* {
    final repo = await _ref.read(
      firestoreRewardRedemptionRepositoryProvider.future,
    );
    if (repo == null) {
      // Pending redemptions are learner spend state, not configuration. An
      // empty stream here would claim that the learner has no pending
      // requests when the profile-scoped backend simply is not ready.
      throw const RewardRedemptionRepositoryNotReadyException();
    }
    yield* repo.watchPendingRedemptions();
  }

  Future<void> fulfilRedemption(String ulid) async {
    final repo = await _ref.read(
      firestoreRewardRedemptionRepositoryProvider.future,
    );
    if (repo == null) {
      throw const RewardRedemptionRepositoryNotReadyException();
    }
    await repo.fulfilRedemption(ulid);
  }

  Future<void> declineRedemption(String ulid) async {
    final repo = await _ref.read(
      firestoreRewardRedemptionRepositoryProvider.future,
    );
    if (repo == null) {
      throw const RewardRedemptionRepositoryNotReadyException();
    }
    await repo.declineRedemption(ulid);
  }
}
