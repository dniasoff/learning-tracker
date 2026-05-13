import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_card_view_model.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// One-line lifetime-learning summary shown at the bottom of [TrackCard].
///
/// Displays the lifetime percentage label and a completion/chart icon.
/// When [LifetimeLearningData.isComplete] is true the icon turns green.
class LifetimeLearningLine extends StatelessWidget {
  const LifetimeLearningLine({super.key, required this.vm, required this.l10n});

  final TrackCardViewModel vm;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lifetime = vm.lifetime;
    final percentDisplay = lifetime.displayPercent ?? '…';

    return Row(
      children: [
        Expanded(
          child: Text(
            '${l10n.trackLifetimeLearning} • $percentDisplay',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.brandInkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(
          lifetime.isComplete
              ? Icons.check_circle_rounded
              : Icons.show_chart_rounded,
          size: 20,
          color: lifetime.isComplete
              ? kActiveTrackCompletionGreen
              : AppTheme.brandInkMuted,
        ),
      ],
    );
  }
}
