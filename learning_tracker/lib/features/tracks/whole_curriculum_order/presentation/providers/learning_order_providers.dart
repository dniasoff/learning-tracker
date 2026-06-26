import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/repositories/learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/use_cases/save_learning_order_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The current seed/content version from [SeedMetadata] (§10.1 version guard).
///
/// Reads the `version` field from the content DB's single SeedMetadata row.
/// Defaults to 1 when no metadata row is found (test / first-install paths).
final contentVersionProvider = FutureProvider<int>((ref) async {
  final contentDb = await ref.watch(contentDatabaseProvider.future);
  final meta = await contentDb.seedMetadataDao.getVersion();
  return meta?.version ?? 1;
});

/// Provides the LearningOrderRepository (stateless — curriculum passed per call).
final learningOrderRepositoryProvider = Provider<LearningOrderRepository>((
  ref,
) {
  final database = ref.watch(userDatabaseProvider);
  final contentRepository = ref.watch(contentRepositoryProvider);
  final syncFacade = ref.watch(syncWriteFacadeProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  // §10.1: pass the current content version for the version-mismatch guard.
  // Use 1 as a safe synchronous default; the FutureProvider resolves shortly
  // after startup but the repository is accessed from async call sites so the
  // version will be current in practice.
  final contentVersion = ref
      .watch(contentVersionProvider)
      .maybeWhen(data: (v) => v, orElse: () => 1);
  return LearningOrderRepositoryImpl(
    database: database,
    contentRepository: contentRepository,
    syncEngine: syncFacade,
    profileId: profileId,
    currentContentVersion: contentVersion,
  );
});

/// Provides the [SaveLearningOrderUseCase] wired to the repository.
final saveLearningOrderUseCaseProvider = Provider<SaveLearningOrderUseCase>((
  ref,
) {
  final repository = ref.watch(learningOrderRepositoryProvider);
  return SaveLearningOrderUseCase(repository: repository);
});

/// Provides the ordered list of drag-level items for a curriculum.
///
/// Family provider keyed by CurriculumId per P3.
final learningOrderProvider =
    FutureProvider.family<List<LearningOrderItem>, CurriculumId>((
      ref,
      curriculumId,
    ) async {
      final repository = ref.watch(learningOrderRepositoryProvider);
      return repository.getOrder(curriculumId);
    });

/// Provides whether parent controls ordering (permission setting).
final parentControlsOrderingProvider = FutureProvider<bool>((ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  final prefs = await SharedPreferences.getInstance();
  return ProfileScopedPreferenceKeys.readLearningOrderParentControls(
    prefs,
    profileId,
  );
});

/// Provides the active profile's [ProfileMode] from the [LearnerProfiles] table.
///
/// WS9.enum: unified — formerly read [UserMode] from the vestigial
/// [accounts.userMode] column; now reads [ProfileMode] from the canonical
/// [learner_profiles.mode] column via [activeProfileIdProvider].
final userModeProvider = FutureProvider<ProfileMode>((ref) async {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final profile = await database.profileDao.getProfileById(profileId);
  if (profile == null) return ProfileMode.adult;
  return ProfileMode.fromStorageKey(profile.mode);
});

/// True when ordering is restricted (child mode + parent controls ordering).
final orderingRestrictedProvider = FutureProvider<bool>((ref) async {
  final parentControls = await ref.watch(parentControlsOrderingProvider.future);
  final userMode = await ref.watch(userModeProvider.future);
  return parentControls && userMode.isChild;
});
