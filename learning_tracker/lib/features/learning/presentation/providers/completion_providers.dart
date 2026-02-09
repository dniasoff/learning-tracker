import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/learning/data/repositories/completion_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/bulk_mark_completion_use_case.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/mark_completion_use_case.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/core/database/database_provider.dart';

part 'completion_providers.g.dart';

/// Provides the completion repository.
@riverpod
CompletionRepository completionRepository(CompletionRepositoryRef ref) {
  final database = ref.watch(databaseProvider);
  final syncEngine = ref.watch(syncEngineProvider);

  return CompletionRepositoryImpl(
    database: database,
    syncEngine: syncEngine,
  );
}

/// Provides the mark completion use case.
@riverpod
MarkCompletionUseCase markCompletionUseCase(MarkCompletionUseCaseRef ref) {
  final repository = ref.watch(completionRepositoryProvider);
  return MarkCompletionUseCase(repository);
}

/// Provides the bulk mark completion use case.
@riverpod
BulkMarkCompletionUseCase bulkMarkCompletionUseCase(
  BulkMarkCompletionUseCaseRef ref,
) {
  final repository = ref.watch(completionRepositoryProvider);
  return BulkMarkCompletionUseCase(repository);
}
