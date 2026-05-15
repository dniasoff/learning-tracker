import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/providers/merge_router_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Provider for [SyncOrchestrator].
///
/// Returns null when the user is not cloud-born — matches the tier-gate used
/// by [syncEngineProvider]. Callers treat null as "sync not available" (same
/// semantics as a null [SyncEngine]).
///
/// DNI-334 AC4 + DNI-335 AC6: [PullPipeline] is wired with [MergeRouter] as
/// its [MergeDispatcher]; [ListenerSupervisor] and [LifecycleObserver] are
/// initialized inside [SyncOrchestratorImpl] on construction and disposed via
/// [ref.onDispose].
final syncOrchestratorProvider = Provider<SyncOrchestrator?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (!authState.isCloudBorn) return null;

  final engine = ref.watch(syncEngineProvider);
  if (engine == null) return null;

  final gateway = ref.watch(firestoreGatewayProvider);
  if (gateway == null) return null;

  final mergeRouter = ref.watch(mergeRouterProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final talker = ref.watch(talkerProvider);

  final pullPipeline = PullPipeline(
    gateway: gateway,
    dispatcher: mergeRouter,
  );

  final orchestrator = SyncOrchestratorImpl(
    engine: engine,
    pullPipeline: pullPipeline,
    mergeRouter: mergeRouter,
    gateway: gateway,
    profileId: profileId,
    logger: AppLogger(talker),
  );

  ref.onDispose(orchestrator.dispose);

  return orchestrator;
});
