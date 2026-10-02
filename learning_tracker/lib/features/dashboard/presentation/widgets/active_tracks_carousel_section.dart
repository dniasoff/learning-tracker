import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/active_track_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/arrow_button.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The active-tracks carousel. Its visible page is the curriculum in view
/// ([dashboardCurriculumInViewProvider]), whose streak the dashboard shows
/// (DNI-479, AD-40).
class ActiveTracksCarouselSection extends ConsumerStatefulWidget {
  const ActiveTracksCarouselSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.activeTracks,
    required this.allTasks,
    required this.titleStyle,
  });

  final String title;
  final String subtitle;
  final List<CurriculumTrackEntity> activeTracks;
  final List<DailyTask> allTasks;
  final TextStyle titleStyle;

  @override
  ConsumerState<ActiveTracksCarouselSection> createState() =>
      _ActiveTracksCarouselSectionState();
}

class _ActiveTracksCarouselSectionState
    extends ConsumerState<ActiveTracksCarouselSection> {
  late final PageController _controller;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    // Open on the curriculum already in view, so the streak shown and the
    // visible track agree when the dashboard is rebuilt.
    final inView = ref.read(dashboardCurriculumInViewProvider);
    final index = widget.activeTracks.indexWhere(
      (t) => t.curriculumId == inView,
    );
    _activeIndex = index < 0 ? 0 : index;
    _controller = PageController(initialPage: _activeIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: widget.titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.brandInkMuted,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ArrowButton(
              icon: Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              isEnabled: _activeIndex > 0,
              semanticLabel: l10n.activeTracksPreviousTrack,
              onTap: _activeIndex > 0
                  ? () {
                      _controller.previousPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  : null,
            ),
            const SizedBox(width: 6),
            ArrowButton(
              icon: Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              isEnabled: _activeIndex < widget.activeTracks.length - 1,
              semanticLabel: l10n.activeTracksNextTrack,
              onTap: _activeIndex < widget.activeTracks.length - 1
                  ? () {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.activeTracks.length,
            onPageChanged: (value) {
              setState(() {
                _activeIndex = value;
              });
              ref
                  .read(dashboardCurriculumInViewProvider.notifier)
                  .show(widget.activeTracks[value].curriculumId);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ActiveTrackCard(
                  track: widget.activeTracks[index],
                  allTasks: widget.allTasks,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
