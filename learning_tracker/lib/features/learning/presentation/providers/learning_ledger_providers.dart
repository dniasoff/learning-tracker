import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/manual_completion_use_case.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'learning_ledger_providers.g.dart';

/// Fetches the [ProfileMode] for the active profile.
///
/// Uses [ProfileMode.fromStorageKey] to convert the raw storage key to a typed
/// enum. Falls back to [ProfileMode.adult] for unrecognised values.
final _activeProfileModeProvider = FutureProvider.autoDispose<ProfileMode>((
  ref,
) async {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final profile = await database.profileDao.getProfileById(profileId);
  if (profile == null) return ProfileMode.adult;
  return ProfileMode.fromStorageKey(profile.mode);
});

/// Provides the learning ledger repository.
@riverpod
LearningLedgerRepository learningLedgerRepository(Ref ref) {
  final database = ref.watch(userDatabaseProvider);
  final outboxFacade = ref.watch(outboxSyncWriteFacadeProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final profileMode =
      ref.watch(_activeProfileModeProvider).value ?? ProfileMode.adult;
  final pinSessionProfileId = ref.watch(
    parentPinAuthenticatedProfileIdProvider,
  );
  final parentPinSessionMatches =
      pinSessionProfileId != null && pinSessionProfileId == profileId;

  return LearningLedgerRepositoryImpl(
    database: database,
    // Phase 1 — bypass cleanup: route ledger pushes through the outbox so
    // offline writes are retained and pushed by the next drain.
    outboxFacade: outboxFacade,
    activeProfileId: profileId,
    activeProfileMode: profileMode,
    parentPinSessionMatchesActiveProfile: parentPinSessionMatches,
  );
}

/// Provides the manual completion use case.
@riverpod
ManualCompletionUseCase manualCompletionUseCase(Ref ref) {
  final repository = ref.watch(learningLedgerRepositoryProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final profileMode =
      ref.watch(_activeProfileModeProvider).value ?? ProfileMode.adult;
  final pinSessionProfileId = ref.watch(
    parentPinAuthenticatedProfileIdProvider,
  );
  final parentPinSessionMatches =
      pinSessionProfileId != null && pinSessionProfileId == profileId;
  return ManualCompletionUseCase(
    repository: repository,
    activeProfileId: profileId,
    activeProfileMode: profileMode,
    parentPinSessionMatchesActiveProfile: parentPinSessionMatches,
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
