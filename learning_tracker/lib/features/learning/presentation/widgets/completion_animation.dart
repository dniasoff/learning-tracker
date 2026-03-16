import 'dart:math';

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';

/// Animation widget shown when a completion is successfully marked.
///
/// In child mode: celebratory checkmark burst with confetti particles.
/// In adult mode: brief checkmark with subtle fade.
class CompletionAnimation extends StatefulWidget {
  final UserMode userMode;
  final VoidCallback? onComplete;

  const CompletionAnimation({
    super.key,
    this.userMode = UserMode.child,
    this.onComplete,
  });

  @override
  State<CompletionAnimation> createState() => _CompletionAnimationState();
}

class _CompletionAnimationState extends State<CompletionAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    final isChild = widget.userMode == UserMode.child;
    final duration = isChild
        ? const Duration(milliseconds: 800)
        : const Duration(milliseconds: 400);

    _controller = AnimationController(duration: duration, vsync: this);

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
    );

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.userMode == UserMode.child) ..._buildConfettiParticles(),
            Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 60,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildConfettiParticles() {
    final random = Random();
    const particleColors = [
      Colors.amber,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
    ];

    return List.generate(12, (i) {
      final angle = (i / 12) * 2 * pi;
      final distance = 40.0 + random.nextDouble() * 30;
      final color = particleColors[i % particleColors.length];
      final size = 4.0 + random.nextDouble() * 4;

      return Positioned(
        left: 40 + cos(angle) * distance * _controller.value - size / 2,
        top: 40 + sin(angle) * distance * _controller.value - size / 2,
        child: Opacity(
          opacity: (1.0 - _controller.value).clamp(0.0, 1.0),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      );
    });
  }
}
