import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/completion_animation.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/completion_feedback_controller.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/points_popup.dart';

/// Provider family to check whether a specific stage is already completed.
final isStageCompletedProvider = FutureProvider.autoDispose
    .family<bool, ({String sefariaRef, int stageId, String trackType})>((
      ref,
      params,
    ) async {
      final repository = ref.watch(completionRepositoryProvider);
      return repository.isStageCompleted(
        sefariaRef: params.sefariaRef,
        stageId: params.stageId,
        trackType: params.trackType,
      );
    });

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
      final useCase = ref.read(markCompletionUseCaseProvider);
      final request = CompletionRequest(
        curriculumId: widget.curriculumId,
        sefariaRef: widget.sefariaRef,
        stageId: widget.stageId,
        trackType: widget.trackType,
      );

      final completion = await useCase(request);

      setState(() {
        _isLoading = false;
      });

      // Start feedback sequence
      _feedbackController.start(
        CompletionFeedbackData(
          pointsAwarded: completion.points,
          progressBefore: 0,
          progressAfter: 0,
          userMode: widget.userMode,
        ),
      );

      // Show appropriate feedback based on user mode
      if (widget.userMode == UserMode.child) {
        // Non-blocking points popup
        if (mounted) {
          await showPointsPopup(
            context: context,
            points: completion.points,
            userMode: widget.userMode,
          );
        }
      } else {
        // Subtle confirmation for adults
        await _showSubtleConfirmation();
      }

      _feedbackController.cancel();
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

  Future<void> _showSubtleConfirmation() async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Marked as complete'),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
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
            if (_feedbackController.phase == CompletionFeedbackPhase.checkmark)
              Positioned.fill(
                child: CompletionAnimation(
                  userMode: widget.userMode,
                  onComplete: () => _feedbackController.advance(),
                ),
              ),
          ],
        );
      },
    );
  }
}
