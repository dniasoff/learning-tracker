import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/social/presentation/providers/learning_group_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class GroupTaskProgressSlot extends ConsumerWidget {
  const GroupTaskProgressSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = ref.watch(selectedProfileIdProvider);
    if (profileId == null) return const SizedBox.shrink();
    final today = ref.read(localDayClockProvider).today();
    final onDate =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final query = (profileId: profileId, onDate: onDate);
    final progress = ref.watch(groupTaskProgressForLearnProvider(query));
    final l10n = AppLocalizations.of(context)!;
    return progress.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => InlineAsyncError(
        error: error,
        onRetry: () => ref.invalidate(groupTaskProgressForLearnProvider(query)),
      ),
      data: (entries) {
        final visible = entries
            .where(
              (entry) => entry.task.allocationMembers.any(
                (member) => member['progress'] is Map<Object?, Object?>,
              ),
            )
            .toList(growable: false);
        if (visible.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.groupTaskLearnProgress,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final entry in visible)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.groupName} · ${entry.task.taskName}',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      for (final member in entry.task.allocationMembers)
                        if (member['progress']
                            case final Map<Object?, Object?> progress)
                          Text(
                            l10n.groupTaskMemberProgress(
                              member['displayName'] as String? ?? '',
                              (progress['completed'] as num?)?.toInt() ?? 0,
                              (progress['total'] as num?)?.toInt() ?? 0,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
