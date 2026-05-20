import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/repositories/learning_order_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/domain/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides the LearningOrderRepository (stateless — curriculum passed per call).
final learningOrderRepositoryProvider = Provider<LearningOrderRepository>((
  ref,
) {
  final database = ref.watch(userDatabaseProvider);
  final contentRepository = ref.watch(contentRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return LearningOrderRepositoryImpl(
    database: database,
    contentRepository: contentRepository,
    syncEngine: syncEngine,
  );
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
