import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';

/// Dot-row page indicator for the intro screen.
///
/// Renders [pageCount] dots where the dot at [currentPage] is active (navy,
/// wider) and the rest are inactive (light grey). This is the canonical page
/// position affordance; it does not drive any navigation itself.
class IntroPageIndicator extends StatelessWidget {
  const IntroPageIndicator({
    super.key,
    required this.pageCount,
    required this.currentPage,
  });

  final int pageCount;
  final int currentPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (i) {
        final isActive = i == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? context.colors.introNavy
                : context.colors.introIndicatorInactive,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
