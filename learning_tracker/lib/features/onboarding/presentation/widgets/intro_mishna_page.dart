import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

const _kNavy = Color(0xFF1A36A5);
const _kCoral = Color(0xFFF86B6B);
const _kPeach = Color(0xFFFFD8C8);
const _kPillBlue = Color(0xFFC8D8F8);

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
                    color: _kPillBlue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.introMishnaReviewChip,
                    style: GoogleFonts.plusJakartaSans(
                      color: _kNavy,
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
                    color: _kPeach.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '…yos',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.brandInk,
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
                  color: _kNavy,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: _kNavy.withValues(alpha: 0.28),
                      blurRadius: 22,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.psychology_rounded,
                        color: AppTheme.brandCreamCard,
                        size: 96,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kCoral,
                        ),
                        child: const Icon(
                          Icons.sync,
                          color: AppTheme.brandCreamCard,
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
                          color: AppTheme.brandCreamCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: _kNavy,
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
                      color: const Color(0xFFE2E5EB),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        width: c.maxWidth * t,
                        height: 5,
                        color: const Color(0xFFB8C0CC),
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
