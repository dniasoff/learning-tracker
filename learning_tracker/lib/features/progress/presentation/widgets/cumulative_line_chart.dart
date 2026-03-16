import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';

/// Line chart showing cumulative progress with optional target line.
class CumulativeLineChart extends StatelessWidget {
  final List<CumulativeProgressPoint> data;
  final List<TargetLinePoint>? targetLine;

  const CumulativeLineChart({super.key, required this.data, this.targetLine});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final maxActual = data.fold<int>(0, (m, d) => d.total > m ? d.total : m);
    final maxTarget =
        targetLine?.fold<double>(
          0,
          (m, d) => d.expectedTotal > m ? d.expectedTotal : m,
        ) ??
        0;
    final maxY =
        ([maxActual.toDouble(), maxTarget].reduce((a, b) => a > b ? a : b) *
                1.1)
            .ceilToDouble();

    final lineBarsData = <LineChartBarData>[
      // Actual progress line
      LineChartBarData(
        spots: [
          for (var i = 0; i < data.length; i++)
            FlSpot(i.toDouble(), data[i].total.toDouble()),
        ],
        isCurved: true,
        preventCurveOverShooting: true,
        color: Theme.of(context).colorScheme.primary,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
    ];

    // Add target line if available
    if (targetLine != null && targetLine!.length == data.length) {
      lineBarsData.add(
        LineChartBarData(
          spots: [
            for (var i = 0; i < targetLine!.length; i++)
              FlSpot(i.toDouble(), targetLine![i].expectedTotal),
          ],
          isCurved: false,
          color: Colors.orange,
          barWidth: 2,
          dashArray: [8, 4],
          dotData: const FlDotData(show: false),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, right: 16),
      child: LineChart(
        LineChartData(
          maxY: maxY == 0 ? 5 : maxY,
          lineBarsData: lineBarsData,
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
                  final step = data.length <= 7
                      ? 1
                      : data.length <= 14
                      ? 2
                      : 5;
                  if (index % step != 0) return const SizedBox.shrink();
                  final d = data[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${d.month}/${d.day}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  if (value == value.roundToDouble() && value >= 0) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }
}
