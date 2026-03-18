import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

/// Provider for the PointsService, scoped to active profile.
final pointsServiceProvider = Provider<PointsService>((ref) {
  final database = ref.watch(appDatabaseProvider);
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

/// Global points total across all curricula.
final globalPointsProvider = FutureProvider<int>((ref) async {
  final service = ref.watch(pointsServiceProvider);
  return service.getGlobalTotal();
});

/// Per-curriculum breakdown map.
final curriculumBreakdownProvider = FutureProvider<Map<CurriculumId, int>>((
  ref,
) async {
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
