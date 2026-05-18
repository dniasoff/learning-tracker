import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/providers/merge_router_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/sync/providers/resolve_profile_id_provider.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Provider for [SyncOrchestrator].
///
/// Returns null when the user is not cloud-born — matches the tier-gate used
/// by [syncEngineProvider]. Callers treat null as "sync not available" (same
/// semantics as a null [SyncEngine]).
///
/// DNI-334 AC4 + DNI-335 AC6: [PullPipeline] is wired with [MergeRouter] as
/// its [MergeDispatcher]; [ListenerSupervisor] and [LifecycleObserver] are
/// started inside [SyncOrchestratorImpl.start] and disposed via
/// [ref.onDispose].
///
/// S7 (singleton invariant): this provider is a `keepAlive` singleton — at
/// most one [SyncOrchestrator] exists per app session.
///
///   * It does NOT watch [syncEngineProvider] / [firestoreGatewayProvider] /
///     [mergeRouterProvider] etc. Invalidating any of those — as the sign-in
///     and upgrade-to-cloud flows used to do — must NOT tear down and rebuild
///     the orchestrator, since a rebuild transiently produced duplicate
///     [LifecycleObserver]s and listener sets (Bug #1, quality crisis
///     2026-05-17). Those build-time dependencies are read once via
///     [ref.read].
///   * It still watches [authStateProvider] — but only to gate on the
///     cloud-born tier. That is a genuine once-per-session transition
///     (sign-in / sign-out / upgrade), not the volatile invalidation churn
///     the singleton guarantee protects against.
///   * R1 fix: it does NOT watch the active-profile provider directly. The
///     active profile is resolved lazily via [resolveProfileIdProvider].
///
/// The [SyncEngine] is handed to the orchestrator as a lazy resolver so a
/// later engine rebuild (e.g. after a DB swap) is picked up without recreating
/// the orchestrator.
final syncOrchestratorProvider = Provider<SyncOrchestrator?>((ref) {
  // keepAlive: the orchestrator owns a WidgetsBinding observer and a set of
  // Firestore listeners — it must survive transient unmounts of any widget
  // that reads it, and there must be exactly one per session (S7).
  ref.keepAlive();

  // Tier gate only. Reads (not watches) the volatile build-time dependencies
  // below so that invalidating them does not rebuild the orchestrator.
  final authState = ref.watch(authStateProvider);
  if (!authState.isCloudBorn) return null;

  final engine = ref.read(syncEngineProvider);
  if (engine == null) return null;

  final gateway = ref.read(firestoreGatewayProvider);
  if (gateway == null) return null;

  final mergeRouter = ref.read(mergeRouterProvider);
  final resolveProfileId = ref.read(resolveProfileIdProvider);
  final talker = ref.read(talkerProvider);

  final pullPipeline = PullPipeline(gateway: gateway, dispatcher: mergeRouter);

  final orchestrator = SyncOrchestratorImpl(
    // Resolve the engine lazily — a DB swap rebuilds syncEngineProvider, and
    // the orchestrator must delegate to the current engine, not a stale one.
    resolveEngine: () => ref.read(syncEngineProvider)!,
    pullPipeline: pullPipeline,
    mergeRouter: mergeRouter,
    gateway: gateway,
    resolveProfileId: resolveProfileId,
    logger: AppLogger(talker),
  );

  // Idempotent: registers the lifecycle observer + Firestore listeners once.
  orchestrator.start();

  ref.onDispose(orchestrator.dispose);

  return orchestrator;
});
