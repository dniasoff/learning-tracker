import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class StreakRecoveryBanner extends ConsumerWidget {
  final int currentStreak;

  const StreakRecoveryBanner({super.key, required this.currentStreak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final recoveryAsync = ref.watch(dashboardStreakRecoveryProvider);
    return recoveryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (info) {
        if (!info.wasRecovered) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            color: context.colors.brandCoral.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.shield,
                    color: context.colors.brandCoral,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.streakRecovery(info.currentStreak),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.colors.brandCoral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
