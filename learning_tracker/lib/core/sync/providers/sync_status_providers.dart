import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart'
    show syncEngineProvider;

/// Broadcast stream of [SyncStatus] changes.
///
/// Emits [SyncStatus.localOnly] immediately when no engine is available
/// (i.e. local-born accounts or unauthenticated state). For cloud-born
/// accounts, forwards the engine's status stream.
///
/// Phase 5: canonical source of truth for sync-status in core/sync/. Feature-
/// layer UI can watch this directly; [syncStatusProvider] in sync_providers.dart
/// delegates here.
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  if (engine == null) {
    return Stream.value(const SyncStatus.localOnly());
  }
  return engine.statusStream;
});

/// Current [SyncStatus] derived from [syncStatusStreamProvider].
///
/// Returns [SyncStatus.localOnly] for local-born / unauthenticated users.
/// Returns [SyncStatus.syncing] while the stream is loading.
/// Returns [SyncStatus.error] if the stream itself errors.
///
/// Phase 5: canonical source of truth for sync-status in core/sync/. Feature-
/// layer UI can watch this directly; [syncStatusProvider] in sync_providers.dart
/// delegates here.
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
