import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

/// Provider for FirestoreDataSource.
final firestoreDataSourceProvider = Provider<FirestoreDataSource>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);

  return FirestoreDataSource(firestore: firestore, auth: auth);
});

/// Provider for OfflineQueue.
final offlineQueueProvider = Provider<OfflineQueue>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final firestoreDataSource = ref.watch(firestoreDataSourceProvider);
  final logger = ref.watch(talkerProvider);

  return OfflineQueue(
    database: database,
    firestoreDataSource: firestoreDataSource,
    logger: logger,
  );
});

/// Provider for SyncEngine.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final firestoreDataSource = ref.watch(firestoreDataSourceProvider);
  final offlineQueue = ref.watch(offlineQueueProvider);
  final logger = ref.watch(talkerProvider);

  final engine = SyncEngine(
    database: database,
    firestoreDataSource: firestoreDataSource,
    offlineQueue: offlineQueue,
    logger: logger,
  );

  // Initialize on creation; surface errors onto the status stream.
  engine.initialize().catchError((Object error, StackTrace stackTrace) {
    // initialize() updates the status stream with an error status on failure,
    // but catchError is needed here so an unhandled async error doesn't crash
    // the isolate when the Future is fire-and-forget.
  });

  // Dispose when provider is disposed
  ref.onDispose(() {
    engine.dispose();
  });

  return engine;
});

/// Provider for sync status stream.
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.statusStream;
});

/// Provider for current sync status (from stream).
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final asyncStatus = ref.watch(syncStatusStreamProvider);
  return asyncStatus.when(
    data: (status) => status,
    loading: () => SyncStatus.syncing(startedAt: DateTime.now()),
    error: (error, _) =>
        SyncStatus.error(message: error.toString(), failedAt: DateTime.now()),
  );
});
