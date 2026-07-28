import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.introPeach,
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
                  color: context.colors.brandCreamCard,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.introNavy.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _WindowDot(c: context.colors.accentCoral),
                            _WindowDot(c: context.colors.goldTrophy),
                            _WindowDot(c: context.colors.introWindowDotBlue),
                          ],
                        ),
                        const Spacer(),
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: context.colors.brandInkMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _dailyListRow1Checked(context),
                    const SizedBox(height: 4),
                    _dailyListRow2Highlight(context),
                    const SizedBox(height: 4),
                    _dailyListRowEmpty(context, filled: true),
                    const SizedBox(height: 4),
                    _dailyListRowEmpty(context, filled: false),
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.introNavy,
              ),
              child: Center(
                child: Icon(
                  Icons.auto_awesome,
                  // Dark-mode legibility burndown: goldTrophy DARKENS in dark
                  // mode (it's ink-on-fixed-white-surface by design) but this
                  // circle's fill (introNavy) stays deep-saturated in BOTH
                  // themes — measured 1.13:1 in dark. goldOnColouredSurface
                  // is the token built for exactly this "stays coloured"
                  // pairing (see its doc comment).
                  color: context.colors.goldOnColouredSurface,
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

Widget _dailyListRow1Checked(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
      color: context.colors.introDailyRowPillBg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.introNavy,
          ),
          child: Icon(
            Icons.check,
            size: 14,
            // Dark-mode legibility burndown: brandCreamCard is a SURFACE
            // token (correctly darkens for real cards) but this circle's
            // fill is introNavy, which stays deep navy in BOTH themes —
            // measured 1.39:1 in dark. introCtaLabel is the fixed-white
            // token already built for ink painted on introNavy (same pairing
            // as GlowingCtaButton's label).
            color: context.colors.introCtaLabel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: context.colors.introDailyRowTrackFilled,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _dailyListRow2Highlight(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
      color: context.colors.introNavy,
      borderRadius: BorderRadius.circular(999),
      boxShadow: [
        BoxShadow(
          color: context.colors.introNavy.withValues(alpha: 0.2),
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
          decoration: BoxDecoration(
            // Dark-mode legibility burndown: brandCreamCard (a SURFACE
            // token) darkened this "punched-out" accent circle to near-black
            // in dark mode while the introNavy pill around it stayed deep
            // navy — measured 1.39:1. introCtaLabel keeps it fixed white in
            // both themes, matching the introNavy-fill pairing used
            // elsewhere in this illustration.
            color: context.colors.introCtaLabel,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: context.colors.introNavy,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              // Same fix as the circle above — was brandCreamCard (darkens),
              // painted on the introNavy pill (stays deep navy).
              color: context.colors.introCtaLabel.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _dailyListRowEmpty(BuildContext context, {required bool filled}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
      color: context.colors.introDailyRowPillBg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.introDailyCheckboxBorder),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: filled
                  ? context.colors.introDailyRowTrackFilled
                  : context.colors.introDailyRowTrackEmpty,
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
                            color: context.colors.introProgressTrackBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            width: c.maxWidth * t,
                            height: 6,
                            decoration: BoxDecoration(
                              color: context.colors.introProgressFillGreen,
                              borderRadius: const BorderRadius.horizontal(
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
          AppLocalizations.of(context)!.introSetupProgress,
          style: GoogleFonts.plusJakartaSans(
            color: context.colors.brandInkSoft,
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
