import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

/// Provider for sync status stream.
///
/// W2.33: delegates to the orchestrator's own status stream via
/// [syncOrchestratorProvider]. Emits [SyncStatus.localOnly] when no
/// orchestrator is available.
///
/// Canonical source of truth for sync-status is
/// `core/sync/providers/sync_status_providers.dart`.
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
  final orchestrator = ref.watch<SyncOrchestrator?>(syncOrchestratorProvider);
  if (orchestrator == null) {
    return Stream.value(const SyncStatus.localOnly());
  }
  return orchestrator.statusStream;
});

/// Provider for current sync status (from stream).
///
/// W2.33: delegates to the orchestrator's own status via
/// [syncOrchestratorProvider].
///
/// Canonical source of truth for sync-status is
/// `core/sync/providers/sync_status_providers.dart`.
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final orchestrator = ref.watch<SyncOrchestrator?>(syncOrchestratorProvider);
  if (orchestrator == null) return const SyncStatus.localOnly();

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

// W2.31 — outbox-backed SyncWriteFacade provider ────────────────────────────

/// Outbox-backed [SyncWriteFacade] provider.
///
/// Tier-gated: returns `null` for local-born accounts (same rule as the
/// deleted syncEngineProvider). Cloud-born accounts get an
/// [OutboxSyncWriteFacade] that enqueues mutations into the outbox table for
/// async push.
///
/// When a tutor session is active ([activeTutoredProfileSelectionProvider] !=
/// null) the outbox facade is wrapped by a [TutoredWriteRouter] that intercepts
/// entity writes and routes them to the matching TutorWriteService Cloud
/// Function instead. The outbox [isProfileTutored] guard remains as the
/// belt-and-suspenders safety net.
///
/// W2.35: [syncEngineProvider] deleted — this is the sole write-path provider.
final syncWriteFacadeProvider = Provider<SyncWriteFacade?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (!authState.isCloudBorn) return null;

  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final clock = ref.watch(localDayClockProvider);

  final outboxFacade = OutboxSyncWriteFacade(
    outboxDao: database.outboxDao,
    database: database,
    profileId: profileId,
    clock: clock,
    // Phase 1 — write-tee: kick the outbox processor after every enqueue
    // so writes reach Firestore in the same network round as the local
    // commit. Resolved lazily so the processor's rebuild lifetime is
    // independent of the facade.
    onEnqueueDrain: () =>
        ref.read(outboxProcessorProvider)?.drain(profileId) ??
        Future<int>.value(0),
  );

  final tutoredSelection = ref.watch(activeTutoredProfileSelectionProvider);
  if (tutoredSelection == null) return outboxFacade;

  return TutoredWriteRouter(
    delegate: outboxFacade,
    writeService: ref.watch(tutorWriteServiceProvider),
    selection: tutoredSelection,
    gamificationSnapshotBuilder: outboxFacade.buildGamificationSnapshot,
  );
});

/// Cloud-born concrete [OutboxSyncWriteFacade] for repositories/services that
/// need access to outbox-only helpers (`enqueueLedgerEntry`,
/// `enqueueNotificationSettings`, `enqueueProfileProgram`,
/// `enqueueStreakPayload`, `enqueueStudyDayConfig`).
///
/// Returns `null` for local-born accounts so callers can null-guard cleanly,
/// matching the [syncWriteFacadeProvider] tier-gate. The instance and the one
/// returned by [syncWriteFacadeProvider] are NOT shared on purpose: each
/// provider builds its own facade so widening the surface here cannot
/// accidentally retire the `SyncWriteFacade` type on the other consumers.
final outboxSyncWriteFacadeProvider = Provider<OutboxSyncWriteFacade?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (!authState.isCloudBorn) return null;

  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final clock = ref.watch(localDayClockProvider);

  final facade = OutboxSyncWriteFacade(
    outboxDao: database.outboxDao,
    database: database,
    profileId: profileId,
    clock: clock,
    onEnqueueDrain: () =>
        ref.read(outboxProcessorProvider)?.drain(profileId) ??
        Future<int>.value(0),
  );
  // WS9 Wave-B (C#2): register this facade as the points-sync sink so every
  // ledger insert + redemption mutation made via PointsBalanceDao is pushed
  // to the outbox. The DAO lives in core/ and cannot import the facade, so the
  // wiring happens here at the features-layer composition root.
  database.pointsBalanceDao.syncSink = facade;
  return facade;
});
