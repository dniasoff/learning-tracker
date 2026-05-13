import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:learning_tracker/features/sync/domain/services/device_restore_service.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Provider for DeviceRestoreService.
///
/// Returns null when user has no cloud account (restore requires Firestore).
final deviceRestoreServiceProvider = Provider<DeviceRestoreService?>((ref) {
  final syncEngine = ref.watch(syncEngineProvider);
  final firestoreDataSource = ref.watch(firestoreDataSourceProvider);
  if (syncEngine == null || firestoreDataSource == null) return null;

  final database = ref.watch(userDatabaseProvider);
  final curriculumImportService = ref.watch(curriculumImportServiceProvider);
  final logger = ref.watch(appLoggerProvider);

  final analytics = ref.watch(analyticsServiceProvider);

  final service = DeviceRestoreService(
    database: database,
    syncEngine: syncEngine,
    firestoreDataSource: firestoreDataSource,
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
