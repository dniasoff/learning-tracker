import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_error_code.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';

// W2.33: sync_status_providers now reads from syncOrchestratorProvider instead
// of syncEngineProvider. SyncOrchestratorImpl owns its own StreamController
// (statusStream / currentStatus) so SyncEngine is no longer in the status path.

/// Broadcast stream of [SyncStatus] changes.
///
/// W2.33: forwards the [SyncOrchestrator]'s own status stream rather than
/// the legacy [SyncEngine] stream. Emits [SyncStatus.localOnly] when no
/// orchestrator is available (local-born / unauthenticated).
///
/// Canonical source of truth for sync-status in core/sync/. Feature-layer
/// UI can watch this directly; [syncStatusProvider] in sync_providers.dart
/// also delegates here.
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
  final orchestrator = ref.watch<SyncOrchestrator?>(syncOrchestratorProvider);
  if (orchestrator == null) {
    return Stream.value(const SyncStatus.localOnly());
  }
  return orchestrator.statusStream;
});

/// Current [SyncStatus] derived from [syncStatusStreamProvider].
///
/// Returns [SyncStatus.localOnly] for local-born / unauthenticated users.
/// Returns [SyncStatus.syncing] while the stream is loading.
/// Returns [SyncStatus.error] if the stream itself errors.
///
/// Canonical source of truth for sync-status in core/sync/. Feature-layer
/// UI can watch this directly; [syncStatusProvider] in sync_providers.dart
/// also delegates here.
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final orchestrator = ref.watch<SyncOrchestrator?>(syncOrchestratorProvider);
  if (orchestrator == null) return const SyncStatus.localOnly();

  final asyncStatus = ref.watch(syncStatusStreamProvider);
  return asyncStatus.when(
    data: (status) => status,
    // Late subscribers (e.g. the Backup & Sync card mounted after pullOnLaunch
    // already settled) attach to a broadcast stream that has no pending
    // events. Returning a fresh `syncing` here would wedge the card on
    // "Syncing…" forever. The orchestrator's [currentStatus] is the
    // authoritative snapshot between events.
    loading: () => orchestrator.currentStatus,
    // AUD-sync-01 (EH-5): the stream itself errored (not a classified
    // domain exception) — code is unknown; error.toString() is retained
    // only as non-user-facing debugDetail.
    error: (error, _) => SyncStatus.error(
      code: SyncErrorCode.unknown,
      failedAt: DateTimeFactory.nowLocal(),
      debugDetail: error.toString(),
    ),
  );
});
