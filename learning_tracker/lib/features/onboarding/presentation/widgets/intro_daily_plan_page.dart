import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

const _kNavy = Color(0xFF1A36A5);
const _kGreen = Color(0xFF1DB97D);
const _kCoral = Color(0xFFF86B6B);
const _kPeach = Color(0xFFFFD8C8);

/// Animated illustration for the first intro page ("Your Daily Torah Plan").
class IntroDailyPlanIllustration extends StatelessWidget {
  const IntroDailyPlanIllustration({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ).value.clamp(0.85, 1.0);
        return Transform.scale(scale: scale, child: child);
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            top: 0,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _kPeach,
              ),
            ),
          ),
          // Card Column is ~180+ px intrinsic; FittedBox scales to fit the Stack
          // (prevents ~30px RenderFlex overflow in tight maxHeight).
          Center(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: Container(
                width: 248,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppTheme.brandCreamCard,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _kNavy.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _WindowDot(c: _kCoral),
                            _WindowDot(c: AppColors.goldTrophy),
                            _WindowDot(c: Color(0xFF5BC0EB)),
                          ],
                        ),
                        Spacer(),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppTheme.brandInkMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _dailyListRow1Checked(),
                    const SizedBox(height: 4),
                    _dailyListRow2Highlight(),
                    const SizedBox(height: 4),
                    _dailyListRowEmpty(filled: true),
                    const SizedBox(height: 4),
                    _dailyListRowEmpty(filled: false),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _kNavy,
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome,
                  color: AppColors.goldTrophy,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _dailyListRow1Checked() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F1F4),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _kNavy,
          ),
          child: const Icon(
            Icons.check,
            size: 14,
            color: AppTheme.brandCreamCard,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xFFDCDFE5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _dailyListRow2Highlight() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
      color: _kNavy,
      borderRadius: BorderRadius.circular(999),
      boxShadow: [
        BoxShadow(
          color: _kNavy.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppTheme.brandCreamCard,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow_rounded, color: _kNavy, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.brandCreamCard.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _dailyListRowEmpty({required bool filled}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F1F4),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC9CED6)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: filled ? const Color(0xFFDCDFE5) : const Color(0xFFE5E7EC),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Progress bar shown at the bottom of the daily plan intro page.
class IntroDailyPlanProgressBar extends StatelessWidget {
  const IntroDailyPlanProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1 / 3),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                return LayoutBuilder(
                  builder: (context, c) {
                    return Stack(
                      children: [
                        Container(
                          width: c.maxWidth,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E5EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            width: c.maxWidth * t,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _kGreen,
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'SETUP PROGRESS',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.brandInkSoft,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _WindowDot extends StatelessWidget {
  const _WindowDot({required this.c});

  final Color c;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 5),
      width: 7,
      height: 7,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
    );
  }
}
