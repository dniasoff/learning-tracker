import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Bar chart showing points earned per day (child mode only).
class PointsOverTimeChart extends StatelessWidget {
  final List<DailyPointsData> data;

  const PointsOverTimeChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noData));
    }

    final maxPoints = data.fold<int>(
      0,
      (max, d) => d.points > max ? d.points : max,
    );
    final maxY = maxPoints == 0 ? 10.0 : (maxPoints + 5).toDouble();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          maxY: maxY,
          barTouchData: const BarTouchData(enabled: false),
          titlesData: const FlTitlesData(
            show: false,
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].points.toDouble(),
                    color: const Color(0xFFF2D9B3),
                    width: data.length <= 7 ? 20 : 10,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
