import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Widget that observes app lifecycle and manages sync listeners.
///
/// Attaches Firestore listeners when app is in foreground (resumed).
/// Detaches listeners when app goes to background (paused) to save battery.
class SyncLifecycleObserver extends ConsumerStatefulWidget {
  const SyncLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleObserver> createState() =>
      _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Attach listeners on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = ref.read(syncEngineProvider);
      engine.attachListeners();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final engine = ref.read(syncEngineProvider);

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground, attach listeners
        engine.attachListeners();
        break;

      case AppLifecycleState.inactive:
        // On iOS, inactive fires for transient states (notification shade,
        // alerts). Do not detach listeners here.
        break;

      case AppLifecycleState.paused:
        // App going to background, detach listeners
        engine.detachListeners();
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is being killed or hidden, ensure cleanup
        engine.detachListeners();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
