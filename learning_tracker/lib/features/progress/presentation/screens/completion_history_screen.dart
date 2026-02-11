import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';

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
  List<Completion>? _completions;
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadCompletions();
  }

  Future<void> _loadCompletions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final database = ref.read(appDatabaseProvider);

      List<Completion> completions;
      if (widget.curriculumId != null) {
        completions = await database.completionDao.getCompletionsByCurriculum(
          widget.curriculumId!,
        );
      } else {
        completions = await database.completionDao.getAllCompletions();
      }

      // Apply track filter if specified
      if (_trackFilter != null) {
        completions = completions
            .where((c) => c.trackType == _trackFilter!.storageKey)
            .toList();
      }

      // Sort by completion date descending (most recent first)
      completions.sort((a, b) => b.completedAt.compareTo(a.completedAt));

      setState(() {
        _completions = completions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  void _onTrackFilterChanged(TrackType? trackType) {
    setState(() {
      _trackFilter = trackType;
    });
    _loadCompletions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completion History'),
        actions: [_buildTrackFilterMenu()],
      ),
      body: Column(
        children: [
          if (_trackFilter != null) _buildActiveFilterChip(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Loading history...');
    }

    if (_error != null) {
      return ErrorDisplay(
        message: 'Failed to load completion history: $_error',
        onRetry: _loadCompletions,
      );
    }

    return _buildCompletionsList(_completions!);
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No completions yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
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
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
