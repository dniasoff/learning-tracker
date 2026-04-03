import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_progress.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/deadline_content.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/momentum_content.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/program_calendar_content.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/shared/chazara_status_line.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/velocity_content.dart';

/// Per-track dashboard card with variant-specific content.
///
/// Renders one of 4 variant layouts based on [TrackProgress.variant]:
/// - Program Calendar: Hebrew content ref + cycle position
/// - Deadline: progress bar + pace vs deadline
/// - Velocity: rate vs target
/// - Momentum: personal average with gentle tone
class TrackCard extends StatelessWidget {
  const TrackCard({
    super.key,
    required this.progress,
    required this.userMode,
    this.onTap,
    this.onContinue,
  });

  final TrackProgress progress;
  final UserMode userMode;
  final VoidCallback? onTap;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = userMode == UserMode.child ? 16.0 : 12.0;
    final buttonHeight = userMode == UserMode.child ? 56.0 : 48.0;
    final curriculumColor = AppTheme.getCurriculumColor(progress.curriculumId);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: curriculumColor, width: 4),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: track label + curriculum chip
              Row(
                children: [
                  Expanded(
                    child: Text(
                      progress.trackLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: curriculumColor.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      progress.curriculumId.displayNameHe,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: curriculumColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Variant-specific content
              _buildVariantContent(),

              // Chazara line (conditional)
              if (progress.chazaraStatus != null) ...[
                const Divider(height: 16),
                ChazaraStatusLine(status: progress.chazaraStatus!),
              ],

              const SizedBox(height: 8),

              // Footer: task count + Continue button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Today: ${progress.tasksToday} task${progress.tasksToday == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(
                      minimumSize: Size(0, buttonHeight),
                    ),
                    child: const Text('Continue →'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantContent() {
    switch (progress.variant) {
      case TrackProgressVariant.programCalendar:
        return ProgramCalendarContent(
          calendarPos: progress.calendarPos!,
        );
      case TrackProgressVariant.deadlineGoal:
        return DeadlineContent(progress: progress);
      case TrackProgressVariant.velocityGoal:
        return VelocityContent(progress: progress);
      case TrackProgressVariant.momentum:
        return MomentumContent(progress: progress);
    }
  }
}
