import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/bulk_mark_completion_use_case.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/mark_completion_use_case.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'completion_providers.g.dart';

/// Provides the completion repository.
@riverpod
CompletionRepository completionRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  final contentRepository = ref.watch(contentRepositoryProvider);

  final bookmarkRepository = ref.watch(bookmarkRepositoryProvider);

  return CompletionRepositoryImpl(
    database: database,
    syncEngine: syncEngine,
    contentRepository: contentRepository,
    bookmarkRepository: bookmarkRepository,
  );
}

/// Provides the mark completion use case.
@riverpod
MarkCompletionUseCase markCompletionUseCase(Ref ref) {
  final repository = ref.watch(completionRepositoryProvider);
  return MarkCompletionUseCase(repository);
}

/// Provides the bulk mark completion use case.
@riverpod
BulkMarkCompletionUseCase bulkMarkCompletionUseCase(Ref ref) {
  final repository = ref.watch(completionRepositoryProvider);
  return BulkMarkCompletionUseCase(repository);
}

/// Provides the number of completions for a specific content item.
///
/// Used by [ContentItemTile] to show per-item completion indicators.
@riverpod
Future<int> completionCount(
  Ref ref, {
  required String curriculumId,
  required String sefariaRef,
}) async {
  final database = ref.watch(appDatabaseProvider);
  final completions = await database.completionDao.getCompletionsForContent(
    sefariaRef,
  );
  return completions
      .where((c) => c.curriculumId == curriculumId)
      .length;
}
