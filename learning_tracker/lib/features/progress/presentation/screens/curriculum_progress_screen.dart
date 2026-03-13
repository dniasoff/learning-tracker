import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/core/widgets/track_progress_bar.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';

@RoutePage()
class CurriculumProgressScreen extends ConsumerStatefulWidget {
  const CurriculumProgressScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
  });

  final String curriculumId;

  @override
  ConsumerState<CurriculumProgressScreen> createState() =>
      _CurriculumProgressScreenState();
}

class _CurriculumProgressScreenState
    extends ConsumerState<CurriculumProgressScreen> {
  bool _showBreakdown = true; // Toggle between breakdown and aggregate view

  @override
  Widget build(BuildContext context) {
    final curriculumName = _getCurriculumName(widget.curriculumId);

    return Scaffold(
      appBar: AppBar(title: Text('Progress - $curriculumName')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildViewToggle(),
            const SizedBox(height: 24),
            _showBreakdown ? _buildBreakdownView() : _buildAggregateView(),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment<bool>(
          value: true,
          label: Text('By Track'),
          icon: Icon(Icons.splitscreen),
        ),
        ButtonSegment<bool>(
          value: false,
          label: Text('Total'),
          icon: Icon(Icons.bar_chart),
        ),
      ],
      selected: {_showBreakdown},
      onSelectionChanged: (Set<bool> selected) {
        setState(() {
          _showBreakdown = selected.first;
        });
      },
    );
  }

  Widget _buildBreakdownView() {
    final trackBreakdownAsync = ref.watch(
      trackBreakdownProvider(widget.curriculumId),
    );

    return trackBreakdownAsync.when(
      data: (trackCounts) => _buildBreakdownContent(trackCounts),
      loading: () => const LoadingIndicator(message: 'Loading progress...'),
      error: (error, stack) => ErrorDisplay(
        message: 'Failed to load progress breakdown: $error',
        onRetry: () => ref.invalidate(trackBreakdownProvider),
      ),
    );
  }

  Widget _buildBreakdownContent(Map<TrackType, int> trackCounts) {
    final total = trackCounts.values.fold<int>(0, (sum, count) => sum + count);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completion Breakdown by Track',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TrackProgressBar(trackCounts: trackCounts),
            const SizedBox(height: 24),
            _buildTrackDetails(trackCounts),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Completions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  total.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackDetails(Map<TrackType, int> trackCounts) {
    return Column(
      children: TrackType.values.map((trackType) {
        final count = trackCounts[trackType] ?? 0;
        final color = AppTheme.getTrackColor(trackType);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  trackType.displayNameEn,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Text(
                '$count items',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAggregateView() {
    final aggregateAsync = ref.watch(
      aggregateCountProvider(widget.curriculumId),
    );

    return aggregateAsync.when(
      data: (total) => _buildAggregateContent(total),
      loading: () => const LoadingIndicator(message: 'Loading progress...'),
      error: (error, stack) => ErrorDisplay(
        message: 'Failed to load aggregate count: $error',
        onRetry: () => ref.invalidate(aggregateCountProvider),
      ),
    );
  }

  Widget _buildAggregateContent(int total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Total Completions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              total.toString(),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: AppTheme.getCurriculumColorByKey(widget.curriculumId),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'items completed',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurriculumName(String curriculumId) {
    final matches = CurriculumId.values.where(
      (c) => c.storageKey == curriculumId,
    );
    return matches.isNotEmpty ? matches.first.displayNameEn : curriculumId;
  }
}
