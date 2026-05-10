import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/theme/text_styles.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/achievement_unlock_celebration.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_terms_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class TextDisplayScreen extends ConsumerWidget {
  const TextDisplayScreen({
    super.key,
    @PathParam('sefariaRef') required this.sefariaRef,
  });

  final String sefariaRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textAsync = ref.watch(textContentProvider(sefariaRef));
    final fontSize = ref.watch(fontSizeProvider);
    final showNikud = ref.watch(showNikudProvider);
    final useHebrew = ref.watch(hebrewTermsScriptProvider);
    final theme = Theme.of(context);

    final englishTitle = sefariaRef.replaceAll('_', ' ');
    final hebrewTitle = useHebrew
        ? ref
              .watch(hebrewNameForRefProvider(sefariaRef))
              .whenOrNull(data: (he) => he)
        : null;
    final title = (hebrewTitle != null && hebrewTitle.isNotEmpty)
        ? hebrewTitle
        : englishTitle;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FC),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppTheme.brandInk,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: textAsync.when(
          data: (textContent) {
            if (textContent == null) {
              return const _OfflineMessage();
            }
            return _TextContentView(
              textContent: textContent,
              fontSize: fontSize,
              showNikud: showNikud,
              sefariaRef: sefariaRef,
            );
          },
          loading: () => const _LoadingView(),
          error: (error, stack) => _ErrorView(error: error),
        ),
      ),
    );
  }
}

/// Loading view with spinner and message.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading text...'),
        ],
      ),
    );
  }
}

/// Message shown when text is unavailable (not cached and API unreachable).
class _OfflineMessage extends StatelessWidget {
  const _OfflineMessage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Text not available',
              style: AppTextStyles.titleMedium.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your internet connection and try again.',
              style: AppTextStyles.bodySmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error view.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load text',
            style: AppTextStyles.titleMedium.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: AppTextStyles.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Main text content view redesigned as a learning reader.
class _TextContentView extends StatelessWidget {
  const _TextContentView({
    required this.textContent,
    required this.fontSize,
    required this.showNikud,
    required this.sefariaRef,
  });

