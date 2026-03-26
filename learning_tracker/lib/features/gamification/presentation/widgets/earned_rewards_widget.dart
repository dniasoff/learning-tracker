import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_providers.dart';

/// Displays earned rewards history.
///
/// In [UserMode.child] mode, unrevealed rewards show "Mystery Reward!".
/// In [UserMode.adult] mode, all earned reward titles are visible.
class EarnedRewardsWidget extends ConsumerWidget {
  final UserMode userMode;

  const EarnedRewardsWidget({super.key, required this.userMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earned = ref.watch(earnedRewardsProvider);

    return earned.when(
      data: (rewards) {
        if (rewards.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No rewards earned yet. Keep learning!'),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final reward in rewards)
              ListTile(
                leading: Icon(
                  (userMode == UserMode.adult ||
                          reward.isRevealed ||
                          reward.isVisible)
                      ? Icons.emoji_events
                      : Icons.help_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  (userMode == UserMode.adult ||
                          reward.isRevealed ||
                          reward.isVisible)
                      ? reward.title
                      : 'Mystery Reward!',
                ),
                subtitle:
                    (userMode == UserMode.adult ||
                        reward.isRevealed ||
                        reward.isVisible)
                    ? Text(reward.description)
                    : null,
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        ref
            .read(talkerProvider)
            .error('Failed to load earned rewards', error, stack);
        return const Text('Error loading rewards');
      },
    );
  }
}
