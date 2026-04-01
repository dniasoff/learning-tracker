import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/manual_completion_use_case.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'learning_ledger_providers.g.dart';

/// Fetches the profile mode ('adult' or 'child') for the active profile.
final _activeProfileModeProvider = FutureProvider.autoDispose<String>((
  ref,
) async {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final profile = await database.profileDao.getProfileById(profileId);
  return profile?.mode ?? 'adult';
});

/// Provides the learning ledger repository.
@riverpod
LearningLedgerRepository learningLedgerRepository(Ref ref) {
  final database = ref.watch(userDatabaseProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final profileMode = ref.watch(_activeProfileModeProvider).value ?? 'adult';

  return LearningLedgerRepositoryImpl(
    database: database,
    syncEngine: syncEngine,
    activeProfileId: profileId,
    activeProfileMode: profileMode,
  );
}

/// Provides the manual completion use case.
@riverpod
ManualCompletionUseCase manualCompletionUseCase(Ref ref) {
  final repository = ref.watch(learningLedgerRepositoryProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final profileMode = ref.watch(_activeProfileModeProvider).value ?? 'adult';
  return ManualCompletionUseCase(
    repository: repository,
    activeProfileId: profileId,
    activeProfileMode: profileMode,
  );
}

/// Watches all ledger entries for the active profile.
final learningLedgerProvider =
    FutureProvider.autoDispose<List<LearningLedgerData>>((ref) async {
      final database = ref.watch(userDatabaseProvider);
      final profileId = ref.watch(activeProfileIdProvider);
      return database.learningLedgerDao.getEntriesByProfile(profileId);
    });

/// Watches ledger entries filtered by curriculum for the active profile.
final curriculumLedgerProvider = FutureProvider.autoDispose
    .family<List<LearningLedgerData>, String>((ref, curriculumId) async {
      final database = ref.watch(userDatabaseProvider);
      final profileId = ref.watch(activeProfileIdProvider);
      return database.learningLedgerDao.getEntriesByCurriculum(
        profileId,
        curriculumId,
      );
    });

/// Computed completion stats for a curriculum.
final completionStatsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, curriculumId) async {
      final repository = ref.watch(learningLedgerRepositoryProvider);
      final profileId = ref.watch(activeProfileIdProvider);
      return repository.getCompletionStats(profileId, curriculumId);
    });
