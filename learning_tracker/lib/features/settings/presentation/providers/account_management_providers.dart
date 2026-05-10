import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/settings/domain/services/account_management_service.dart';

/// Provider for AccountManagementService
final accountManagementServiceProvider = Provider<AccountManagementService>((
  ref,
) {
  return AccountManagementService(
    authRepository: ref.watch(authRepositoryProvider),
    database: ref.watch(userDatabaseProvider),
  );
});