  final TextContent textContent;
  final FontSize fontSize;
  final bool showNikud;
  final String sefariaRef;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayHebrew = showNikud
        ? textContent.hebrewText
        : HebrewUtils.stripNikud(textContent.hebrewText);
    final insightChips = _buildInsightChips(textContent.englishText);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 0.15,
              minHeight: 5,
              backgroundColor: AppTheme.brandOutline.withValues(alpha: 0.35),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.brandBlue,
              ),
            ),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (textContent.hebrewText.isNotEmpty) ...[
                  _ReaderSectionCard(
                    label: 'Hebrew Text',
                    labelBackground: const Color(0xFFF26666),
                    alignLabelRight: false,
                    child: Text(
                      displayHebrew,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.hebrewBodyLarge.copyWith(
                        fontSize: 26 * fontSize.multiplier,
                        height: 1.65,
                        color: const Color(0xFF1A1D24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppTheme.brandOutline.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 22,
                      color: AppTheme.brandBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Divider(
                        color: AppTheme.brandOutline.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (textContent.englishText.isNotEmpty) ...[
                  _ReaderSectionCard(
                    label: 'English Translation',
                    labelBackground: AppTheme.brandBlue,
                    alignLabelRight: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textContent.englishText,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontSize: 16 * fontSize.multiplier,
                            height: 1.55,
                            color: AppTheme.brandInk,
                          ),
                        ),
                        if (insightChips.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: insightChips
                                .map(
                                  (chip) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.brandBlueSoft.withValues(
                                        alpha: 0.55,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      chip,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: AppTheme.brandBlueDeep,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FC),
            border: Border(
              top: BorderSide(
                color: AppTheme.brandOutline.withValues(alpha: 0.4),
              ),
            ),
          ),
          child: _CompletionSection(sefariaRef: sefariaRef),
        ),
      ],
    );
  }
}

List<String> _buildInsightChips(String englishText) {
  final text = englishText.toLowerCase();
  final chips = <String>[];
  if (text.contains('priest')) chips.add('Vocabulary: Priests');
  if (text.contains('time') || text.contains('watch')) {
    chips.add('Concept: Time');
  }
  return chips.take(2).toList();
}

class _ReaderSectionCard extends StatelessWidget {
  const _ReaderSectionCard({
    required this.label,
    required this.labelBackground,
    required this.child,
    this.alignLabelRight = false,
  });

  final String label;
  final Color labelBackground;
  final Widget child;
  final bool alignLabelRight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
          decoration: BoxDecoration(
            color: AppTheme.brandCreamCard,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandInk.withValues(alpha: 0.04),
                blurRadius: 11,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppTheme.brandOutline.withValues(alpha: 0.45),
            ),
          ),
          child: child,
        ),
        Positioned(
          top: -12,
          left: alignLabelRight ? null : 0,
          right: alignLabelRight ? 0 : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: labelBackground,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: labelBackground.withValues(alpha: 0.26),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Next distinct daily-task item in [tasks] after any entries that share
/// [currentRef] (same reader URL).
DailyTask? _nextDailyTaskAfter(List<DailyTask> tasks, String currentRef) {
  final firstIdx = tasks.indexWhere(
    (t) => t.contentItemSefariaRef == currentRef,
  );
  if (firstIdx < 0) return null;
  var i = firstIdx;
  while (i < tasks.length && tasks[i].contentItemSefariaRef == currentRef) {
    i++;
  }
  if (i >= tasks.length) return null;
  return tasks[i];
}

/// Mark completion section. Resolves the curriculum + stage for this sefariaRef
/// from today's scheduled tasks, then records the completion directly via
/// [markCompletionUseCaseProvider] and invalidates dashboard providers so
/// progress, streak, points, and daily tasks all refresh.
class _CompletionSection extends ConsumerStatefulWidget {
  const _CompletionSection({required this.sefariaRef});

  final String sefariaRef;

  @override
  ConsumerState<_CompletionSection> createState() => _CompletionSectionState();
}

class _CompletionSectionState extends ConsumerState<_CompletionSection> {
  bool _saving = false;

  Future<void> _handleComplete(DailyTask task, String trackType) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final tasksBefore = await ref.read(allDailyTasksProvider.future);
      final nextAfterComplete = _nextDailyTaskAfter(
        tasksBefore,
        widget.sefariaRef,
      );

      final useCase = ref.read(markCompletionUseCaseProvider);
      final result = await useCase(
        CompletionRequest(
          curriculumId: task.curriculumId.storageKey,
          sefariaRef: widget.sefariaRef,
          stageId: task.stageOrder,
          trackType: trackType,
        ),
      );

      final profileId = ref.read(activeProfileIdProvider);
      ref.invalidate(allDailyTasksProvider);
      ref.invalidate(dashboardStreakProvider);
      ref.invalidate(dashboardGlobalPointsProvider);
      ref.invalidate(dashboardCompletionPercentageProvider(task.curriculumId));
      ref.invalidate(dashboardLastCompletionProvider(task.curriculumId));
      ref.invalidate(dashboardPaceStatusProvider(task.curriculumId));
      ref.invalidate(dashboardChildNextRewardProvider);
      ref.invalidate(lifetimeTotalsAcrossAllCurriculaProvider(profileId));
      ref.invalidate(globalLifetimeCurriculaProvider(profileId));
      ref.invalidate(progressOverviewStatsProvider);
      ref.invalidate(journeyViewModelProvider(profileId));
      ref.invalidate(achievementsOverviewProvider);
      ref.invalidate(
        isStageCompletedProvider((
          sefariaRef: widget.sefariaRef,
          stageId: task.stageOrder,
          trackType: trackType,
        )),
      );
      ref.invalidate(
        isStageCompletedProvider((
          sefariaRef: widget.sefariaRef,
          stageId: task.stageDefinitionId,
          trackType: trackType,
        )),
      );

      if (mounted) {
        setState(() => _saving = false);
      }

      if (mounted) {
        final userMode = ref.read(dashboardUserModeProvider).asData?.value;
        if (userMode == UserMode.child &&
            result.newMilestoneUnlocks.isNotEmpty) {
          await AchievementUnlockCelebration.showForUnlockedMilestones(
            context: context,
            ref: ref,
            newUnlocks: result.newMilestoneUnlocks,
          );
        }
      }

      if (mounted && nextAfterComplete != null) {
        await context.router.replace(
          TextDisplayRoute(sefariaRef: nextAfterComplete.contentItemSefariaRef),
        );
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked complete'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, st) {
      AppLogger.instance.error('Failed to mark completion', e, st);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Couldn't save: $e"),
            backgroundColor: AppTheme.brandCoralDeep,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyTasksAsync = ref.watch(allDailyTasksProvider);

    return dailyTasksAsync.when(
      loading: () => const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.brandCoralDeep,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unable to load completion context: $e',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.brandInkMuted,
              ),
            ),
          ),
        ],
      ),
      data: (tasks) {
        final matches = tasks.where(
          (t) => t.contentItemSefariaRef == widget.sefariaRef,
        );
        if (matches.isEmpty) {
          return Row(
            children: [
              Icon(
                Icons.check_circle,
                color: AppTheme.brandGold.withValues(alpha: 0.8),
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No open stage for today — all caught up on this item.',
                  style: TextStyle(fontSize: 13, color: AppTheme.brandInkMuted),
                ),
              ),
            ],
          );
        }

        final task = matches.first;
        final nextTask = _nextDailyTaskAfter(tasks, widget.sefariaRef);
        final trackTypeAsync = ref.watch(
          trackStorageKeyForTrackIdProvider(task.trackId),
        );
        return trackTypeAsync.when(
          loading: () => const SizedBox(
            height: 44,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (trackType) {
            final isCompletedByOrderAsync = ref.watch(
              isStageCompletedProvider((
                sefariaRef: widget.sefariaRef,
                stageId: task.stageOrder,
                trackType: trackType,
              )),
            );
            final isCompletedByDefinitionIdAsync = ref.watch(
              isStageCompletedProvider((
                sefariaRef: widget.sefariaRef,
                stageId: task.stageDefinitionId,
                trackType: trackType,
              )),
            );
            final isDone =
                (isCompletedByOrderAsync.asData?.value ?? false) ||
                (isCompletedByDefinitionIdAsync.asData?.value ?? false);

            final nextLabel =
                AppLocalizations.of(context)?.textReaderNextDailyTask ??
                'Next daily task';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: (_saving || isDone)
                      ? null
                      : () => _handleComplete(task, trackType),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDone
                        ? AppTheme.brandGoldDeep
                        : AppTheme.brandBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_saving)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.brandCreamCard,
                          ),
                        )
                      else
                        Icon(
                          isDone
                              ? Icons.check_circle
                              : Icons.check_circle_outline_rounded,
                          size: 20,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        isDone
                            ? 'Completed (${task.stageName})'
                            : 'Mark Complete',
                        style: const TextStyle(
                          fontSize: 31 / 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (nextTask != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.router.replace(
                      TextDisplayRoute(
                        sefariaRef: nextTask.contentItemSefariaRef,
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: Text(
                      nextLabel,
                      style: const TextStyle(
                        fontSize: 31 / 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.brandBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      side: BorderSide(
                        color: AppTheme.brandBlue.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
