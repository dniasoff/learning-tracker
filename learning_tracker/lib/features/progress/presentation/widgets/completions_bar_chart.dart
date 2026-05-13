import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Bar chart showing daily completion counts.
class CompletionsBarChart extends StatelessWidget {
  final List<DailyCompletionData> data;

  const CompletionsBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noData));
    }

    final maxCount = data.fold<int>(
      0,
      (max, d) => d.count > max ? d.count : max,
    );
    final maxY = maxCount == 0 ? 5.0 : (maxCount + 1).toDouble();

    final isShortRange = data.length <= 7;
    final weekdayLabel = <int, String>{
      DateTime.monday: 'MON',
      DateTime.tuesday: 'TUE',
      DateTime.wednesday: 'WED',
      DateTime.thursday: 'THU',
      DateTime.friday: 'FRI',
      DateTime.saturday: 'SAT',
      DateTime.sunday: 'SUN',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
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
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF8A91A5),
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
                    toY: data[i].count.toDouble(),
                    color: i == data.length - 1
                        ? const Color(0xFF123DAE)
                        : const Color(0xFFC8CEDB),
                    width: isShortRange ? 18 : 10,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                  ),
                ],
                showingTooltipIndicators: const [],
              ),
          ],
        ),
      ),
    );
  }
}
