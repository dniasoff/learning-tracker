import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_error_code.dart';

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
/// 6. `degraded` - Pushes are queueing silently (e.g. repeated permission
///    denied or listener quota exhaustion). Surfaced to the UI so users see
///    that their writes are stuck instead of assuming everything synced.
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
  ///
  /// EH-5: [code] is a stable, localizable category — never a pre-formatted
  /// human message. Presentation resolves the user-facing string for [code]
  /// through `AppLocalizations`. [debugDetail], when present, is technical
  /// (may contain exception class names, Firestore paths, SDK codes) and
  /// must NEVER be rendered directly to the user — logs/diagnostics only.
  const factory SyncStatus.error({
    required SyncErrorCode code,
    required DateTime failedAt,
    String? debugDetail,
  }) = SyncStatusError;

  /// Pushes are silently queueing because Firestore keeps refusing them
  /// (permission-denied threshold reached) or realtime listeners hit the
  /// connection quota. The queue is intact — work resumes when the
  /// underlying problem clears — but the UI must show the user that their
  /// last few writes have not landed yet.
  const factory SyncStatus.degraded({
    required int pendingChanges,
    required String reason,
  }) = SyncStatusDegraded;
}
