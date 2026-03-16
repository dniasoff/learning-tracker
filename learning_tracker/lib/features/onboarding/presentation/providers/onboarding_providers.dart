import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
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
