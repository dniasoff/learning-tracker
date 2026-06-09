import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

/// Provider for the PointsService, scoped to active profile.
final pointsServiceProvider = Provider<PointsService>((ref) {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return PointsService(database, profileId: profileId);
});

/// Per-curriculum points total, keyed by curriculumId (P3 family pattern).
final curriculumPointsProvider = FutureProvider.family<int, CurriculumId>((
  ref,
  curriculum,
) async {
  final service = ref.watch(pointsServiceProvider);
  return service.getCurriculumTotal(curriculum.storageKey);
});

/// Global debitable points balance — reactive stream backed by watchBalance.
///
/// DG-DASH-02 / D9: previously a one-shot [FutureProvider] calling
/// [PointsService.getGlobalTotal] (which reads the balance once). This left
/// the gamification-screen points counter STALE after any balance mutation
/// (redemption debit, parent refund, completion credit) until the user
/// pull-to-refreshed.
///
/// Fix: converted to a [StreamProvider] backed by
/// [PointsBalanceDao.watchBalance] — the same reactive read path used by
/// [dashboardGlobalPointsProvider]. Any write to the PointsBalance row
/// (credit, debit, refund) causes the stream to emit the new value
/// immediately, so the gamification screen's counter stays live without
/// requiring manual invalidation or a pull-to-refresh.
final globalPointsProvider = StreamProvider<int>((ref) {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return db.pointsBalanceDao.watchBalance(profileId);
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
  return service.getCurriculumBreakdown();
});

/// Points history log, optionally filtered by curriculum.
final pointsHistoryProvider =
    FutureProvider.family<List<PointsHistoryEntry>, CurriculumId?>((
      ref,
      curriculum,
    ) async {
      final service = ref.watch(pointsServiceProvider);
      return service.getPointsHistory(curriculumId: curriculum?.storageKey);
    });
