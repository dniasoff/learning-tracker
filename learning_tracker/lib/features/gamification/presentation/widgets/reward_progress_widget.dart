import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/talker_provider.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_model.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_providers.dart';

/// Shows progress toward the next unearned reward.
///
/// In [UserMode.child] mode, hides reward details showing "Mystery Reward!".
/// In [UserMode.adult] mode, shows reward title directly.
class RewardProgressWidget extends ConsumerWidget {
  final UserMode userMode;

  const RewardProgressWidget({super.key, required this.userMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextReward = ref.watch(nextRewardProvider);
    final progress = ref.watch(rewardProgressProvider);

    return nextReward.when(
      data: (reward) {
        if (reward == null) return const SizedBox.shrink();

        return progress.when(
          data: (progressValue) => _buildProgressCard(
            context,
            reward: reward,
            progress: progressValue,
          ),
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) {
            ref
                .read(talkerProvider)
                .error('Failed to load reward progress', error, stack);
            return const SizedBox.shrink();
          },
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) {
        ref
            .read(talkerProvider)
            .error('Failed to load next reward', error, stack);
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildProgressCard(
    BuildContext context, {
    required RewardModel reward,
    required double progress,
  }) {
    // Show title if: adult mode, or reward is visible, or reward is revealed
    final showTitle =
        userMode == UserMode.adult || reward.isVisible || reward.isRevealed;
    final title = showTitle ? reward.title : 'Mystery Reward!';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  userMode == UserMode.child
                      ? Icons.help_outline
                      : Icons.emoji_events,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toInt()}% complete',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
