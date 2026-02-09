import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/completion_animation.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/points_popup.dart';

/// Button widget for marking a content item as completed.
///
/// Shows completion animation and points popup (child mode) or
/// subtle confirmation (adult mode) upon successful completion.
class CompletionButton extends ConsumerStatefulWidget {
  final String curriculumId;
  final int contentItemId;
  final int stageId;
  final String trackType;
  final UserMode userMode;
  final VoidCallback? onCompleted;

  const CompletionButton({
    required this.curriculumId,
    required this.contentItemId,
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
  bool _showAnimation = false;

  Future<void> _handleMarkComplete() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final useCase = ref.read(markCompletionUseCaseProvider);
      final request = CompletionRequest(
        curriculumId: widget.curriculumId,
        contentItemId: widget.contentItemId,
        stageId: widget.stageId,
        trackType: widget.trackType,
      );

      final completion = await useCase(request);

      // Show completion feedback
      setState(() {
        _showAnimation = true;
        _isLoading = false;
      });

      // Show appropriate feedback based on user mode
      if (widget.userMode == UserMode.child) {
        // Show points popup for children
        await _showPointsPopup(completion.points);
      } else {
        // Show subtle confirmation for adults
        await _showSubtleConfirmation();
      }

      // Reset animation state after feedback
      setState(() {
        _showAnimation = false;
      });

      widget.onCompleted?.call();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark complete: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPointsPopup(int points) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PointsPopup(
        points: points,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
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
    return Stack(
      alignment: Alignment.center,
      children: [
        ElevatedButton(
          onPressed: _isLoading || _showAnimation ? null : _handleMarkComplete,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Mark Complete'),
        ),
        if (_showAnimation)
          const Positioned.fill(
            child: CompletionAnimation(),
          ),
      ],
    );
  }
}
