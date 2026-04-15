import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_status.freezed.dart';

/// Represents the current state of data synchronization with Firestore.
///
/// The sync status follows this lifecycle:
/// 0. `localOnly` - Local-born tier, sync permanently disabled (v2 §4.5)
/// 1. `syncing` - Active sync operation in progress
/// 2. `synced` - All data successfully synchronized
/// 3. `pending` - Online but local changes awaiting push
/// 4. `offline` - Device is offline, changes queued locally
/// 5. `error` - Sync operation failed
@freezed
sealed class SyncStatus with _$SyncStatus {
  /// Local-born tier — sync permanently disabled (v2 §4.5).
  /// Previously "no account"; v2 frames this as an immutable tier.
  const factory SyncStatus.localOnly() = SyncStatusLocalOnly;

  /// Sync operation is currently in progress.
  const factory SyncStatus.syncing({required DateTime startedAt}) =
      SyncStatusSyncing;

  /// All data is successfully synchronized with Firestore.
  const factory SyncStatus.synced({required DateTime lastSyncedAt}) =
      SyncStatusSynced;

  /// Online but local changes are queued and awaiting push.
  const factory SyncStatus.pending({required int pendingChanges}) =
      SyncStatusPending;

  /// Device is offline. Local changes are queued for sync when online.
  const factory SyncStatus.offline({required int pendingChanges}) =
      SyncStatusOffline;

  /// Sync operation failed with an error.
  const factory SyncStatus.error({
    required String message,
    required DateTime failedAt,
  }) = SyncStatusError;
}
