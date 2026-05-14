import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Provider for [SyncOrchestrator].
///
/// Returns null when the user is not cloud-born — matches the tier-gate used
/// by [syncEngineProvider]. Callers treat null as "sync not available" (same
/// semantics as a null [SyncEngine]).
///
/// Phase 3: delegates internally to [SyncEngine]. Once the full merge
/// decomposition is complete, the provider will wire [PullPipeline] and
/// [MergeRouter] directly and the dependency on [syncEngineProvider] will be
/// removed.
final syncOrchestratorProvider = Provider<SyncOrchestrator?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (!authState.isCloudBorn) return null;

  final engine = ref.watch(syncEngineProvider);
  if (engine == null) return null;

  return SyncOrchestratorImpl(engine: engine);
});
