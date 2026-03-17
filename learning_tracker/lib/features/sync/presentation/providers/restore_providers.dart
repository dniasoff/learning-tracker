import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:learning_tracker/features/sync/domain/services/device_restore_service.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Provider for DeviceRestoreService.
final deviceRestoreServiceProvider = Provider<DeviceRestoreService>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  final firestoreDataSource = ref.watch(firestoreDataSourceProvider);
  final curriculumImportService = ref.watch(curriculumImportServiceProvider);
  final logger = ref.watch(talkerProvider);

  final service = DeviceRestoreService(
    database: database,
    syncEngine: syncEngine,
    firestoreDataSource: firestoreDataSource,
    curriculumImportService: curriculumImportService,
    logger: logger,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider for restore status stream.
final restoreStatusStreamProvider = StreamProvider<RestoreStatus>((ref) {
  final service = ref.watch(deviceRestoreServiceProvider);
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
