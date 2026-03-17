import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/completion_animation.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/completion_feedback_controller.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/points_popup.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/notification_providers.dart';
import 'package:learning_tracker/features/notifications/presentation/providers/reward_milestone_providers.dart';

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

  Future<void> _handleMarkComplete() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Capture progress before completion
      final curriculumEnum = CurriculumId.values.where(
        (c) => c.storageKey == widget.curriculumId,
      );
      final progressBefore = curriculumEnum.isNotEmpty
          ? (await ref.read(
              dashboardCompletionPercentageProvider(
                curriculumEnum.first,
              ).future,
            ))
          : 0.0;

      // Capture streak before completion
      final streakData = ref.read(dashboardStreakProvider).value;
      final streakBefore = streakData?.currentStreak ?? 0;

      final useCase = ref.read(markCompletionUseCaseProvider);
      final request = CompletionRequest(
        curriculumId: widget.curriculumId,
        sefariaRef: widget.sefariaRef,
        stageId: widget.stageId,
        trackType: widget.trackType,
      );

      final completion = await useCase(request);

      // Cancel streak alert since user completed learning today
      await ref.read(streakAlertServiceProvider).onCompletionRecorded();

      // Invalidate and re-read progress/streak after completion
      if (curriculumEnum.isNotEmpty) {
        ref.invalidate(
          dashboardCompletionPercentageProvider(curriculumEnum.first),
        );
      }
      ref.invalidate(dashboardStreakProvider);

      // Check if any rewards were earned after points changed
      final rewardService = ref.read(rewardServiceProvider);
      final newlyEarned = await checkAndAwardRewards(
        rewardService,
        userMode: widget.userMode,
      );

      // Fire instant notification for each newly earned reward
      if (newlyEarned.isNotEmpty) {
        final milestoneService = ref.read(
          rewardMilestoneNotificationServiceProvider,
        );
        await milestoneService.notifyNewRewards(
          newlyEarned: newlyEarned,
          userMode: widget.userMode,
        );
      }

      final progressAfter = curriculumEnum.isNotEmpty
          ? (await ref.read(
              dashboardCompletionPercentageProvider(
                curriculumEnum.first,
              ).future,
            ))
          : progressBefore + 0.01;

      final streakDataAfter = ref.read(dashboardStreakProvider).value;
      final streakAfter = streakDataAfter?.currentStreak ?? streakBefore;

      setState(() {
        _isLoading = false;
      });

      // Start feedback sequence
      _feedbackController.start(
        CompletionFeedbackData(
          pointsAwarded: completion.points,
          progressBefore: progressBefore,
          progressAfter: progressAfter,
          streakBefore: streakBefore,
          streakAfter: streakAfter,
          userMode: widget.userMode,
        ),
      );

      // Show points popup non-blocking (child mode only)
      if (widget.userMode == UserMode.child) {
        if (mounted) {
          unawaited(
            showPointsPopup(
              context: context,
              points: completion.points,
              userMode: widget.userMode,
            ),
          );
        }
      }
      // Adult mode: overlay checkmark animation handles feedback (no snackbar)

      widget.onCompleted?.call();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark complete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
