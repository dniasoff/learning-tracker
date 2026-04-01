import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:learning_tracker/features/sync/presentation/providers/restore_providers.dart';

@RoutePage()
class DeviceRestoreScreen extends ConsumerStatefulWidget {
  const DeviceRestoreScreen({super.key});

  @override
  ConsumerState<DeviceRestoreScreen> createState() =>
      _DeviceRestoreScreenState();
}

class _DeviceRestoreScreenState extends ConsumerState<DeviceRestoreScreen> {
  @override
  void initState() {
    super.initState();
    _startRestore();
  }

  Future<void> _startRestore() async {
    final service = ref.read(deviceRestoreServiceProvider);
    if (service == null) return; // Local-only — no restore possible
    final success = await service.restore();
    if (mounted && success) {
      _navigateToApp();
    }
  }

  Future<void> _retry() async {
    final service = ref.read(deviceRestoreServiceProvider);
    if (service == null) return;
    final success = await service.retry();
    if (mounted && success) {
      _navigateToApp();
    }
  }

  void _navigateToApp() {
    final router = ref.read(routerProvider);
    router.restoreGuard.markRestoreComplete();
    context.router.replaceAll([const AppShellRoute()]);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(restoreStatusProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: status.when(
            idle: () => const SizedBox.shrink(),
            checking: () => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text('Checking device...'),
              ],
            ),
            restoring: (phase, completedSteps, totalSteps) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(phase, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: totalSteps > 0 ? completedSteps / totalSteps : null,
                ),
                const SizedBox(height: 8),
                Text('Step $completedSteps of $totalSteps'),
              ],
            ),
            complete: (collectionsRestored) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 24),
                Text(
                  'Restore complete!',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            error: (message) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                Text(
                  'Restore failed',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _retry, child: const Text('Retry')),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _navigateToApp,
                  child: const Text('Skip & continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
