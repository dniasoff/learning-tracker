import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/curriculum_breakdown_list.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Source toggle for the Lifetime Knowledge tree.
///
/// "All sources" includes lifetimeOnly historical imports (B1 lifetime tier).
/// "Track only" restricts the view to live + bulkInTrack rows so the user can
/// answer the narrower "what did I do inside a track?" question — same data
/// surface as the retired Items Learned screen.
enum _LifetimeSourceFilter { allSources, trackOnly }

/// Lifetime-tier lens screen.
///
/// Replaces the retired Items Learned + Lifetime View screens with a single
/// toggleable surface. The header carries two lifetime-tier counters (items
/// learned, total chazaros), the body is the per-curriculum tree (reusing
/// [CurriculumBreakdownList]), and the footer surfaces the existing
/// Lifetime Marking CTA so the "I learned this years ago" flow becomes
/// discoverable outside of Settings.
///
/// See `docs/planning/progress-ia-redesign.md` §5 for the full spec.
@RoutePage()
class LifetimeKnowledgeScreen extends ConsumerStatefulWidget {
  const LifetimeKnowledgeScreen({super.key});

  @override
  ConsumerState<LifetimeKnowledgeScreen> createState() =>
      _LifetimeKnowledgeScreenState();
}

class _LifetimeKnowledgeScreenState
    extends ConsumerState<LifetimeKnowledgeScreen> {
  /// Local-state toggle — persisted across rebuilds but not across screen
  /// navigations (no provider yet; revisit when the toggle needs to drive
  /// other screens too).
  _LifetimeSourceFilter _filter = _LifetimeSourceFilter.allSources;

  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider);
    final l10n = AppLocalizations.of(context)!;
    final baseTheme = Theme.of(context);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme);

    final summariesAsync = _filter == _LifetimeSourceFilter.allSources
        ? ref.watch(lifetimeViewSummariesProvider(profileId))
        : ref.watch(itemsLearnedSummariesProvider(profileId));

    // F3: header counters must follow the source toggle. The "All sources"
    // branch reads the lifetime-tier union; the "Track only" branch reads
    // the same trackAchievement-filtered surface the body uses, so the
    // numbers on top match the per-curriculum tree below.
    final headerAsync = _filter == _LifetimeSourceFilter.allSources
        ? ref.watch(lifetimeHeaderCountersProvider(profileId))
        : ref.watch(trackOnlyHeaderCountersProvider(profileId));

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.brandInk,
        title: Text(
          l10n.tierLensLifetimeKnowledge,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.brandInk,
          ),
        ),
      ),
      body: Theme(
        data: baseTheme.copyWith(textTheme: textTheme),
        child: Column(
          children: [
            // Header counters card.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _LifetimeHeaderCard(
                headerAsync: headerAsync,
                onRetry: () {
                  if (_filter == _LifetimeSourceFilter.allSources) {
                    ref.invalidate(lifetimeHeaderCountersProvider(profileId));
                  } else {
                    ref.invalidate(trackOnlyHeaderCountersProvider(profileId));
                  }
                },
              ),
            ),
            // Source toggle.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _LifetimeSourceToggle(
                filter: _filter,
                onChanged: (next) => setState(() => _filter = next),
              ),
            ),
            // Per-curriculum tree.
            Expanded(
              child: summariesAsync.when(
                data: (summaries) {
                  final withProgress =
                      summaries.where((s) => s.learnedLeafCount > 0).toList()
                        ..sort(
                          (a, b) => a.curriculumId.index.compareTo(
                            b.curriculumId.index,
                          ),
                        );

                  if (withProgress.isEmpty) {
                    return EmptyState(
                      message: l10n.itemsLearnedNoCurricula,
                      subtitle: l10n.itemsLearnedNoCurriculaSubtitle,
                      icon: Icons.menu_book_outlined,
                    );
                  }
                  return CurriculumBreakdownList(
                    summaries: withProgress,
                    showProvenance: true,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorDisplay(
                    message: l10n.lifetimeKnowledgeLoadError,
                    onRetry: () {
                      if (_filter == _LifetimeSourceFilter.allSources) {
                        ref.invalidate(
                          lifetimeViewSummariesProvider(profileId),
                        );
                      } else {
                        ref.invalidate(
                          itemsLearnedSummariesProvider(profileId),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
            // CTA — navigate to Lifetime Marking (existing settings flow).
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _LifetimeMarkingCta(
                  onTap: () =>
                      context.router.push(const LifetimeMarkingRoute()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header card with the two lifetime-tier counters.
class _LifetimeHeaderCard extends ConsumerWidget {
  const _LifetimeHeaderCard({required this.headerAsync, required this.onRetry});

  final AsyncValue<LifetimeHeaderCounters> headerAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final terms = domainTermLabels(ref);
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.brandOutline.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: headerAsync.when(
          data: (counters) => Row(
            children: [
              const Icon(
                Icons.menu_book_outlined,
                color: AppTheme.brandBlue,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      terms.itemsLearnedCount(counters.itemsLearned),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.brandInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      terms.totalChazaros(counters.totalChazaros),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.brandInkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: LoadingIndicator(size: 24)),
          ),
          error: (error, _) => Row(
            children: [
              Expanded(
                child: Text(
                  l10n.lifetimeKnowledgeCounterError,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: onRetry,
                child: Text(l10n.lifetimeKnowledgeRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pair of segmented buttons that flip [_LifetimeSourceFilter].
class _LifetimeSourceToggle extends StatelessWidget {
  const _LifetimeSourceToggle({required this.filter, required this.onChanged});

  final _LifetimeSourceFilter filter;
  final ValueChanged<_LifetimeSourceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<_LifetimeSourceFilter>(
      segments: [
        ButtonSegment(
          value: _LifetimeSourceFilter.allSources,
          label: Text(l10n.lifetimeKnowledgeToggleAllSources),
          icon: const Icon(Icons.public_outlined),
        ),
        ButtonSegment(
          value: _LifetimeSourceFilter.trackOnly,
          label: Text(l10n.lifetimeKnowledgeToggleTrackOnly),
          icon: const Icon(Icons.school_outlined),
        ),
      ],
      selected: {filter},
      onSelectionChanged: (selection) => onChanged(selection.first),
      multiSelectionEnabled: false,
      showSelectedIcon: false,
    );
  }
}

/// Bottom CTA card linking to the existing Lifetime Marking screen.
class _LifetimeMarkingCta extends StatelessWidget {
  const _LifetimeMarkingCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: AppTheme.brandCreamCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                color: AppTheme.brandBlue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.lifetimeKnowledgeAddCta,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.brandInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.lifetimeKnowledgeAddCtaSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.brandInkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.brandInkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
