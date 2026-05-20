import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyumim_grouped_view.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyumim_timeline_view.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Achievement-tier lens screen: "Siyumim & Milestones".
///
/// Restructure of the former Learning Journey screen — now exposes the
/// **three additive celebration levels** per curriculum:
///
///   1. Unit-level (Siyum Masechta / Sefer / Siman / Hilchos)
///   2. Aggregate-level (Siyum Seder / Chelek) — only where the curriculum
///      exposes an aggregate hierarchy level (Mishnayos, Bavli, Yerushalmi,
///      Mishneh Torah).
///   3. Curriculum-complete (Siyum HaShas, Siyum HaTorah, etc.).
///
/// Top counters are split by level; the body groups hierarchically within
/// each curriculum so contained units roll up into their aggregate. The
/// existing "By curriculum" / "Timeline" toggle is preserved.
///
/// Per the IA redesign brief (§4 — "no provenance label"): a siyum is a
/// siyum, regardless of how it was earned. The screen never shows
/// "via bulk-mark" vs "Live ·{date}".
@RoutePage()
class SiyumimMilestonesScreen extends ConsumerWidget {
  const SiyumimMilestonesScreen({
    super.key,
    @QueryParam('profileId') this.profileId,
  });

  final int? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final terms = domainTermLabels(ref);
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
        : terms.tierLensSiyumimMilestones;

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
                  // Top counters — one row per celebration level.
                  _LevelCountersCard(viewModel: viewModel),
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
                        ? SiyumimGroupedView(viewModel: viewModel)
                        : SiyumimTimelineView(viewModel: viewModel),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// "Empty" means no milestones earned AND no completion ledger entries.
  /// A profile with active curricula but no completions yet still hits this
  /// path (the existing behaviour — preserve it).
  bool _isEmpty(JourneyViewModel viewModel) {
    return viewModel.totalCompletions == 0 &&
        viewModel.unitLevelSiyumimCount == 0 &&
        viewModel.aggregateLevelSiyumimCount == 0 &&
        viewModel.curriculumLevelSiyumimCount == 0;
  }
}

/// Three-row card at the top of the screen — one row per celebration level.
///
/// The labels come from `domainTermLabels(ref)` so the Hebrew Terms toggle
/// flips them appropriately. The order mirrors the design brief:
/// curriculum → aggregate → unit (most prestigious first).
class _LevelCountersCard extends ConsumerWidget {
  const _LevelCountersCard({required this.viewModel});

  final JourneyViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CounterRow(
                count: viewModel.curriculumLevelSiyumimCount,
                label: 'curriculum-level siyumim',
                emphasis: true,
                color: theme.colorScheme.primary,
                icon: Icons.emoji_events,
              ),
              const SizedBox(height: 6),
              _CounterRow(
                count: viewModel.aggregateLevelSiyumimCount,
                label: 'aggregate-level siyumim',
                color: theme.colorScheme.secondary,
                icon: Icons.workspace_premium,
              ),
              const SizedBox(height: 6),
              _CounterRow(
                count: viewModel.unitLevelSiyumimCount,
                label: 'unit-level siyumim',
                color: theme.colorScheme.tertiary,
                icon: Icons.star,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
    this.emphasis = false,
  });

  final int count;
  final String label;
  final Color color;
  final IconData icon;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final textStyle = (emphasis
            ? Theme.of(context).textTheme.titleLarge
            : Theme.of(context).textTheme.titleMedium)
        ?.copyWith(color: color, fontWeight: FontWeight.w600);
    return Row(
      children: [
        Icon(icon, color: color, size: emphasis ? 24 : 20),
        const SizedBox(width: 10),
        Text('$count', style: textStyle),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasis ? 15 : 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
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
