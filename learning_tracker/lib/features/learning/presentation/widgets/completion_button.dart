import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/optimistic_completion_provider.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/completion_animation.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/completion_feedback_controller.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';

/// Button widget for marking a content item as completed.
///
/// Shows completion animation and points popup (child mode) or
/// subtle confirmation (adult mode) upon successful completion.
/// All animations are non-blocking — user can continue immediately.
class CompletionButton extends ConsumerStatefulWidget {
  final String curriculumId;
  final String sefariaRef;
  final int stageId;
  final String trackType;
  final UserMode userMode;
  final VoidCallback? onCompleted;

  const CompletionButton({
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageId,
    required this.trackType,
    required this.userMode,
    this.onCompleted,
    super.key,
  });

  @override
  ConsumerState<CompletionButton> createState() => _CompletionButtonState();
}

class _CompletionButtonState extends ConsumerState<CompletionButton> {
  bool _isLoading = false;
  final CompletionFeedbackController _feedbackController =
      CompletionFeedbackController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  /// Default points when we don't have DB config yet (used for optimistic UI).
  int _optimisticPoints(int stageId) => switch (stageId) {
    1 => 10, // Learn
    2 => 5, // Chazara 1
    3 => 3, // Chazara 2
    _ => 1, // Additional stages
  };

  Future<void> _handleMarkComplete() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Build the optimistic key for this completion
    final optKey = optimisticKey(
      sefariaRef: widget.sefariaRef,
      stageId: widget.stageId,
      trackType: widget.trackType,
    );

    final isChildProfile = widget.userMode == UserMode.child;
    // Capture streak only for child profiles.
    final streakBefore = isChildProfile
        ? (ref.read(dashboardStreakProvider).value?.currentStreak ?? 0)
        : null;

    // --- Optimistic UI update (synchronous, < 1ms) ---
    ref.read(optimisticCompletionStateProvider.notifier).add(optKey);

    setState(() {
      _isLoading = false;
    });

    // Start feedback immediately with optimistic point values
    final optimisticPts = _optimisticPoints(widget.stageId);
    _feedbackController.start(
      CompletionFeedbackData(
        pointsAwarded: optimisticPts,
        progressBefore: 0,
        progressAfter: 0,
        streakBefore: streakBefore,
        streakAfter: streakBefore == null ? null : streakBefore + 1,
        userMode: widget.userMode,
      ),
    );

    widget.onCompleted?.call();

    // --- Background persistence (fire-and-forget with error rollback) ---
    unawaited(_persistCompletion(optKey));
  }

  /// Persists the completion to DB in the background.
  /// On failure, rolls back the optimistic state and shows a retry snackbar.
  Future<void> _persistCompletion(String optKey) async {
    try {
      final useCase = ref.read(markCompletionUseCaseProvider);
      final request = CompletionRequest(
        curriculumId: widget.curriculumId,
        sefariaRef: widget.sefariaRef,
        stageId: widget.stageId,
        trackType: widget.trackType,
      );

      final completion = await useCase(request);

      // --- Lazy provider invalidation (non-blocking) ---
      final curriculumEnum = CurriculumId.values.where(
        (c) => c.storageKey == widget.curriculumId,
      );
      if (curriculumEnum.isNotEmpty) {
        ref.invalidate(
          dashboardCompletionPercentageProvider(curriculumEnum.first),
        );
        ref.invalidate(dashboardLastCompletionProvider(curriculumEnum.first));
      }
      if (widget.userMode == UserMode.child) {
        ref.invalidate(dashboardStreakProvider);
        ref.invalidate(dashboardGlobalPointsProvider);
      }
      // Today's plan is snapshotted per local day — we don't invalidate
      // allDailyTasksProvider on completion. The task card reads completion
      // state from isStageCompletedProvider so the UI still reflects the
      // mark-done, and new items are not pulled into today's list.

      // Background: streak alert, rewards
      if (widget.userMode == UserMode.child) {
        unawaited(_postCompletionWork(completion));
      }
    } catch (e) {
      // --- Rollback optimistic state ---
      ref.read(optimisticCompletionStateProvider.notifier).remove(optKey);

      // Reset button to tappable state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _feedbackController.cancel();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Couldn't save — tap to retry"),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleMarkComplete,
            ),
          ),
        );
      }

      AppLogger.instance.error('Completion persistence failed', e);
    }
  }

  /// Background work after completion — doesn't block UI.
  Future<void> _postCompletionWork(dynamic completion) async {
    try {
      await ref.read(streakAlertServiceProvider).onCompletionRecorded();
    } catch (e) {
      // Background work failure shouldn't crash the app
      AppLogger.instance.error('Post-completion work failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompletedAsync = ref.watch(
      isStageCompletedProvider((
        sefariaRef: widget.sefariaRef,
        stageId: widget.stageId,
        trackType: widget.trackType,
      )),
    );

    final isAlreadyCompleted = isCompletedAsync.value ?? false;

    return ListenableBuilder(
      listenable: _feedbackController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ElevatedButton(
              onPressed:
                  _isLoading ||
                      _feedbackController.isActive ||
                      isAlreadyCompleted
                  ? null
                  : _handleMarkComplete,
              style: isAlreadyCompleted
                  ? ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade800,
                    )
                  : null,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : isAlreadyCompleted
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 18),
                        SizedBox(width: 4),
                        Text('Completed'),
                      ],
                    )
                  : const Text('Mark Complete'),
            ),
            // H1: IgnorePointer so animation overlay doesn't block taps
            if (_feedbackController.phase == CompletionFeedbackPhase.checkmark)
              IgnorePointer(
                child: Positioned.fill(
                  child: CompletionAnimation(
                    userMode: widget.userMode,
                    onComplete: () => _feedbackController.advance(),
                  ),
                ),
              ),
            // M2: Render AnimatedProgressBar during progressFill phase
            if (_feedbackController.phase ==
                CompletionFeedbackPhase.progressFill)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedProgressBar(
                  value: _feedbackController.data?.progressAfter ?? 0,
                  duration: const Duration(milliseconds: 600),
                  onAnimationComplete: () => _feedbackController.advance(),
                ),
              ),
          ],
        );
      },
    );
  }
}
