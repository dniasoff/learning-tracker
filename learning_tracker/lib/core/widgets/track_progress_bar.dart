import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// A progress bar showing completion count.
///
/// Previously segmented by track type; track-type display has been removed
/// per product rules (no track-type labels anywhere in the UI).
class TrackProgressBar extends StatelessWidget {
  const TrackProgressBar({
    super.key,
    required this.completionCount,
    this.height = 24.0,
    this.showLabels = true,
  });

  /// Total completion count to display.
  final int completionCount;

  /// Height of the progress bar in logical pixels.
  final double height;

  /// Whether to show text labels below the bar.
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    if (completionCount == 0) {
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
            child: Container(color: AppTheme.brandBlue),
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: 8),
          _buildLabel(context),
        ],
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
        child: Text('No completions yet', style: TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildLabel(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: AppTheme.brandBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('$completionCount', style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
