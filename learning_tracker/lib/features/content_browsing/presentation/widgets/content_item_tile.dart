import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/item_review_breakdown.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/review_count_badge.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Displays a single content item in the hierarchy browser.
///
/// When the Hebrew Terms toggle is on (default), shows only the Hebrew name.
/// When off, shows the Hebrew name with the English transliteration as a
/// subtitle. Leaf items show a review count badge that updates reactively.
///
/// [showReviewBadge] guards the [ReviewCountBadge] per the chazara product
/// rule: the badge is review/chazara-specific and MUST NOT render when the
/// viewing context has no track with chazara enabled.  Defaults to `true` so
/// that call sites that don't yet know the track context (e.g. cross-track
/// search) are conservative rather than silent.
class ContentItemTile extends ConsumerWidget {
  const ContentItemTile({
    super.key,
    required this.item,
    required this.curriculum,
    required this.onTap,
    this.reviewCount,
    this.showReviewBadge = true,
    this.showBreadcrumb = false,
  });

  final ContentItem item;
  final CurriculumId curriculum;
  final VoidCallback onTap;

  /// Pre-loaded review count from batch provider. Falls back to per-item
  /// provider if null.
  final int? reviewCount;

  /// Whether the review count badge should be shown for this context.
  ///
  /// Pass `false` when the viewing track (or any active track in the
  /// curriculum) does not have chazara enabled.  Hiding the badge prevents
  /// confusing "1x" indicators on learn-only tracks.
  final bool showReviewBadge;

  /// Whether to show a parent breadcrumb as the subtitle.
  ///
  /// Enable in search contexts where multiple items share the same display
  /// name (e.g. "משנה ו") and the parent path is needed for disambiguation.
  /// Defaults to `false` for the hierarchy browser where the position in the
  /// drill path already supplies parent context.
  final bool showBreadcrumb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Use batch-loaded count if available, otherwise watch per-item provider.
    final count =
        reviewCount ??
        ref
            .watch(
              completionCountProvider(
                curriculumId: curriculum.storageKey,
                sefariaRef: item.sefariaRef,
              ),
            )
            .value ??
        0;

    return ListTile(
      minLeadingWidth: 48,
      minVerticalPadding: 14,
      leading: _buildLeadingIcon(theme, count),
      title: CurriculumLabel.item(
        item,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.start,
      ),
      subtitle: showBreadcrumb
          ? CurriculumLabel.parent(
              item.sefariaRef,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: _buildTrailing(theme, count),
      onTap: onTap,
      onLongPress: item.isLeaf && count > 0 && showReviewBadge
          ? () => _showStageBreakdown(context, ref)
          : null,
    );
  }

  void _showStageBreakdown(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      // Scroll-controlled so the sheet can grow with its content and the
      // _StageBreakdownSheet's internal SingleChildScrollView gets a bounded
      // height to scroll within (capped at 80% of screen) instead of
      // overflowing on short screens or with large text.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _StageBreakdownSheet(curriculumId: curriculum.storageKey, item: item),
    );
  }

  Widget _buildLeadingIcon(ThemeData theme, int completionCount) {
    if (item.isLeaf) {
      final isCompleted = completionCount > 0;
      return Icon(
        isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isCompleted
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      );
    } else {
      return Icon(Icons.folder, color: theme.colorScheme.primary, size: 32);
    }
  }

  Widget? _buildTrailing(ThemeData theme, int completionCount) {
    if (item.isLeaf) {
      // AC-4: Show review count badge; AC-6: hidden when 0.
      // Chazara rule: badge is review-specific — suppress it when the
      // viewing track context has no chazara enabled.
      if (!showReviewBadge) return null;
      return ReviewCountBadge(count: completionCount);
    } else {
      return Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      );
    }
  }
}

/// Widget showing per-stage completion status for a leaf item.
class StageCompletionIndicators extends StatelessWidget {
  const StageCompletionIndicators({super.key, required this.stages});

  final Map<int, bool> stages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: stages.entries.map((entry) {
        final isComplete = entry.value;
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Icon(
            isComplete ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isComplete
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        );
      }).toList(),
    );
  }
}

/// Widget showing aggregate completion percentage for a container.
class AggregateCompletionIndicator extends StatelessWidget {
  const AggregateCompletionIndicator({super.key, required this.percentage});

  final double percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${percentage.toStringAsFixed(0)}%',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 40,
          height: 4,
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet showing per-stage breakdown for a content item (AC-5).
class _StageBreakdownSheet extends ConsumerWidget {
  const _StageBreakdownSheet({required this.curriculumId, required this.item});

  final String curriculumId;
  final ContentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final breakdownAsync = ref.watch(
      itemStageBreakdownProvider((
        curriculumId: curriculumId,
        sefariaRef: item.sefariaRef,
      )),
    );
    final curriculumEnum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == curriculumId,
      orElse: () => CurriculumId.mishnayos,
    );
    final stageRepository = ref.watch(
      stageDefinitionRepositoryProvider(curriculumEnum),
    );
    final terms = domainTermLabels(ref);
    final media = MediaQuery.of(context);

    // Bound the sheet to 80% of the screen height (minus the keyboard) and make
    // its body scrollable so a long breakdown — or large accessibility text —
    // scrolls within the sheet instead of overflowing.
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (media.size.height - media.viewInsets.bottom) * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.brandOutline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CurriculumLabel.item(
                item,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.colors.brandInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.stageBreakdownReviewHistoryTitle,
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.brandInkMuted,
                ),
              ),
              const SizedBox(height: 16),
              breakdownAsync.when(
                data: (breakdown) {
                  if (breakdown.isEmpty) {
                    return Text(
                      l10n.noCompletionsYet,
                      style: TextStyle(color: context.colors.brandInkMuted),
                    );
                  }
                  return FutureBuilder<Map<int, String>>(
                    future: _resolveStageNames(stageRepository, curriculumEnum),
                    builder: (context, snapshot) {
                      final rawNames = snapshot.data ?? {};
                      // Resolve each stored name through the toggle-aware resolver
                      // so the breakdown re-renders live when the Hebrew Terms
                      // toggle changes.
                      final names = {
                        for (final entry in rawNames.entries)
                          entry.key: terms.resolveStoredStageName(entry.value),
                      };
                      return ItemReviewBreakdown(
                        stageBreakdown: breakdown,
                        stageNames: names,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => AppErrorView(
                  error: e,
                  stackTrace: st,
                  onRetry: () => ref.refresh(
                    itemStageBreakdownProvider((
                      curriculumId: curriculumId,
                      sefariaRef: item.sefariaRef,
                    )),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<int, String>> _resolveStageNames(
    StageDefinitionRepository stageRepository,
    CurriculumId curriculumId,
  ) async {
    final stages = await stageRepository.getStagesForCurriculum(curriculumId);
    return {for (final s in stages) s.stageOrder: s.stageName};
  }
}
