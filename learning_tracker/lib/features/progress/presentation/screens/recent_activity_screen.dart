import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/progress/presentation/providers/recent_activity_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/cumulative_line_chart.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/limudim_chazaros_bar_chart.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/points_over_time_chart.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/streak_calendar.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Recent Activity — the engagement-tier lens.
///
/// Strictly live-only data per the three-tier credit policy. Replaces the
/// legacy "Progress Charts" and "Streak History" screens with a single
/// lens that answers *"What did I do recently?"*.
///
/// Layout (top-down):
///   1. AppBar with back button + the engagement-tier title.
///   2. Time-range pills (Last 7 / Last 30 / All time).
///   3. Curriculum filter pills.
///   4. Streak header card — current + best streak + a weekly dot calendar.
///   5. Limudim & Chazaros stacked bar chart (live only).
///   6. Cumulative line chart (live only).
///   7. Points-over-time bar (child mode only — adult mode hides the card).
///
/// All futures are wired through [recentActivityProviders] which key on
/// the active [RecentActivityWindow] — switching range / curriculum gets a
/// fresh fetch; unrelated rebuilds reuse the cached future automatically.
@RoutePage()
class RecentActivityScreen extends ConsumerStatefulWidget {
  const RecentActivityScreen({super.key});

  @override
  ConsumerState<RecentActivityScreen> createState() =>
      _RecentActivityScreenState();
}

class _RecentActivityScreenState extends ConsumerState<RecentActivityScreen> {
  ChartTimeRange _timeRange = ChartTimeRange.last7Days;
  CurriculumId? _curriculum;

