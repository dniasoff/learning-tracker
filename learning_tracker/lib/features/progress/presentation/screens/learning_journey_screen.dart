import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/journey_grouped_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/journey_timeline_view.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class LearningJourneyScreen extends ConsumerWidget {
  const LearningJourneyScreen({
    super.key,
    @QueryParam('profileId') this.profileId,
  });

  final int? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final activeProfileId = ref.watch(activeProfileIdProvider);
    final effectiveProfileId = profileId ?? activeProfileId;
    final journeyAsync = ref.watch(
      journeyViewModelProvider(effectiveProfileId),
    );
    final sortMode = ref.watch(journeySortModeProvider);

    // Get profile name for AppBar when viewing another profile
    final isViewingOther = profileId != null && profileId != activeProfileId;
    final profileAsync = isViewingOther
        ? ref.watch(profileByIdProvider(profileId!))
        : null;
    final profileName = profileAsync?.asData?.value?.displayName;
    final title = profileName != null
        ? l10n.journeyTitleNamed(profileName)
        : l10n.myLearningJourney;

    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: title)),
      body: SafeArea(
        top: false,
        child: journeyAsync.when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => ErrorDisplay(
            message: l10n.failedToLoadJourney(error.toString()),
            onRetry: () =>
                ref.invalidate(journeyViewModelProvider(effectiveProfileId)),
          ),
          data: (viewModel) {
            if (_isEmpty(viewModel)) {
              return const _EmptyState();
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
                      segments: [
                        ButtonSegment(
                          value: JourneySortModeValue.grouped,
                          label: Text(l10n.journeyByCurriculum),
                          icon: const Icon(Icons.grid_view),
                        ),
                        ButtonSegment(
                          value: JourneySortModeValue.chronological,
                          label: Text(l10n.journeyTimeline),
                          icon: const Icon(Icons.timeline),
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
        ),
      ),
    );
  }

  bool _isEmpty(JourneyViewModel viewModel) {
    return viewModel.totalCompletions == 0;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_stories,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.journeyEmptyTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.journeyEmptyBody,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
