import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';

@RoutePage()
class CompletionHistoryScreen extends ConsumerStatefulWidget {
  const CompletionHistoryScreen({
    super.key,
    @PathParam('curriculumId') this.curriculumId,
  });

  final String? curriculumId;

  @override
  ConsumerState<CompletionHistoryScreen> createState() =>
      _CompletionHistoryScreenState();
}

class _CompletionHistoryScreenState
    extends ConsumerState<CompletionHistoryScreen> {
  TrackType? _trackFilter;

  void _onTrackFilterChanged(TrackType? trackType) {
    setState(() {
      _trackFilter = trackType;
    });
  }

  @override
  Widget build(BuildContext context) {
    final completionsAsync = widget.curriculumId != null
        ? ref.watch(
            completionHistoryForCurriculumProvider(widget.curriculumId!),
          )
        : ref.watch(allCompletionHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(text: 'Completion History'),
        actions: [_buildTrackFilterMenu()],
      ),
      body: Column(
        children: [
          if (_trackFilter != null) _buildActiveFilterChip(),
          Expanded(child: _buildBody(completionsAsync)),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<Completion>> completionsAsync) {
    return completionsAsync.when(
      loading: () => const LoadingIndicator(message: 'Loading history...'),
      error: (error, _) => ErrorDisplay(
        message: 'Failed to load completion history: $error',
        onRetry: () {
          if (widget.curriculumId != null) {
            ref.invalidate(
              completionHistoryForCurriculumProvider(widget.curriculumId!),
            );
          } else {
            ref.invalidate(allCompletionHistoryProvider);
          }
        },
      ),
      data: (allCompletions) {
        // Apply track filter in-memory (SQL filter is a future optimisation)
        var completions = allCompletions;
        if (_trackFilter != null) {
          completions = completions
              .where((c) => c.trackType == _trackFilter!.storageKey)
              .toList();
        }
        // Sort by completion date descending (most recent first)
        completions = [...completions]
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
        return _buildCompletionsList(completions);
      },
    );
  }

  Widget _buildTrackFilterMenu() {
    return PopupMenuButton<TrackType?>(
      icon: Icon(
        _trackFilter != null ? Icons.filter_alt : Icons.filter_alt_outlined,
        color: _trackFilter != null ? AppTheme.trackPersonal : null,
      ),
      tooltip: 'Filter by track',
      onSelected: _onTrackFilterChanged,
      itemBuilder: (context) => [
        const PopupMenuItem<TrackType?>(
          value: null,
          child: Row(
            children: [
              Icon(Icons.clear),
              SizedBox(width: 8),
              Text('All Tracks'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...TrackType.values.map((trackType) {
          return PopupMenuItem<TrackType>(
            value: trackType,
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.getTrackColor(trackType),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(trackType.displayNameEn),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActiveFilterChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.getTrackColor(_trackFilter!).withValues(alpha: 0.1),
      child: Row(
        children: [
          const Text('Filtered by: ', style: TextStyle(fontSize: 14)),
          Chip(
            avatar: CircleAvatar(
              backgroundColor: AppTheme.getTrackColor(_trackFilter!),
            ),
            label: Text(_trackFilter!.displayNameEn),
            onDeleted: () => _onTrackFilterChanged(null),
            deleteIcon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionsList(List<Completion> completions) {
    if (completions.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No completions yet',
              style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completions.length,
      itemBuilder: (context, index) {
        return _buildCompletionCard(completions[index]);
      },
    );
  }

  Widget _buildCompletionCard(Completion completion) {
    final trackType = TrackType.fromStorageKey(completion.trackType);
    final trackColor = AppTheme.getTrackColor(trackType);
    // Format: "Feb 11, 2026 2:30 PM"
    final completedDate = completion.completedAt.toLocal();
    final formattedDate =
        '${_monthName(completedDate.month)} ${completedDate.day}, ${completedDate.year} ${_formatTime(completedDate)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 48,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        title: Text(
          completion.sefariaRef,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Stage ${completion.stageId} • ${trackType.displayNameEn}'),
            const SizedBox(height: 2),
            Text(
              formattedDate,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            Text(
              '${completion.points}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
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

  String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    if (hour == 0) return '12:$minute AM';
    if (hour < 12) return '$hour:$minute AM';
    if (hour == 12) return '12:$minute PM';
    return '${hour - 12}:$minute PM';
  }
}
