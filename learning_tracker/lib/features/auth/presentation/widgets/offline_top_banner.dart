import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/auth/presentation/providers/connectivity_providers.dart';

/// Slim top banner shown above the app bar when a cloud-born user
/// is temporarily offline. Local-born users never see this banner —
/// being offline is their permanent state, not news (v2 §4.6).
///
/// Slides down on offline, slides up on reconnect.
class OfflineTopBanner extends ConsumerWidget {
  const OfflineTopBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    if (!authState.isCloudBorn) return const SizedBox.shrink();

    final connectivity = ref.watch(connectivityStreamProvider);
    final isOffline = connectivity.maybeWhen(
      data: (online) => !online,
      orElse: () => false,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: isOffline
          ? Semantics(
              liveRegion: true,
              label: "Offline — changes will sync when you're back online",
              child: Container(
                width: double.infinity,
                height: 32,
                color: Theme.of(context).colorScheme.secondaryContainer,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "Offline — changes will sync when you're back",
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
