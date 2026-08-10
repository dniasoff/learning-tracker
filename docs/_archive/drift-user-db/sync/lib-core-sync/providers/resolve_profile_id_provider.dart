import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

/// Returns a stable resolver that reads the current active profile id on demand.
///
/// Consumed by [syncOrchestratorProvider] so the SyncOrchestrator can query
/// the active profile at each pull/dispatch without creating a watch-dependency
/// on [activeProfileIdProvider]. A watch-dependency would cause the provider to
/// rebuild on every profile switch, registering a second LifecycleObserver
/// before the first is disposed (Bug #1 / R1).
final resolveProfileIdProvider = Provider<int Function()>((ref) {
  return () => ref.read(activeProfileIdProvider);
});
