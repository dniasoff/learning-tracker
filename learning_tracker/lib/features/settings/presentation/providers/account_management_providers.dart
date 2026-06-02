import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/domain/services/account_management_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart'
    show flutterSecureStorageProvider;

/// Provider for AccountManagementService
final accountManagementServiceProvider = Provider<AccountManagementService>((
  ref,
) {
  return AccountManagementService(
    authRepository: ref.watch(authRepositoryProvider),
    database: ref.watch(userDatabaseProvider),
    // Inject the shared secure-storage handle so account deletion wipes the
    // device-scoped PIN store (parent/profile/tutor PIN hashes + lockout) —
    // these survive a SharedPreferences clear and must not leak into the next
    // sign-up (Bug 6).
    secureStorage: ref.watch(flutterSecureStorageProvider),
  );
});
