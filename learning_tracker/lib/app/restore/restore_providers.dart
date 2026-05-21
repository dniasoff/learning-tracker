import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/restore/device_restore_service.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart'
    show firestoreGatewayProvider;
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';

/// Provider for DeviceRestoreService.
///
/// Returns null when user has no cloud account (restore requires Firestore).
final deviceRestoreServiceProvider = Provider<DeviceRestoreService?>((ref) {
  final syncOrchestrator = ref.watch(syncOrchestratorProvider);
  // `firestoreGatewayProvider` is observed only as a gating signal — the
  // restore service no longer issues raw Firestore reads (post-pull active
  // curricula are derived from Drift). Restore still requires a cloud
  // account, so a null gateway means there's nothing to restore.
  final gateway = ref.watch(firestoreGatewayProvider);
  if (syncOrchestrator == null || gateway == null) return null;

  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final authState = ref.watch(authStateProvider);
  final curriculumImportService = ref.watch(curriculumImportServiceProvider);
  final logger = ref.watch(appLoggerProvider);
  final analytics = ref.watch(analyticsServiceProvider);

  final service = DeviceRestoreService(
    database: database,
    syncOrchestrator: syncOrchestrator,
    profileId: profileId,
    isAuthenticated: authState.isCloudBorn,
    curriculumImportService: curriculumImportService,
    logger: logger,
    analytics: analytics,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider for restore status stream.
final restoreStatusStreamProvider = StreamProvider<RestoreStatus>((ref) {
  final service = ref.watch(deviceRestoreServiceProvider);
  if (service == null) return Stream.value(const RestoreStatus.idle());
  return service.statusStream;
});

/// Provider for current restore status.
final restoreStatusProvider = Provider<RestoreStatus>((ref) {
  final asyncStatus = ref.watch(restoreStatusStreamProvider);
  return asyncStatus.when(
    data: (status) => status,
    loading: () => const RestoreStatus.idle(),
    error: (error, _) => RestoreStatus.error(message: error.toString()),
  );
});

/// Emits a tick whenever a successful restore finishes. Surfaces (e.g. the
/// dashboard, profile picker, track hub) listen for this so they can
/// `ref.invalidate` cached providers that may have rendered the empty-DB
/// snapshot taken before pull-on-launch finished merging.
final restoreCompletedStreamProvider = StreamProvider<void>((ref) {
  final service = ref.watch(deviceRestoreServiceProvider);
  if (service == null) return const Stream.empty();
  return service.restoreCompletedStream;
});
