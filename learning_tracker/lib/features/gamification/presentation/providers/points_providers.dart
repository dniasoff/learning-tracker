import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/gamification/domain/services/points_service.dart';

/// Provider for the PointsService singleton.
final pointsServiceProvider = Provider<PointsService>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return PointsService(database);
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
