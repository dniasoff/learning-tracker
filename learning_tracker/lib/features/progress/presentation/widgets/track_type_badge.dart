import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// Small chip displaying the track type (v1: always `personal`) with color.
class TrackTypeBadge extends StatelessWidget {
  const TrackTypeBadge({super.key, required this.trackType});

  final TrackType trackType;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getTrackColor(trackType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: CurriculumLabel.trackType(
        trackType,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
