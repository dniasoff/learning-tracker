import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/item_review_breakdown.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/review_count_badge.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Displays a single content item in the hierarchy browser.
///
/// When the Hebrew Terms toggle is on (default), shows only the Hebrew name.
/// When off, shows the Hebrew name with the English transliteration as a
/// subtitle. Leaf items show a review count badge that updates reactively.
class ContentItemTile extends ConsumerWidget {
  const ContentItemTile({
    super.key,
    required this.item,
    required this.curriculum,
    required this.onTap,
    this.reviewCount,
  });

  final ContentItem item;
  final CurriculumId curriculum;
  final VoidCallback onTap;

  /// Pre-loaded review count from batch provider. Falls back to per-item
  /// provider if null.
  final int? reviewCount;

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

    final useHebrew = ref.watch(useHebrewTermsProvider);
    return ListTile(
      minLeadingWidth: 48,
      minVerticalPadding: 14,
      leading: _buildLeadingIcon(theme, count),
      title: CurriculumLabel.item(
        item,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        textDirection: useHebrew ? TextDirection.rtl : TextDirection.ltr,
        textAlign: TextAlign.start,
      ),
      trailing: _buildTrailing(theme, count),
      onTap: onTap,
      onLongPress: item.isLeaf && count > 0
          ? () => _showStageBreakdown(context, ref)
          : null,
    );
  }

  void _showStageBreakdown(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.brandCreamCard,
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
    final breakdownAsync = ref.watch(
      itemStageBreakdownProvider((
        curriculumId: curriculumId,
        sefariaRef: item.sefariaRef,
      )),
    );
    final db = ref.watch(userDatabaseProvider);

    return Padding(
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
                color: AppTheme.brandOutline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          CurriculumLabel.item(
            item,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.brandInk,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Review History',
            style: TextStyle(fontSize: 13, color: AppTheme.brandInkMuted),
          ),
          const SizedBox(height: 16),
          breakdownAsync.when(
            data: (breakdown) {
              if (breakdown.isEmpty) {
                return const Text(
                  'No completions yet.',
                  style: TextStyle(color: AppTheme.brandInkMuted),
                );
              }
              return FutureBuilder<Map<int, String>>(
                future: _resolveStageNames(db, curriculumId),
                builder: (context, snapshot) {
                  final names = snapshot.data ?? {};
                  return ItemReviewBreakdown(
                    stageBreakdown: breakdown,
                    stageNames: names,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              AppLocalizations.of(context)!.errorWithMessage(e.toString()),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<Map<int, String>> _resolveStageNames(
    UserDatabase db,
    String curriculumId,
  ) async {
    final stages = await db.stageDao.getStageDefinitionsByCurriculum(
      curriculumId,
    );
    return {for (final s in stages) s.id: s.stageName};
  }
}
