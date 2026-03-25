import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// A segmented progress bar showing completion breakdown by track type.
///
/// Displays a horizontal bar divided into colored segments, each representing
/// the proportion of completions from a specific track (personal, school, tutor).
class TrackProgressBar extends StatelessWidget {
  const TrackProgressBar({
    super.key,
    required this.trackCounts,
    this.height = 24.0,
    this.showLabels = true,
  });

  /// Map of track types to completion counts.
  final Map<TrackType, int> trackCounts;

  /// Height of the progress bar in logical pixels.
  final double height;

  /// Whether to show text labels below the bar.
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final total = trackCounts.values.fold<int>(0, (sum, count) => sum + count);

    if (total == 0) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Row(children: _buildSegments(total)),
          ),
        ),
        if (showLabels) ...[const SizedBox(height: 8), _buildLabels()],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: const Center(
        child: Text(
          'No completions yet',
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  List<Widget> _buildSegments(int total) {
    final segments = <Widget>[];

    for (final trackType in TrackType.values) {
      final count = trackCounts[trackType] ?? 0;
      if (count > 0) {
        final proportion = count / total;
        segments.add(
          Expanded(
            flex: (proportion * 100).round(),
            child: Container(color: AppTheme.getTrackColor(trackType)),
          ),
        );
      }
    }

    return segments;
  }

  Widget _buildLabels() {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: TrackType.values.map((trackType) {
        final count = trackCounts[trackType] ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppTheme.getTrackColor(trackType),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${trackType.displayNameEn}: $count',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }
}
