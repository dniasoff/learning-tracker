import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';

/// Widget that ensures [SyncOrchestratorImpl] is alive for the widget subtree.
///
/// [SyncOrchestratorImpl] owns its own [LifecycleObserver] (started inside
/// [SyncOrchestratorImpl.start]) and [ListenerSupervisor], so no manual
/// lifecycle wiring is needed here.  This widget simply reads the orchestrator
/// provider so the singleton is created and kept alive.
///
/// W2.35: the legacy [SyncEngine] connectivity subscription, setOnlineState,
/// attachListeners and detachListeners calls were removed — the orchestrator
/// handles all of that internally.
class SyncLifecycleObserver extends ConsumerStatefulWidget {
  const SyncLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleObserver> createState() =>
      _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver> {
  @override
  Widget build(BuildContext context) {
    // Ensure the orchestrator singleton is created and kept alive.
    ref.watch(syncOrchestratorProvider);
    return widget.child;
  }
}
