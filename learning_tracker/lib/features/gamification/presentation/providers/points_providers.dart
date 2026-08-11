import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/gamification/data/repositories/firestore_curriculum_reward_eligibility_adapter.dart';
import 'package:learning_tracker/features/gamification/data/repositories/firestore_points_balance_reader_adapter.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';

/// Provider for the PointsService.
///
/// **Firestore-backed.** [FirestoreCurriculumRewardEligibilityAdapter] and
/// [FirestorePointsBalanceReaderAdapter] replace the Drift `UserDatabase` +
/// `profileId` construction this provider used before — both adapters
/// resolve the active profile internally via `ref`, so this provider no
/// longer reads `activeProfileIdProvider` itself.
final pointsServiceProvider = Provider<PointsService>((ref) {
  return PointsService(
    eligibility: FirestoreCurriculumRewardEligibilityAdapter(ref: ref),
    balanceReader: FirestorePointsBalanceReaderAdapter(ref: ref),
  );
});

/// Per-curriculum points total, keyed by curriculumId (P3 family pattern).
///
/// SM-6 (docs/coding-standards.md): parameterized/family providers stay
/// autoDispose. `CurriculumId` is a small finite enum, so the leak was
/// bounded, but retaining every family member for the container's lifetime
/// is still inconsistent with the rest of this feature's family providers
/// (AUD-gamification-13).
final curriculumPointsProvider = FutureProvider.autoDispose
    .family<int, CurriculumId>((ref, curriculum) async {
      final service = ref.watch(pointsServiceProvider);
      final completions = await ref
          .watch(completionRepositoryProvider)
          .getCompletionsByCurriculum(curriculum.storageKey);
      return service.getCurriculumTotal(curriculum, completions);
    });

/// Global debitable points balance.
///
/// **Not a live stream, unlike the Drift-era `watchBalance`.** No Firestore
/// equivalent exists or can cheaply exist — `firestore.rules` caps every
/// `points_ledger` query at `limit <= 500` (SR-4), so an unbounded
/// `.snapshots()` listener over the whole ledger is rules-rejected. Re-reads
/// whenever [completionCommittedProvider] fires, matching
/// `dashboardGlobalPoints` (`dashboard_providers.dart`) and
/// `childRedemptionBalance` (`child_redemption_screen.dart`) — see either's
/// doc comment for the full disclosed-regression rationale.
final globalPointsProvider = FutureProvider<int>((ref) async {
  ref.watch<int>(completionCommittedProvider);
  final service = ref.watch(pointsServiceProvider);
  return service.getGlobalTotal();
});

/// Per-curriculum breakdown map.
///
/// DG-BRKD-01: watches [completionCommittedProvider] so the breakdown chips
/// in [PointsDisplayWidget] update after a completion is committed — without
/// requiring a pull-to-refresh or widget disposal/re-creation. Same pattern
/// as [achievementsOverviewProvider] and [dashboardCompletionPercentageProvider].
final curriculumBreakdownProvider = FutureProvider<Map<CurriculumId, int>>((
  ref,
) async {
  // Rebuild whenever a completion is committed — keeps the per-curriculum
  // chip labels live on the gamification screen.
  ref.watch<int>(completionCommittedProvider);
  final service = ref.watch(pointsServiceProvider);
  final repository = ref.watch(completionRepositoryProvider);
  final completions = <CompletionEntity>[
    for (final curriculum in CurriculumId.values)
      ...await repository.getCompletionsByCurriculum(curriculum.storageKey),
  ];
  return service.getCurriculumBreakdown(completions);
});

/// Points history log, optionally filtered by curriculum.
///
/// SM-6 (docs/coding-standards.md): parameterized/family providers stay
/// autoDispose (AUD-gamification-13).
final pointsHistoryProvider = FutureProvider.autoDispose
    .family<List<PointsHistoryEntry>, CurriculumId?>((ref, curriculum) async {
      final service = ref.watch(pointsServiceProvider);
      final repository = ref.watch(completionRepositoryProvider);
      final completions = curriculum != null
          ? await repository.getCompletionsByCurriculum(curriculum.storageKey)
          : <CompletionEntity>[
              for (final c in CurriculumId.values)
                ...await repository.getCompletionsByCurriculum(c.storageKey),
            ];
      return service.getPointsHistory(
        completions: completions,
        curriculumId: curriculum,
      );
    });
