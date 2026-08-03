import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/repositories/learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/use_cases/save_learning_order_use_case.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's learning-order repository — Firestore-backed via
/// [FirestoreLearningOrderRepositoryAdapter] (F2 fix). Construction stays
/// synchronous: the adapter holds a [Ref] and resolves
/// `firestoreLearningOrderRepositoryProvider` per method call, so this stays
/// a plain [Provider] for its existing watchers (`learningOrderProvider`,
/// `saveLearningOrderUseCaseProvider`, `learning_order_screen.dart`'s direct
/// read for `resetToDefault`).
///
/// Previously resolved to the Drift-backed [LearningOrderRepositoryImpl],
/// whose writes landed on a document tree
/// `FirestoreBookmarkRepositoryAdapter`'s bookmark-advance read
/// (`FirestoreLearningOrderRepository.getCustomOrderRefs`) never looked at —
/// see [FirestoreLearningOrderRepositoryAdapter]'s class doc comment for the
/// full defect this rewire fixes.
final learningOrderRepositoryProvider = Provider<LearningOrderRepository>((
  ref,
) {
  return FirestoreLearningOrderRepositoryAdapter(ref: ref);
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
///
/// AUD-tracks-15 (SM-8): LearningOrderRepositoryImpl no longer depends on
/// ContentRepository — it only talks to its own DAO. The content-fetch step
/// lives here instead: resolve the curriculum's content list via
/// ContentRepository, then pass it into the repository call.
final learningOrderProvider =
    FutureProvider.family<List<LearningOrderItem>, CurriculumId>((
      ref,
      curriculumId,
    ) async {
      final allItems = await ref
          .watch(contentRepositoryProvider)
          .getContentForCurriculum(curriculumId);
      final repository = ref.watch(learningOrderRepositoryProvider);
      return repository.getOrder(curriculumId, allItems);
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
