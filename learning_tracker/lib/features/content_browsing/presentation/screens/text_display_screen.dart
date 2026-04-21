import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/text_display_preferences.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/theme/text_styles.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/text_cache_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/text_display_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';

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

    return Scaffold(
      appBar: AppBar(title: AppBarTitle(text: sefariaRef)),
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

    return Column(
      children: [
        // Progress bar at top
        ClipRRect(
          child: LinearProgressIndicator(
            value: 0.15,
            minHeight: 3,
            backgroundColor: AppTheme.brandOutline.withValues(alpha: 0.5),
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hebrew text (RTL)
                if (textContent.hebrewText.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.brandCreamCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.brandOutline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Hebrew Text',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.brandInkMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayHebrew,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: AppTextStyles.hebrewBodyLarge.copyWith(
                            fontSize: 18 * fontSize.multiplier,
                            height: 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // English text (LTR)
                if (textContent.englishText.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.brandCreamCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.brandOutline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'English Translation',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.brandInkMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          textContent.englishText,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontSize: 16 * fontSize.multiplier,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Pinned Mark Complete button at the bottom of the screen.
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppTheme.brandCreamCard,
            border: Border(top: BorderSide(color: AppTheme.brandOutline)),
          ),
          child: _CompletionSection(sefariaRef: sefariaRef),
        ),
      ],
    );
  }
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

  Future<void> _handleComplete(DailyTask task) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final useCase = ref.read(markCompletionUseCaseProvider);
      await useCase(
        CompletionRequest(
          curriculumId: task.curriculumId.storageKey,
          sefariaRef: widget.sefariaRef,
          stageId: task.stageOrder,
          trackType: 'personal',
        ),
      );

      ref.invalidate(allDailyTasksProvider);
      ref.invalidate(dashboardStreakProvider);
      ref.invalidate(dashboardGlobalPointsProvider);
      ref.invalidate(dashboardCompletionPercentageProvider(task.curriculumId));
      ref.invalidate(dashboardLastCompletionProvider(task.curriculumId));
      ref.invalidate(progressOverviewStatsProvider);
      final profileId = ref.read(activeProfileIdProvider);
      ref.invalidate(journeyViewModelProvider(profileId));
      ref.invalidate(
        isStageCompletedProvider((
          sefariaRef: widget.sefariaRef,
          stageId: task.stageOrder,
          trackType: 'personal',
        )),
      );
      ref.invalidate(
        isStageCompletedProvider((
          sefariaRef: widget.sefariaRef,
          stageId: task.stageDefinitionId,
          trackType: 'personal',
        )),
      );

      if (mounted) {
        setState(() => _saving = false);
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
            backgroundColor: Colors.red,
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
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unable to load completion context: $e',
              style: TextStyle(fontSize: 13, color: AppTheme.brandInkMuted),
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
                color: Colors.green.withValues(alpha: 0.8),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No open stage for today — all caught up on this item.',
                  style: TextStyle(fontSize: 13, color: AppTheme.brandInkMuted),
                ),
              ),
            ],
          );
        }

        final task = matches.first;
        final isCompletedByOrderAsync = ref.watch(
          isStageCompletedProvider((
            sefariaRef: widget.sefariaRef,
            stageId: task.stageOrder,
            trackType: 'personal',
          )),
        );
        final isCompletedByDefinitionIdAsync = ref.watch(
          isStageCompletedProvider((
            sefariaRef: widget.sefariaRef,
            stageId: task.stageDefinitionId,
            trackType: 'personal',
          )),
        );
        final isDone =
            (isCompletedByOrderAsync.asData?.value ?? false) ||
            (isCompletedByDefinitionIdAsync.asData?.value ?? false);

        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_saving || isDone) ? null : () => _handleComplete(task),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: isDone ? Colors.green.shade700 : null,
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                  ),
            label: Text(
              isDone
                  ? 'Completed (${task.stageName})'
                  : 'Mark ${task.stageName} Complete',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }
}
