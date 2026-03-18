import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/journey_grouped_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/journey_timeline_view.dart';

@RoutePage()
class LearningJourneyScreen extends ConsumerWidget {
  const LearningJourneyScreen({
    super.key,
    @QueryParam('profileId') this.profileId,
  });

  final int? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfileId = ref.watch(activeProfileIdProvider);
    final effectiveProfileId = profileId ?? activeProfileId;
    final journeyAsync = ref.watch(journeyViewModelProvider(effectiveProfileId));
    final sortMode = ref.watch(journeySortModeProvider);

    // Get profile name for AppBar when viewing another profile
    final isViewingOther = profileId != null && profileId != activeProfileId;
    final profileAsync = isViewingOther
        ? ref.watch(selectedProfileProvider)
        : null;
    final profileName = profileAsync?.asData?.value?.displayName;
    final title = profileName != null
        ? "$profileName's Learning Journey"
        : 'My Learning Journey';

    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: title)),
      body: SafeArea(top: false, child: journeyAsync.when(
        loading: () => const LoadingIndicator(
          message: 'Loading your journey...',
        ),
        error: (error, _) => ErrorDisplay(
          message: 'Failed to load journey: $error',
          onRetry: () => ref.invalidate(
            journeyViewModelProvider(effectiveProfileId),
          ),
        ),
        data: (viewModel) {
          if (_isEmpty(viewModel)) {
            return _EmptyState(
              onStartLearning: () => context.router.push(
                const DashboardRoute(),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(journeyViewModelProvider(effectiveProfileId));
            },
            child: Column(
              children: [
                // View toggle
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SegmentedButton<JourneySortModeValue>(
                    segments: const [
                      ButtonSegment(
                        value: JourneySortModeValue.grouped,
                        label: Text('By Curriculum'),
                        icon: Icon(Icons.grid_view),
                      ),
                      ButtonSegment(
                        value: JourneySortModeValue.chronological,
                        label: Text('Timeline'),
                        icon: Icon(Icons.timeline),
                      ),
                    ],
                    selected: {sortMode},
                    onSelectionChanged: (selected) {
                      ref
                          .read(journeySortModeProvider.notifier)
                          .setMode(selected.first);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Content
                Expanded(
                  child: sortMode == JourneySortModeValue.grouped
                      ? JourneyGroupedView(viewModel: viewModel)
                      : JourneyTimelineView(viewModel: viewModel),
                ),
              ],
            ),
          );
        },
      )),
    );
  }

  bool _isEmpty(JourneyViewModel viewModel) {
    return viewModel.totalCompletions == 0;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStartLearning});

  final VoidCallback onStartLearning;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'Your learning journey starts here!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Complete your first masechta to see it recorded forever.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onStartLearning,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Learning'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
