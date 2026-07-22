import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/progress/domain/models/chart_data.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Line chart showing cumulative progress with optional target line.
class CumulativeLineChart extends StatelessWidget {
  final List<CumulativeProgressPoint> data;
  final List<TargetLinePoint>? targetLine;

  const CumulativeLineChart({super.key, required this.data, this.targetLine});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noData));
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
        // chartLimudBlue (not blueMid): this line is drawn directly on the
        // card surface and needs to stay visible against it in dark mode —
        // the opposite requirement from blueMid's hero-fill role (run-9
        // audit; see AppPalette.chartLimudBlue doc).
        color: context.colors.chartLimudBlue,
        barWidth: 3,
        dotData: FlDotData(
          show: true,
          checkToShowDot: (spot, barData) => spot.x == data.length - 1,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: 3.5,
            color: context.colors.chartLimudBlue,
            strokeWidth: 2,
            strokeColor: Colors.white,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.colors.chartLimudBlue.withValues(alpha: 0.2),
              context.colors.chartLimudBlue.withValues(alpha: 0),
            ],
          ),
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
      padding: const EdgeInsets.only(top: 8),
      child: LineChart(
        LineChartData(
          maxY: maxY == 0 ? 5 : maxY,
          lineBarsData: lineBarsData,
          titlesData: FlTitlesData(
            show: false,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
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
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }
}
