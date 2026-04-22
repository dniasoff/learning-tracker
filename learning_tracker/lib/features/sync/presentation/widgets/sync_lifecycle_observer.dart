import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/auth/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Widget that observes app lifecycle and manages sync listeners.
///
/// Attaches Firestore listeners when app is in foreground (resumed).
/// Detaches listeners when app goes to background (paused) to save battery.
/// Becomes a no-op when SyncEngine is null (local-only mode).
class SyncLifecycleObserver extends ConsumerStatefulWidget {
  const SyncLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleObserver> createState() =>
      _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  ProviderSubscription<AsyncValue<bool>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _connectivitySubscription = ref.listenManual<AsyncValue<bool>>(
      connectivityStreamProvider,
      (previous, next) {
        next.whenData((online) {
          ref.read(syncEngineProvider)?.setOnlineState(online);
        });
      },
      fireImmediately: true,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncEngineProvider)?.attachListeners();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final engine = ref.read(syncEngineProvider);
    if (engine == null) return; // Local-only mode — no-op

    switch (state) {
      case AppLifecycleState.resumed:
        engine.attachListeners();
        engine.pullOnLaunch();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        engine.detachListeners();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
