import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/tutor_mode/domain/services/tutor_dashboard_aggregator.dart';
import 'package:learning_tracker/features/tutor_mode/presentation/providers/tutor_dashboard_providers.dart';

@RoutePage()
class TutorDashboardScreen extends ConsumerStatefulWidget {
  const TutorDashboardScreen({super.key});

  @override
  ConsumerState<TutorDashboardScreen> createState() =>
      _TutorDashboardScreenState();
}

class _TutorDashboardScreenState extends ConsumerState<TutorDashboardScreen> {
  CurriculumId? _selectedCurriculum;

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(tutorDashboardDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(text: 'Tutor Dashboard'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility,
                  size: 16,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  'Read Only',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('Error loading dashboard: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(tutorDashboardDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => _DashboardBody(
          data: _selectedCurriculum != null
              ? data.filterByCurriculum(_selectedCurriculum!)
              : data,
          allCurricula: data.activeCurricula,
          selectedCurriculum: _selectedCurriculum,
          onCurriculumChanged: (c) => setState(() => _selectedCurriculum = c),
          onRefresh: () async => ref.invalidate(tutorDashboardDataProvider),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final TutorDashboardData data;
  final List<CurriculumId> allCurricula;
  final CurriculumId? selectedCurriculum;
  final ValueChanged<CurriculumId?> onCurriculumChanged;
  final Future<void> Function() onRefresh;

  const _DashboardBody({
    required this.data,
    required this.allCurricula,
    required this.selectedCurriculum,
    required this.onCurriculumChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Curriculum filter
          if (allCurricula.length > 1) ...[
            _CurriculumFilter(
              curricula: allCurricula,
              selected: selectedCurriculum,
              onChanged: onCurriculumChanged,
            ),
            const SizedBox(height: 16),
          ],

          // Pace status cards
          if (data.paceInfo.isNotEmpty) ...[
            Text(
              'Progress & Pace',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...data.paceInfo.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PaceCard(curriculum: entry.key, info: entry.value),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Chazara queue
          Text('Chazara Queue', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (data.chazaraQueue.isEmpty)
            const _EmptySection(
              icon: Icons.check_circle_outline,
              message: 'No items due for review',
            )
          else
            _ChazaraQueueSection(items: data.chazaraQueue),
          const SizedBox(height: 16),

          // Daily tasks (read-only)
          Text(
            'Today\'s Tasks',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (data.dailyTasks.isEmpty)
            const _EmptySection(
              icon: Icons.task_alt,
              message: 'No tasks scheduled for today',
            )
          else
            _DailyTasksSection(tasks: data.dailyTasks),
          const SizedBox(height: 16),

          // Completion history
          Text(
            'Completion History',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (data.completionHistory.isEmpty)
            const _EmptySection(
              icon: Icons.history,
              message: 'No completions yet',
            )
          else
            _CompletionHistorySection(
              completions: data.completionHistory.take(50).toList(),
              totalCount: data.completionHistory.length,
            ),
        ],
      ),
    );
  }
}

class _CurriculumFilter extends StatelessWidget {
  final List<CurriculumId> curricula;
  final CurriculumId? selected;
  final ValueChanged<CurriculumId?> onChanged;

  const _CurriculumFilter({
    required this.curricula,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          const SizedBox(width: 8),
          ...curricula.map(
            (c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(c.displayNameEn),
                selected: selected == c,
                onSelected: (_) => onChanged(selected == c ? null : c),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaceCard extends StatelessWidget {
  final CurriculumId curriculum;
  final TutorPaceInfo info;

  const _PaceCard({required this.curriculum, required this.info});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paceStatus = info.paceStatus;
    final statusColor = paceStatus != null
        ? switch (paceStatus.status) {
            PaceStatusType.ahead => Colors.green,
            PaceStatusType.onPace => Colors.blue,
            PaceStatusType.behind => Colors.orange,
          }
        : theme.colorScheme.onSurfaceVariant;
    final statusLabel = paceStatus != null
        ? switch (paceStatus.status) {
            PaceStatusType.ahead => 'Ahead',
            PaceStatusType.onPace => 'On Track',
            PaceStatusType.behind => 'Behind',
          }
        : 'No Goal';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    curriculum.displayNameEn,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: info.completionPercentage.clamp(0.0, 1.0),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 4),
            Text(
              '${(info.completionPercentage * 100).toStringAsFixed(1)}% complete'
              ' \u2022 ${info.totalCompletions} completions',
              style: theme.textTheme.bodySmall,
            ),
            if (paceStatus != null && paceStatus.daysDelta != 0) ...[
              const SizedBox(height: 4),
              Text(
                paceStatus.daysDelta > 0
                    ? '${paceStatus.daysDelta} days ahead'
                    : '${-paceStatus.daysDelta} days behind',
                style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChazaraQueueSection extends StatelessWidget {
  final List<ChazaraQueueItem> items;

  const _ChazaraQueueSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final overdue = items
        .where((i) => i.urgency == ChazaraUrgency.overdue)
        .toList();
    final dueToday = items
        .where((i) => i.urgency == ChazaraUrgency.dueToday)
        .toList();
    final upcoming = items
        .where((i) => i.urgency == ChazaraUrgency.upcoming)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (overdue.isNotEmpty)
          _ChazaraGroup(label: 'Overdue', color: Colors.red, items: overdue),
        if (dueToday.isNotEmpty)
          _ChazaraGroup(
            label: 'Due Today',
            color: Colors.orange,
            items: dueToday,
          ),
        if (upcoming.isNotEmpty)
          _ChazaraGroup(label: 'Upcoming', color: Colors.blue, items: upcoming),
      ],
    );
  }
}

class _ChazaraGroup extends StatelessWidget {
  final String label;
  final Color color;
  final List<ChazaraQueueItem> items;

  const _ChazaraGroup({
    required this.label,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '$label (${items.length})',
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
            ],
          ),
        ),
        ...items.map(
          (item) => Card(
            child: ListTile(
              dense: true,
              title: Text(item.sefariaRef),
              subtitle: Text(
                '${item.stageName}'
                '${item.curriculumId.displayNameEn != '' ? ' \u2022 ${item.curriculumId.displayNameEn}' : ''}'
                '${item.daysOverdue > 0 ? ' \u2022 ${item.daysOverdue}d overdue' : ''}',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _DailyTasksSection extends StatelessWidget {
  final List<DailyTask> tasks;

  const _DailyTasksSection({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: tasks.map((task) {
        final priorityColor = switch (task.priority) {
          DailyTaskPriority.overdueChazara => Colors.red,
          DailyTaskPriority.scheduledChazara => Colors.orange,
          DailyTaskPriority.newLearning => Colors.green,
        };
        final priorityLabel = switch (task.priority) {
          DailyTaskPriority.overdueChazara => 'Overdue',
          DailyTaskPriority.scheduledChazara => 'Chazara',
          DailyTaskPriority.newLearning => 'New',
        };

        return Card(
          child: ListTile(
            dense: true,
            leading: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            title: Text(task.contentItemSefariaRef),
            subtitle: Text(
              '${task.stageName} \u2022 ${task.curriculumId.displayNameEn}'
              ' \u2022 ~${task.estimatedEffortMinutes}min',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: priorityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                priorityLabel,
                style: TextStyle(
                  color: priorityColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CompletionHistorySection extends StatelessWidget {
  final List<Completion> completions;
  final int totalCount;

  const _CompletionHistorySection({
    required this.completions,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...completions.map((completion) {
          final completedDate = completion.completedAt.toLocal();
          final formattedDate =
              '${_monthName(completedDate.month)} ${completedDate.day}, '
              '${completedDate.year} ${_formatTime(completedDate)}';

          return Card(
            child: ListTile(
              dense: true,
              title: Text(completion.sefariaRef),
              subtitle: Text(formattedDate),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 2),
                  Text(
                    '${completion.points}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }),
        if (totalCount > completions.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Showing ${completions.length} of $totalCount completions',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  static String _monthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month];
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    if (hour == 0) return '12:$minute AM';
    if (hour < 12) return '$hour:$minute AM';
    if (hour == 12) return '12:$minute PM';
    return '${hour - 12}:$minute PM';
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptySection({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
