import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/curriculum_import_service.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_providers.g.dart';

@Riverpod(keepAlive: true)
UserProfileService userProfileService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return UserProfileService(
    userProfileDao: db.userProfileDao,
    pushUserProfile: createFirestorePush(firestore),
  );
}

/// Provider for CurriculumImportService used during onboarding.
final curriculumImportServiceProvider = Provider<CurriculumImportService>((
  ref,
) {
  final contentRepo = ref.watch(contentRepositoryProvider);
  final activationService = ref.watch(curriculumActivationServiceProvider);
  return CurriculumImportService(
    contentRepository: contentRepo,
    activationService: activationService,
  );
});

/// Provides hierarchy configs for all 5 curricula (for the selection screen).
final allCurriculaConfigsProvider =
    FutureProvider<Map<CurriculumId, CurriculumHierarchyConfig>>((ref) async {
      final repo = ref.watch(contentRepositoryProvider);
      final configs = <CurriculumId, CurriculumHierarchyConfig>{};
      for (final id in CurriculumId.values) {
        configs[id] = await repo.getHierarchyConfig(id);
      }
      return configs;
    });
