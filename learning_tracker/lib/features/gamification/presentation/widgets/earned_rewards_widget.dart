import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
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

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rewards.length,
          itemBuilder: (context, index) {
            final reward = rewards[index];
            final showDetails = userMode == UserMode.adult || reward.isRevealed;

            return ListTile(
              leading: Icon(
                showDetails ? Icons.emoji_events : Icons.help_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(showDetails ? reward.title : 'Mystery Reward!'),
              subtitle: showDetails ? Text(reward.description) : null,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Error loading rewards'),
    );
  }
}
