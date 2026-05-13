import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_card_view_model.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';

/// Breadcrumb pill that shows the next task for a [TrackCard].
///
/// The pill displays [vm.breadcrumbLabel] as the category label (e.g.
/// "NEXT TASK" or "CURRENT FOCUS") and [vm.nextTask.displayLabel] as the
/// breadcrumb text. Tapping navigates to [NextTaskData.sefariaRef] when set.
///
/// The [firstTaskInTrackForCategoryProvider] drives the navigation target
/// for each stat-grid tap — [NextTaskBreadcrumb] is the primary display
/// surface that shows whichever task the scheduler surfaced.
class NextTaskBreadcrumb extends StatelessWidget {
  const NextTaskBreadcrumb({super.key, required this.vm});

  final TrackCardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sefariaRef = vm.nextTask.sefariaRef;

    return GestureDetector(
      onTap: sefariaRef != null && sefariaRef.isNotEmpty
          ? () => context.router.push(TextDisplayRoute(sefariaRef: sefariaRef))
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: kActiveTrackFocusPillBg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Text(
                vm.breadcrumbLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: kActiveTrackPrimaryBlue,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              vm.nextTask.displayLabel,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.brandInk,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
