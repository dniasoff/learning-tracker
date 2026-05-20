import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
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
  final contentDb = ref.watch(contentDatabaseProvider);
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

/// Provides the current user's UserMode from the database.
final userModeProvider = FutureProvider<UserMode>((ref) async {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) return UserMode.adult;

  final database = ref.watch(userDatabaseProvider);
  final profile = await database.userProfileDao.getUserProfileByFirebaseUid(
    uid,
  );
  if (profile == null) return UserMode.adult;

  return UserMode.values.firstWhere(
    (m) => m.name == profile.userMode,
    orElse: () => UserMode.adult,
  );
});

/// True when ordering is restricted (child mode + parent controls ordering).
final orderingRestrictedProvider = FutureProvider<bool>((ref) async {
  final parentControls = await ref.watch(parentControlsOrderingProvider.future);
  final userMode = await ref.watch(userModeProvider.future);
  return parentControls && userMode == UserMode.child;
});
