import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/presentation/providers/chart_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/completions_bar_chart.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/cumulative_line_chart.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/points_over_time_chart.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/streak_calendar.dart';

@RoutePage()
class ProgressChartsScreen extends ConsumerStatefulWidget {
  const ProgressChartsScreen({super.key});

  @override
  ConsumerState<ProgressChartsScreen> createState() =>
      _ProgressChartsScreenState();
}

class _ProgressChartsScreenState extends ConsumerState<ProgressChartsScreen> {
  ChartTimeRange _timeRange = ChartTimeRange.last7Days;
  CurriculumId? _curriculum;
  final UserMode _userMode = UserMode.child;

  ({DateTime start, DateTime end}) get _dateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_timeRange) {
      ChartTimeRange.last7Days => (
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      ChartTimeRange.last30Days => (
        start: today.subtract(const Duration(days: 29)),
        end: today,
      ),
      ChartTimeRange.allTime => (start: DateTime(2020, 1, 1), end: today),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Progress Charts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTimeRangeSelector(),
          const SizedBox(height: 12),
          _buildCurriculumToggle(),
          const SizedBox(height: 24),
          _ChartSection(
            title: 'Completions Over Time',
            child: SizedBox(height: 200, child: _buildCompletionsChart()),
          ),
          const SizedBox(height: 24),
          _ChartSection(
            title: 'Cumulative Progress',
            child: SizedBox(height: 200, child: _buildCumulativeChart()),
          ),
          const SizedBox(height: 24),
          if (_userMode == UserMode.child) ...[
            _ChartSection(
              title: 'Points Earned',
              child: SizedBox(height: 200, child: _buildPointsChart()),
            ),
            const SizedBox(height: 24),
          ],
          _ChartSection(
            title: 'Streak Calendar',
            child: _buildStreakCalendar(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return SegmentedButton<ChartTimeRange>(
      segments: ChartTimeRange.values
          .map((r) => ButtonSegment(value: r, label: Text(r.displayName)))
          .toList(),
      selected: {_timeRange},
      onSelectionChanged: (set) => setState(() => _timeRange = set.first),
    );
  }

  Widget _buildCurriculumToggle() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _curriculum == null,
            onSelected: (_) => setState(() => _curriculum = null),
          ),
          const SizedBox(width: 8),
          ...CurriculumId.values.map(
            (c) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(c.displayNameEn),
                selected: _curriculum == c,
                onSelected: (_) =>
                    setState(() => _curriculum = _curriculum == c ? null : c),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionsChart() {
    final service = ref.watch(chartDataServiceProvider);
    final dates = _dateRange;

    return FutureBuilder<List<DailyCompletionData>>(
      future: service.getDailyCompletions(
        startDate: dates.start,
        endDate: dates.end,
        curriculumId: _curriculum?.storageKey,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorDisplay(
            message: 'Failed to load data',
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) {
          return const LoadingIndicator(message: 'Loading...');
        }
        return CompletionsBarChart(data: snapshot.data!);
      },
    );
  }

  Widget _buildCumulativeChart() {
    final service = ref.watch(chartDataServiceProvider);
    final dates = _dateRange;

    return FutureBuilder<List<CumulativeProgressPoint>>(
      future: service.getCumulativeProgress(
        startDate: dates.start,
        endDate: dates.end,
        curriculumId: _curriculum?.storageKey,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorDisplay(
            message: 'Failed to load data',
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) {
          return const LoadingIndicator(message: 'Loading...');
        }
        return CumulativeLineChart(data: snapshot.data!);
      },
    );
  }

  Widget _buildPointsChart() {
    final service = ref.watch(chartDataServiceProvider);
    final dates = _dateRange;

    return FutureBuilder<List<DailyPointsData>?>(
      future: service.getDailyPoints(
        startDate: dates.start,
        endDate: dates.end,
        userMode: _userMode,
        curriculumId: _curriculum?.storageKey,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorDisplay(
            message: 'Failed to load data',
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoadingIndicator(message: 'Loading...');
        }
        return PointsOverTimeChart(data: snapshot.data!);
      },
    );
  }

  Widget _buildStreakCalendar() {
    final service = ref.watch(chartDataServiceProvider);
    final dates = _dateRange;

    return FutureBuilder<Set<DateTime>>(
      future: service.getStreakCalendar(
        startDate: dates.start,
        endDate: dates.end,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorDisplay(
            message: 'Failed to load data',
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) {
          return const LoadingIndicator(message: 'Loading...');
        }
        return StreakCalendar(
          activeDates: snapshot.data!,
          startDate: dates.start,
          endDate: dates.end,
        );
      },
    );
  }
}

class _ChartSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
