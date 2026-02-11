import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:learning_tracker/features/progress/domain/repositories/progress_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'progress_providers.g.dart';

/// Provider for the progress repository instance.
@riverpod
ProgressRepository progressRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  return ProgressRepositoryImpl(database: database);
}

/// Provider for track breakdown by curriculum.
///
/// Returns a map of TrackType to completion counts for the given curriculum.
@riverpod
Future<Map<TrackType, int>> trackBreakdown(Ref ref, String curriculumId) async {
  final repository = ref.watch(progressRepositoryProvider);
  return await repository.getTrackBreakdown(curriculumId);
}

/// Provider for aggregate completion count by curriculum.
///
/// Returns the total completion count across all tracks for the given curriculum.
@riverpod
Future<int> aggregateCount(Ref ref, String curriculumId) async {
  final repository = ref.watch(progressRepositoryProvider);
  return await repository.getAggregateCount(curriculumId);
}
