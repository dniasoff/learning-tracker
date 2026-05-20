import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

const _kNavy = Color(0xFF1A36A5);
const _kCoral = Color(0xFFF86B6B);
const _kPeach = Color(0xFFFFD8C8);
const _kGoldTrophy = AppColors.goldTrophy;
const _kMysteryBorder = Color(0xFFC9A86A);
const _kBadgeBg = Color(0xFFE8ECFF);
const _kMysteryBg = Color(0xFFFFF3E0);
const _kGreen = Color(0xFF1DB97D);

/// Animated hero illustration for the third intro page ("Earn While You Learn").
class IntroRewardsHeroIllustration extends StatelessWidget {
  const IntroRewardsHeroIllustration({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final s = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ).value.clamp(0.88, 1.0);
        return Transform.scale(scale: s, child: child);
      },
      child: SizedBox(
        height: 200,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 168,
              height: 168,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _kNavy,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.scrimDark,
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: _kGoldTrophy,
                size: 84,
              ),
            ),
            Positioned(
              top: 0,
              right: 32,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kPeach,
                ),
                child: const Icon(
                  Icons.star,
                  color: AppTheme.brandInk,
                  size: 24,
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 6,
              child: Transform.rotate(
                angle: -0.1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _kCoral,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 14,
                        color: AppTheme.brandCreamCard,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '7 DAY STREAK',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.brandCreamCard,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row of two feature-highlight cards shown on the rewards intro page.
class IntroFeatureCardsRow extends StatelessWidget {
  const IntroFeatureCardsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _FeatureCard(
            icon: Icons.military_tech_outlined,
            label: 'Badge\nCollection',
            bottomBorder: _kNavy,
            circleColor: _kBadgeBg,
            textColor: _kNavy,
            iconColor: _kNavy,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _FeatureCard(
            icon: Icons.card_giftcard_rounded,
            label: 'Mystery\nPrizes',
            bottomBorder: _kMysteryBorder,
            circleColor: _kMysteryBg,
            textColor: Color(0xFF5C4A2A),
            iconColor: Color(0xFF6B4E1E),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.bottomBorder,
    required this.circleColor,
    required this.textColor,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color bottomBorder;
  final Color circleColor;
  final Color textColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      decoration: BoxDecoration(
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(20),
        border: Border(bottom: BorderSide(color: bottomBorder, width: 3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandInk.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: circleColor,
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Banner shown on the rewards intro page so users understand that points
/// and rewards aren't surfaced for adult profiles.
class IntroChildModeTag extends StatelessWidget {
  const IntroChildModeTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _kBadgeBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kNavy.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kNavy.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.child_care_rounded,
              size: 22,
              color: _kNavy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'For Child profiles only',
                  style: GoogleFonts.plusJakartaSans(
                    color: _kNavy,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Points, streaks, and rewards show up when you create a Child profile. Adult profiles focus on plain learning progress.',
                  style: GoogleFonts.plusJakartaSans(
                    color: _kNavy.withValues(alpha: 0.75),
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Scholar-level progress card shown at the bottom of the rewards intro page.
class IntroScholarLevelCard extends ConsumerWidget {
  const IntroScholarLevelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = domainTermLabels(ref);
    final useHebrew = terms.isHebrew;
    final talmidChochomCapsLabel = terms.talmidChochomCaps;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandInk.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scholar Level',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.brandInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Level 4',
                style: GoogleFonts.plusJakartaSans(
                  color: _kNavy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              return Stack(
                children: [
                  Container(
                    width: c.maxWidth,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAEF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      width: c.maxWidth * 0.6,
                      height: 8,
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
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NOVICE',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.brandInkSoft,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                talmidChochomCapsLabel,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.brandInkSoft,
                  fontSize: useHebrew ? 11 : 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: useHebrew ? 0 : 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
