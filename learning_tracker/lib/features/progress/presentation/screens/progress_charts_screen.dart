import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/presentation/providers/chart_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/completions_bar_chart.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/cumulative_line_chart.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/points_over_time_chart.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/streak_calendar.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_terms_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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
      ChartTimeRange.allTime => (start: DateTime(2024, 1, 1), end: today),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userMode = ref.watch(dashboardUserModeProvider).asData?.value;
    final resolvedUserMode = userMode ?? UserMode.adult;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                Expanded(
                  child: Text(
                    l10n.progressChartsTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 10),
            _buildTimeRangeSelector(l10n),
            const SizedBox(height: 10),
            _buildCurriculumToggle(l10n),
            const SizedBox(height: 16),
            _ChartSection(
              title: l10n.chartCompletionsOverTime,
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.chartDailyActivity,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF545D99),
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              child: SizedBox(height: 170, child: _buildCompletionsChart(l10n)),
            ),
            const SizedBox(height: 14),
            _ChartSection(
              title: l10n.chartCumulativeProgress,
              subtitle: l10n.chartCumulativeProgressSubtitle,
              child: SizedBox(height: 150, child: _buildCumulativeChart(l10n)),
            ),
            const SizedBox(height: 14),
            if (resolvedUserMode == UserMode.child) ...[
              _ChartSection(
                title: l10n.chartPointsEarned,
                subtitle: l10n.chartTotalTorahPoints,
                trailing: _buildTotalPointsLabel(),
                child: SizedBox(
                  height: 140,
                  child: _buildPointsChart(l10n, resolvedUserMode),
                ),
              ),
              const SizedBox(height: 14),
            ],
            _ChartSection(
              title: l10n.chartLearningJourney,
              subtitle: l10n.chartJourneyMotivation,
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6F77),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.chartSevenDayStreak,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              child: _buildStreakCalendar(l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector(AppLocalizations l10n) {
    return Row(
      children: ChartTimeRange.values.map((range) {
        final selected = _timeRange == range;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _timeRange = range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF123DAE)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  switch (range) {
                    ChartTimeRange.last7Days => l10n.chartLast7Days,
                    ChartTimeRange.last30Days => l10n.chartLast30Days,
                    ChartTimeRange.allTime => l10n.chartAllTime,
                  },
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : const Color(0xFF5E6678),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCurriculumToggle(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterPill(
            label: l10n.chartFilterAll,
            selected: _curriculum == null,
            onSelected: (_) => setState(() => _curriculum = null),
          ),
          const SizedBox(width: 8),
          ...CurriculumId.values.map(
            (curriculum) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterPill(
                // Single-script label — Hebrew when Hebrew Terms is on,
                // transliterated English when off. Never both.
                label: ref.watch(hebrewTermsScriptProvider)
                    ? curriculum.displayNameHe
                    : curriculum.displayNameEn,
                selected: _curriculum == curriculum,
                onSelected: (_) => setState(
                  () => _curriculum = _curriculum == curriculum
                      ? null
                      : curriculum,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalPointsLabel() {
    final service = ref.watch(chartDataServiceProvider);
    final dates = _dateRange;
    return FutureBuilder<List<DailyPointsData>?>(
      future: service.getDailyPoints(
        startDate: dates.start,
        endDate: dates.end,
        userMode: UserMode.child,
        curriculumId: _curriculum?.storageKey,
      ),
      builder: (context, snapshot) {
        final total = snapshot.data?.fold<int>(
          0,
          (sum, day) => sum + day.points,
        );
        return Text(
          total?.toString() ?? '--',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1F2F),
          ),
        );
      },
    );
  }

  Widget _buildCompletionsChart(AppLocalizations l10n) {
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
            message: l10n.chartFailedToLoad,
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) {
          return LoadingIndicator(message: l10n.loading);
        }
        return CompletionsBarChart(data: snapshot.data!);
      },
    );
  }

  Widget _buildCumulativeChart(AppLocalizations l10n) {
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
            message: l10n.chartFailedToLoad,
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) {
          return LoadingIndicator(message: l10n.loading);
        }
        return CumulativeLineChart(data: snapshot.data!);
      },
    );
  }

  Widget _buildPointsChart(AppLocalizations l10n, UserMode userMode) {
    final service = ref.watch(chartDataServiceProvider);
    final dates = _dateRange;

    return FutureBuilder<List<DailyPointsData>?>(
      future: service.getDailyPoints(
        startDate: dates.start,
        endDate: dates.end,
        userMode: userMode,
        curriculumId: _curriculum?.storageKey,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorDisplay(
            message: l10n.chartFailedToLoad,
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return LoadingIndicator(message: l10n.loading);
        }
        return PointsOverTimeChart(data: snapshot.data!);
      },
    );
  }

  Widget _buildStreakCalendar(AppLocalizations l10n) {
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
            message: l10n.chartFailedToLoad,
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) {
          return LoadingIndicator(message: l10n.loading);
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
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const _ChartSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF03174C).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF778099),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      side: BorderSide.none,
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF123DAE),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? Colors.white : const Color(0xFF4D5668),
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
