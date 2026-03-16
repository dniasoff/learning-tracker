import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';

/// Points popup overlay shown after completion.
///
/// Child mode: Animated dialog with star icon and "+X Points!" text.
/// Adult mode: No popup (caller should skip showing this widget).
///
/// Auto-dismisses after [autoDismissDelay].
class PointsPopup extends StatefulWidget {
  final int points;
  final VoidCallback onDismiss;
  final UserMode userMode;
  final Duration autoDismissDelay;

  const PointsPopup({
    required this.points,
    required this.onDismiss,
    this.userMode = UserMode.child,
    this.autoDismissDelay = const Duration(seconds: 2),
    super.key,
  });

  @override
  State<PointsPopup> createState() => _PointsPopupState();
}

class _PointsPopupState extends State<PointsPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();

    Future.delayed(widget.autoDismissDelay, () {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 80, color: Colors.amber),
                  const SizedBox(height: 16),
                  Text(
                    '+${widget.points} Points!',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Great job!',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shows a non-blocking points popup as an overlay.
///
/// The popup auto-dismisses and does not prevent user interaction
/// with the underlying UI (uses [barrierDismissible: true]).
Future<void> showPointsPopup({
  required BuildContext context,
  required int points,
  UserMode userMode = UserMode.child,
}) async {
  if (userMode == UserMode.adult || points <= 0) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black12,
    builder: (context) => PointsPopup(
      points: points,
      userMode: userMode,
      onDismiss: () => Navigator.of(context).pop(),
    ),
  );
}
