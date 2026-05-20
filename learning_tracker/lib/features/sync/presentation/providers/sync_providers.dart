import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/network_providers.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

/// Provider for FirestoreDataSource, scoped to the active profile.
///
/// Returns null when the user is not cloud-born (v2 §4.5 tier gate).
/// NOTE: [FirestoreDataSource] is a legacy adapter kept alive while
/// [SyncEngine] still depends on it. New code should use
/// [firestoreGatewayProvider] instead.
final firestoreDataSourceProvider = Provider<FirestoreDataSource?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (!authState.isCloudBorn) return null;

  final gateway = ref.watch(firestoreGatewayProvider);
  if (gateway == null) return null;
  final auth = ref.watch(authRepositoryProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  return FirestoreDataSource(
    gateway: gateway,
    auth: auth,
    profileId: profileId,
  );
});

/// Provider for OfflineQueue.
///
/// Returns null for local-born users — offline queue is a no-op since
/// there's nothing to sync. Only cloud-born users queue writes.
final offlineQueueProvider = Provider<OfflineQueue?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (!authState.isCloudBorn) return null;

  final database = ref.watch(userDatabaseProvider);
  final gateway = ref.watch(firestoreGatewayProvider);
  if (gateway == null) return null;
  final talker = ref.watch(talkerProvider);

  return OfflineQueue(
    database: database,
    firestoreGateway: gateway,
    logger: AppLogger(talker),
  );
});

/// Provider for SyncEngine.
///
/// v2 tier-gated activation (per v2 §4.5):
/// - `tier != cloudBorn` → returns `null` (local-born accounts never
///   instantiate SyncEngine — saves memory and battery)
/// - `tier == cloudBorn` + offline → engine instantiated but dormant
/// - `tier == cloudBorn` + online → full sync active
final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final authState = ref.watch(authStateProvider);

  // Local-born or signed out — never instantiate (v2 §4.5).
  if (!authState.isCloudBorn) return null;

  final database = ref.watch(userDatabaseProvider);
  final firestoreDataSource = ref.watch(firestoreDataSourceProvider);
  if (firestoreDataSource == null) return null;
  final offlineQueue = ref.watch(offlineQueueProvider);
  if (offlineQueue == null) return null;
  final talker = ref.watch(talkerProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);

  final analytics = ref.watch(analyticsServiceProvider);
  final outboxProcessor = ref.watch(outboxProcessorProvider);

  final engine = SyncEngine(
    database: database,
    firestoreDataSource: firestoreDataSource,
    offlineQueue: offlineQueue,
    logger: AppLogger(talker),
    connectivityService: connectivityService,
    analytics: analytics,
    outboxProcessor: outboxProcessor,
  );

  // Initialize; surface errors onto the status stream.
  engine.initialize().catchError((Object error, StackTrace stackTrace) {
    // catchError needed so unhandled async error doesn't crash the isolate.
  });

  ref.onDispose(() {
    engine.dispose();
  });

  return engine;
});

/// Provider for sync status stream.
///
/// Phase 5: the canonical source has moved to
/// `core/sync/providers/sync_status_providers.dart`. This provider is kept
/// in place for backward compatibility; new code should prefer the core
/// provider directly.
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  if (engine == null) {
    return Stream.value(const SyncStatus.localOnly());
  }
  return engine.statusStream;
});

/// Provider for current sync status (from stream).
///
/// Phase 5: the canonical source has moved to
/// `core/sync/providers/sync_status_providers.dart`. This provider is kept
/// in place for backward compatibility; new code should prefer the core
/// provider directly.
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  if (engine == null) return const SyncStatus.localOnly();

  final asyncStatus = ref.watch(syncStatusStreamProvider);
  return asyncStatus.when(
    data: (status) => status,
    loading: () => SyncStatus.syncing(startedAt: DateTimeFactory.nowLocal()),
    error: (error, _) => SyncStatus.error(
      message: error.toString(),
      failedAt: DateTimeFactory.nowLocal(),
    ),
  );
});
