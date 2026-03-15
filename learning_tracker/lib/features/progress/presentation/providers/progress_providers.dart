import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/app_database.dart';
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
  return repository.getTrackBreakdown(curriculumId);
}

/// Provider for aggregate completion count by curriculum.
///
/// Returns the total completion count across all tracks for the given curriculum.
@riverpod
Future<int> aggregateCount(Ref ref, String curriculumId) async {
  final repository = ref.watch(progressRepositoryProvider);
  return repository.getAggregateCount(curriculumId);
}

/// Provider that fetches completions for a single curriculum via
/// [ProgressRepository].
///
/// Using [ProgressRepository] (not [CompletionRepository]) keeps the history
/// screen decoupled from write-side concerns (sync engine, content repository)
/// and makes widget testing simpler — only [appDatabaseProvider] needs to be
/// overridden. Watching this provider keeps the screen reactive; invalidating
/// it causes the UI to rebuild with fresh data.
final completionHistoryForCurriculumProvider = FutureProvider.autoDispose
    .family<List<Completion>, String>((ref, curriculumId) async {
      final repository = ref.watch(progressRepositoryProvider);
      return repository.getCompletionsByCurriculum(curriculumId);
    });

/// Provider that fetches completions across all curricula.
///
/// Used when no curriculumId filter is applied.
final allCompletionHistoryProvider =
    FutureProvider.autoDispose<List<Completion>>((ref) async {
      final repository = ref.watch(progressRepositoryProvider);
      return repository.getAllCompletions();
    });
