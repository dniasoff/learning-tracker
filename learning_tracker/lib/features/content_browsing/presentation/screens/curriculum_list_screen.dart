import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class CurriculumListScreen extends ConsumerWidget {
  const CurriculumListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          child: Text(
            l10n.curriculumListTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              letterSpacing: -0.2,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.curriculumListSearchTooltip,
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.brandOutline),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: context.colors.brandInkMuted,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    l10n.curriculumListSearchHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.brandInkMuted,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section header
          Text(
            l10n.curriculumListSectionCurricula,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.brandInkMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Curriculum cards
          ...CurriculumId.values.map(
            (curriculum) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CurriculumCard(curriculum: curriculum),
            ),
          ),

          const SizedBox(height: 24),

          // Recent Activity section
          Text(
            l10n.curriculumListSectionRecentActivity,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.brandInkMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const _RecentActivityPlaceholder(),
        ],
      ),
    );
  }
}

class _CurriculumCard extends ConsumerWidget {
  const _CurriculumCard({required this.curriculum});

  final CurriculumId curriculum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(curriculumContentProvider(curriculum));
    final completionAsync = ref.watch(
      dashboardCompletionPercentageProvider(curriculum),
    );
    final curriculumColor = context.colors.curriculumFor(curriculum);
    final percentage = completionAsync.value;
    final pctDisplay = completionAsync.hasValue
        ? formatFractionAsPercent(percentage!)
        : '';

    return contentAsync.when(
      data: (items) {
        final leafCount = items.where((item) => item.isLeaf).length;
        final containerCount = items.where((item) => !item.isLeaf).length;

        return _buildCard(
          context: context,
          ref: ref,
          curriculumColor: curriculumColor,
          pctDisplay: pctDisplay,
          percentage: percentage,
          leafCount: leafCount,
          containerCount: containerCount,
          completionLoading: completionAsync.isLoading,
          completionError: completionAsync.error,
          onRetryCompletion: () =>
              ref.invalidate(dashboardCompletionPercentageProvider(curriculum)),
        );
      },
      loading: () => _buildCard(
        context: context,
        ref: ref,
        curriculumColor: curriculumColor,
        pctDisplay: pctDisplay,
        percentage: percentage,
        completionLoading: completionAsync.isLoading,
        completionError: completionAsync.error,
        onRetryCompletion: () =>
            ref.invalidate(dashboardCompletionPercentageProvider(curriculum)),
      ),
      error: (_, __) => _buildCard(
        context: context,
        ref: ref,
        curriculumColor: curriculumColor,
        pctDisplay: pctDisplay,
        percentage: percentage,
        completionLoading: completionAsync.isLoading,
        completionError: completionAsync.error,
        onRetryCompletion: () =>
            ref.invalidate(dashboardCompletionPercentageProvider(curriculum)),
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required WidgetRef ref,
    required Color curriculumColor,
    required String pctDisplay,
    required double? percentage,
    int leafCount = 0,
    int containerCount = 0,
    bool completionLoading = false,
    Object? completionError,
    VoidCallback? onRetryCompletion,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () {
        context.router.push(
          ContentHierarchyRoute(curriculumId: curriculum.storageKey),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              curriculumColor.withValues(alpha: 0.35),
              curriculumColor.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: curriculumColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CurriculumLabel.curriculum(
                        curriculum,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.colors.brandInk,
                        ),
                      ),
                      if (!domainTermLabels(ref).isHebrew) ...[
                        const SizedBox(height: 4),
                        Text(
                          curriculumHebrewName(curriculum),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: context.colors.brandInkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (completionError != null)
                  InlineAsyncError(
                    error: completionError,
                    onRetry: onRetryCompletion,
                  )
                else if (completionLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (percentage != null && percentage > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.brandCreamSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: curriculumColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.curriculumListPercentDone(pctDisplay),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colors.brandInk,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.brandGoldSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.curriculumListNewBadge,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.brandGoldDeep,
                      ),
                    ),
                  ),
              ],
            ),
            if (completionError == null &&
                percentage != null &&
                percentage > 0) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 4,
                  backgroundColor: context.colors.brandOutline.withValues(
                    alpha: 0.5,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(curriculumColor),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (containerCount > 0) ...[
                  Text(
                    '$containerCount ${CurriculumLabels.containerCountLabel(curriculum, useHebrew: domainTermLabels(ref).isHebrew, variant: ref.watch(currentTransliterationVariantProvider))}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.brandInkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (leafCount > 0)
                  Text(
                    '$leafCount ${CurriculumLabels.primaryUnitLabel(curriculum, useHebrew: domainTermLabels(ref).isHebrew, variant: ref.watch(currentTransliterationVariantProvider))}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.brandInkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityPlaceholder extends StatelessWidget {
  const _RecentActivityPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.brandOutline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.brandGoldSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.history,
              color: context.colors.brandGoldDeep,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.curriculumListActivityEmptyTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colors.brandInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.curriculumListActivityEmptySubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.brandInkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
