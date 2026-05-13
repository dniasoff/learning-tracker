import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_card_view_model.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';

/// Header row for [TrackCard].
///
/// Renders the primary track name, optional Hebrew secondary name, and a
/// curriculum book-icon circle on the trailing edge.
class TrackCardHeader extends StatelessWidget {
  const TrackCardHeader({super.key, required this.vm});

  final TrackCardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookIconBg = Color(vm.curriculumColorValue).withValues(alpha: 0.2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vm.displayNamePrimary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.brandInk,
                  letterSpacing: -0.1,
                ),
              ),
              if (vm.displayNameSecondary != null) ...[
                const SizedBox(height: 4),
                Text(
                  vm.displayNameSecondary!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.brandInk,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bookIconBg, shape: BoxShape.circle),
          child: const Icon(
            Icons.menu_book_rounded,
            color: kActiveTrackPrimaryBlue,
            size: 24,
          ),
        ),
      ],
    );
  }
}