  ({DateTime start, DateTime end}) get _dateRange {
    final now = DateTimeFactory.nowLocal();
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
      // Use [kChartAllTimeFloor] instead of an inline literal so the
      // "All time" floor is named and traceable (F18 — W7-D fix wave).
      // ChartDataService caps this internally to the first live completion
      // (and bucketises to weekly) so the chart never receives ~9,600
      // leading empty days. See [kChartDailyMaxDays].
      ChartTimeRange.allTime => (start: kChartAllTimeFloor, end: today),
    };
  }

  RecentActivityWindow get _window {
    final dates = _dateRange;
    return RecentActivityWindow(
      startDate: dates.start,
      endDate: dates.end,
      curriculumId: _curriculum?.storageKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final terms = domainTermLabels(ref);
    final userMode =
        ref.watch(dashboardUserModeProvider).asData?.value ?? UserMode.adult;
    final theme = Theme.of(context);
    final window = _window;

    return Scaffold(
      backgroundColor: AppColors.surfaceF4b,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.tierLensRecentActivity,
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
            _buildCurriculumFilter(l10n),
            const SizedBox(height: 16),
            _StreakHeaderCard(window: window),
            const SizedBox(height: 14),
            _ChartSection(
              title:
                  '${terms.limud} & ${terms.chazaros}',
              subtitle: l10n.recentActivityLiveOnlyDisclaimer,
              child: SizedBox(
                height: 200,
                child: _LimudChazaraChartBody(window: window),
              ),
            ),
            const SizedBox(height: 14),
            _ChartSection(
              title: l10n.chartCumulativeProgress,
              subtitle: l10n.recentActivityLiveOnlyDisclaimer,
              child: SizedBox(
                height: 150,
                child: _CumulativeChartBody(window: window),
              ),
            ),
            if (userMode == UserMode.child) ...[
              const SizedBox(height: 14),
              _ChartSection(
                title: l10n.chartPointsEarned,
                subtitle: l10n.chartTotalTorahPoints,
                trailing: _PointsTotalLabel(window: window),
                child: SizedBox(
                  height: 140,
                  child: _PointsChartBody(window: window),
                ),
              ),
            ],
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
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: GestureDetector(
              onTap: () => setState(() => _timeRange = range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppColors.blueMid : Colors.transparent,
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
                    color:
                        selected ? Colors.white : const Color(0xFF5E6678),
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

  Widget _buildCurriculumFilter(AppLocalizations l10n) {
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
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _FilterPill(
                label: curriculumLabelText(ref, curriculum: curriculum),
                selected: _curriculum == curriculum,
                onSelected: (_) => setState(
                  () => _curriculum =
                      _curriculum == curriculum ? null : curriculum,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Streak header ──────────────────────────────────────────────────────────

class _StreakHeaderCard extends ConsumerWidget {
  const _StreakHeaderCard({required this.window});

  final RecentActivityWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final streakAsync = ref.watch(dashboardStreakProvider);
    final activeDatesAsync = ref.watch(
      recentActivityStreakDatesProvider(window),
    );

    return _Card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.streakLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF778099),
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              streakAsync.maybeWhen(
                data: (s) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6F77),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.tierCounterStreakDays(s.currentStreak),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          streakAsync.when(
            data: (s) => Row(
              children: [
                Text(
                  '${s.currentStreak}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1F2F),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.learnStreakDayStreak(s.currentStreak),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5E6678),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.learnStreakPersonalBest(s.maxStreak),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF778099),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            loading: () => LoadingIndicator(message: l10n.loading),
            error: (e, _) => Text(l10n.chartFailedToLoad),
          ),
          // When a curriculum chip is active, clarify the scope mismatch:
          // the headline streak number is profile-global (sourced from
          // `dashboardStreakProvider` — the user's overall live streak,
          // same as the Dashboard pill), but the calendar dots below are
          // scoped to the active curriculum filter. F11 (W7-D fix wave)
          // chose Path A: thread `curriculumId` end-to-end into the
          // calendar, document the global streak number here.
          if (window.curriculumId != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.labelStreakAcrossAllCurricula,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF778099),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          activeDatesAsync.when(
            data: (activeDates) => StreakCalendar(
              activeDates: activeDates,
              startDate: window.startDate,
              endDate: window.endDate,
            ),
            loading: () => LoadingIndicator(message: l10n.loading),
            error: (e, _) => ErrorDisplay(
              message: l10n.chartFailedToLoad,
              onRetry: () => ref.invalidate(
                recentActivityStreakDatesProvider(window),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chart bodies ───────────────────────────────────────────────────────────

class _LimudChazaraChartBody extends ConsumerWidget {
  const _LimudChazaraChartBody({required this.window});

  final RecentActivityWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(
      recentActivityLimudimChazarosProvider(window),
    );
    return async.when(
      data: (data) => LimudimChazarosBarChart(data: data),
      loading: () => LoadingIndicator(message: l10n.loading),
      error: (e, _) => ErrorDisplay(
        message: l10n.chartFailedToLoad,
        onRetry: () => ref.invalidate(
          recentActivityLimudimChazarosProvider(window),
        ),
      ),
    );
  }
}

class _CumulativeChartBody extends ConsumerWidget {
  const _CumulativeChartBody({required this.window});

  final RecentActivityWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(recentActivityCumulativeProvider(window));
    return async.when(
      data: (data) => CumulativeLineChart(data: data),
      loading: () => LoadingIndicator(message: l10n.loading),
      error: (e, _) => ErrorDisplay(
        message: l10n.chartFailedToLoad,
        onRetry: () => ref.invalidate(
          recentActivityCumulativeProvider(window),
        ),
      ),
    );
  }
}

class _PointsChartBody extends ConsumerWidget {
  const _PointsChartBody({required this.window});

  final RecentActivityWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(recentActivityPointsProvider(window));
    return async.when(
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        return PointsOverTimeChart(data: data);
      },
      loading: () => LoadingIndicator(message: l10n.loading),
      error: (e, _) => ErrorDisplay(
        message: l10n.chartFailedToLoad,
        onRetry: () => ref.invalidate(
          recentActivityPointsProvider(window),
        ),
      ),
    );
  }
}

class _PointsTotalLabel extends ConsumerWidget {
  const _PointsTotalLabel({required this.window});

  final RecentActivityWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(recentActivityPointsProvider(window));
    final total =
        async.asData?.value?.fold<int>(0, (sum, d) => sum + d.points);
    return Text(
      total == null ? '--' : l10n.tierCounterPoints(total),
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1A1F2F),
      ),
    );
  }
}

// ── Reusable card shells ───────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.blueNavy.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
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
    return _Card(
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
      selectedColor: AppColors.blueMid,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? Colors.white : const Color(0xFF4D5668),
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
