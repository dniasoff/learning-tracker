import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_status.freezed.dart';

/// Represents the current state of data synchronization with Firestore.
///
/// The sync status follows this lifecycle:
/// 1. `syncing` - Active sync operation in progress
/// 2. `synced` - All data successfully synchronized
/// 3. `offline` - Device is offline, changes queued locally
/// 4. `error` - Sync operation failed
@freezed
class SyncStatus with _$SyncStatus {
  /// Sync operation is currently in progress.
  const factory SyncStatus.syncing({
    required DateTime startedAt,
  }) = _Syncing;

  /// All data is successfully synchronized with Firestore.
  const factory SyncStatus.synced({
    required DateTime lastSyncedAt,
  }) = _Synced;

  /// Device is offline. Local changes are queued for sync when online.
  const factory SyncStatus.offline({
    required int pendingChanges,
  }) = _Offline;

  /// Sync operation failed with an error.
  const factory SyncStatus.error({
    required String message,
    required DateTime failedAt,
  }) = _Error;
}
