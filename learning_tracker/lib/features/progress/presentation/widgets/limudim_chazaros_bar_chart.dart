import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Limud (stage-1 / initial learning) segment colour.
///
/// Uses [AppPaletteContext.colors]'s `chartLimudBlue` (not `blueMid`) — this
/// bar is drawn directly on the card surface, so it needs the token that
/// stays visible against the card in dark mode, not the hero-fill token that
/// stays deep for white content painted over it (run-9 audit).
Color _kLimudColor(BuildContext context) => context.colors.chartLimudBlue;

/// Chazara (stage ≥ 2 / review) segment colour.
Color _kChazaraColor(BuildContext context) =>
    context.colors.progressChazaraSegment;

/// Two-colour stacked bar chart for the Recent Activity screen.
///
/// Each bucket shows two segments:
///  - **Limud** (bottom segment, deep blue) — stage-1 initial-learning marks.
///  - **Chazara** (top segment, accent amber) — stage ≥ 2 review marks.
///
/// The chart shows **track learning** data — provenance comes from
/// [ChartDataService.getDailyLimudimAndChazaros] which applies
/// [CompletionTierFilter.trackAchievement] (live + bulk-mark in-track). The
/// widget itself does no tier filtering; it renders whatever it is given.
///
/// Displays the limud/chazara split per bucket plus a small legend row
/// underneath. Used by [RecentActivityScreen].
class LimudimChazarosBarChart extends ConsumerWidget {
  final List<DailyLimudChazaraData> data;

  const LimudimChazarosBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (data.isEmpty) {
      return Center(child: Text(l10n.noData));
    }

    final terms = domainTermLabels(ref);

    // Gate the chazara segment and legend on whether any bucket has chazara
    // completions (Rule 8).  When no tracks have chazara, chazaraCount is
    // always 0 so the chart becomes a single-colour limudim-only display.
    final hasAnyChazara = data.any((d) => d.chazaraCount > 0);

    final maxTotal = data.fold<int>(
      0,
      (max, d) => d.total > max ? d.total : max,
    );
    final maxY = maxTotal == 0 ? 5.0 : (maxTotal + 1).toDouble();

    final isShortRange = data.length <= 7;
    // Weekday axis labels follow both the UI locale AND the Hebrew-date
    // preference — mirrors the streak calendar's headerUsesHebrewScript logic.
    // Either condition is sufficient: a Hebrew-locale device must show Hebrew
    // letters even on a Gregorian date system, and a user who opted into the
    // Hebrew calendar must see Hebrew weekday initials even with an English UI.
    final isHebrew =
        ref.watch(useHebrewDateProvider) ||
        ref.watch(currentAppLocaleProvider).languageCode == 'he';
    const weekdayLabelEn = <int, String>{
      DateTime.monday: 'MON',
      DateTime.tuesday: 'TUE',
      DateTime.wednesday: 'WED',
      DateTime.thursday: 'THU',
      DateTime.friday: 'FRI',
      DateTime.saturday: 'SAT',
      DateTime.sunday: 'SUN',
    };
    const weekdayLabelHe = <int, String>{
      DateTime.sunday: 'א',
      DateTime.monday: 'ב',
      DateTime.tuesday: 'ג',
      DateTime.wednesday: 'ד',
      DateTime.thursday: 'ה',
      DateTime.friday: 'ו',
      DateTime.saturday: 'ש',
    };
    final weekdayLabel = isHebrew ? weekdayLabelHe : weekdayLabelEn;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                maxY: maxY,
                barTouchData: const BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }
                        final step = isShortRange ? 1 : 2;
                        if (index % step != 0) return const SizedBox.shrink();
                        final d = data[index].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            weekdayLabel[d.weekday] ?? '',
                            style: TextStyle(
                              fontSize: 9,
                              color: context.colors.progressBarAxisLabel,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  for (var i = 0; i < data.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: data[i].total.toDouble(),
                          width: isShortRange ? 18 : 10,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                          // When any track has chazara, stack limud (bottom)
                          // and chazara (top).  For learn-only datasets render
                          // a single solid limudim bar (Rule 8).
                          rodStackItems: hasAnyChazara
                              ? [
                                  BarChartRodStackItem(
                                    0,
                                    data[i].limudCount.toDouble(),
                                    _kLimudColor(context),
                                  ),
                                  BarChartRodStackItem(
                                    data[i].limudCount.toDouble(),
                                    data[i].total.toDouble(),
                                    _kChazaraColor(context),
                                  ),
                                ]
                              : [
                                  BarChartRodStackItem(
                                    0,
                                    data[i].total.toDouble(),
                                    _kLimudColor(context),
                                  ),
                                ],
                        ),
                      ],
                      showingTooltipIndicators: const [],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _Legend(
            limudLabel: terms.limud,
            chazarosLabel: hasAnyChazara ? terms.chazaros : null,
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.limudLabel, this.chazarosLabel});

  final String limudLabel;

  /// Null when no tracks have chazara enabled (Rule 8) — the chazara dot
  /// is omitted entirely from the legend.
  final String? chazarosLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: _kLimudColor(context), label: limudLabel),
        if (chazarosLabel != null) ...[
          const SizedBox(width: 16),
          _LegendDot(color: _kChazaraColor(context), label: chazarosLabel!),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.colors.progressBarLegendLabel,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
