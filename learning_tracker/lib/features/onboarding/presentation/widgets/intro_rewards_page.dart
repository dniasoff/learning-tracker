import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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
        // Compact hero so the reward cards below clear the pinned CTA on a
        // typical phone at first paint (was 200 — pushed the cards under the
        // fixed "Get Started" button).
        height: 150,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.introNavy,
                boxShadow: [
                  BoxShadow(
                    color: context.colors.scrimDark,
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                // Dark-mode legibility burndown: goldTrophy DARKENS in dark
                // mode (ink-on-fixed-white-surface by design) but this
                // circle's fill is introNavy, which stays deep-saturated in
                // BOTH themes — measured 1.13:1 in dark. goldOnColouredSurface
                // is the token built for exactly this "stays coloured" pairing.
                color: context.colors.goldOnColouredSurface,
                size: 68,
              ),
            ),
            Positioned(
              top: 0,
              right: 32,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.introPeach,
                ),
                child: Icon(
                  Icons.star,
                  color: context.colors.brandInk,
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
                    color: context.colors.accentCoral,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.introCardShadow,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  // Decorative illustration badge — shows a streak badge
                  // concept without claiming a specific number.
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 14,
                        color: context.colors.brandCreamCard,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.streak,
                        style: GoogleFonts.plusJakartaSans(
                          color: context.colors.brandCreamCard,
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
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _FeatureCard(
            icon: Icons.military_tech_outlined,
            label: l10n.introBadgeCollection,
            bottomBorder: context.colors.introNavy,
            circleColor: context.colors.introBadgeBg,
            // Dark-mode legibility burndown: both read introNavy, which
            // stays deep navy in BOTH themes, painted on this card's own
            // brandCreamCard background and introBadgeBg circle — both
            // correctly darken — measured 1.38-1.39:1 in dark. The sibling
            // "Mystery Prizes" card already used adapting ink
            // (introMysteryText/introMysteryIcon); introAccentInk gives
            // Badge Collection the same correctly-adapting behaviour while
            // keeping the identical light-mode hex.
            textColor: context.colors.introAccentInk,
            iconColor: context.colors.introAccentInk,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FeatureCard(
            icon: Icons.card_giftcard_rounded,
            label: l10n.introMysteryPrizes,
            bottomBorder: context.colors.introMysteryBorder,
            circleColor: context.colors.introMysteryBg,
            textColor: context.colors.introMysteryText,
            iconColor: context.colors.introMysteryIcon,
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
        color: context.colors.brandCreamCard,
        borderRadius: BorderRadius.circular(20),
        border: Border(bottom: BorderSide(color: bottomBorder, width: 3)),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandInk.withValues(alpha: 0.07),
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
        color: context.colors.introBadgeBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.introNavy.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.colors.introNavy.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            // Dark-mode legibility burndown: icon/title/body below read
            // introNavy, which stays deep navy in BOTH themes, on top of
            // introBadgeBg (adapts) / the introNavy@0.12 circle tint (also
            // effectively adapts, since it is blended over introBadgeBg) —
            // measured ~1.34-1.38:1 in dark. introAccentInk keeps the
            // identical light-mode hex and lightens in dark. The border and
            // this circle's own low-alpha tint fill are left as introNavy —
            // decorative, non-text.
            child: Icon(
              Icons.child_care_rounded,
              size: 22,
              color: context.colors.introAccentInk,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.introChildModeTagTitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.introAccentInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.introChildModeTagBody,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.colors.introAccentInk.withValues(
                      alpha: 0.75,
                    ),
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
///
/// This card is purely decorative — it illustrates what the scholar-level
/// progress bar looks like when a user earns levels. It intentionally does not
/// show a specific level number so it cannot be mistaken for the user's
/// actual progress on their first encounter with the app (H-2 fix).
class IntroScholarLevelCard extends ConsumerWidget {
  const IntroScholarLevelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = domainTermLabels(ref);
    final useHebrew = terms.isHebrew;
    final talmidChochomCapsLabel = terms.talmidChochomCaps;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: context.colors.brandCreamCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.colors.brandInk.withValues(alpha: 0.06),
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
                // Generic label — avoids implying the user is at "Level 4".
                l10n.introScholarProgress,
                style: GoogleFonts.plusJakartaSans(
                  color: context.colors.brandInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              // EXAMPLE badge — makes it visually obvious this is an
              // illustrative preview, not the user's actual level.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colors.introNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.introScholarExample,
                  style: GoogleFonts.plusJakartaSans(
                    // Dark-mode legibility burndown: introNavy stays deep
                    // navy in BOTH themes, painted on this card's own
                    // brandCreamCard background (correctly darkens) via a
                    // low-alpha tint — measured 1.35:1 in dark. introAccentInk
                    // keeps the identical light-mode hex and lightens in dark.
                    color: context.colors.introAccentInk,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
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
                      color: context.colors.introScholarTrackBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      // Decorative fill — not tied to any real value.
                      width: c.maxWidth * 0.6,
                      height: 8,
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
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.introScholarNovice,
                style: GoogleFonts.plusJakartaSans(
                  color: context.colors.brandInkSoft,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                talmidChochomCapsLabel,
                style: GoogleFonts.plusJakartaSans(
                  color: context.colors.brandInkSoft,
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
