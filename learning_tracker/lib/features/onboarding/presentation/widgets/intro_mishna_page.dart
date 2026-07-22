import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Animated illustration for the second intro page ("Never Forget a Mishna").
class IntroMishnaIllustration extends StatelessWidget {
  const IntroMishnaIllustration({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Transform.rotate(angle: -0.04 + (0.01 * (1 - t)), child: child);
      },
      child: SizedBox(
        height: 250,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              top: 20,
              child: Transform.rotate(
                angle: -0.1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.introPillBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.introMishnaReviewChip,
                    style: GoogleFonts.plusJakartaSans(
                      color: context.colors.introNavy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 40,
              child: Transform.rotate(
                angle: 0.08,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.introPeach.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.introMishnaWordFragmentChip,
                    style: GoogleFonts.plusJakartaSans(
                      color: context.colors.brandInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 188,
                height: 200,
                decoration: BoxDecoration(
                  color: context.colors.introNavy,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.introNavy.withValues(alpha: 0.28),
                      blurRadius: 22,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.psychology_rounded,
                        color: context.colors.brandCreamCard,
                        size: 96,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.colors.accentCoral,
                        ),
                        child: Icon(
                          Icons.sync,
                          color: context.colors.brandCreamCard,
                          size: 20,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: context.colors.brandCreamCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.lightbulb_outline,
                          color: context.colors.introNavy,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress bar shown at the bottom of the Mishna intro page.
class IntroMishnaProgressBar extends StatelessWidget {
  const IntroMishnaProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 2 / 3),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) {
            return LayoutBuilder(
              builder: (context, c) {
                return Stack(
                  children: [
                    Container(
                      width: c.maxWidth,
                      height: 5,
                      color: context.colors.introProgressTrackBg,
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        width: c.maxWidth * t,
                        height: 5,
                        color: context.colors.introProgressFillGreen,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
