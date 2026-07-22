// W6.1 — Onboarding sign-up flow branch chooser (FR-8)
//
// After account creation + profile creation, the user is presented with three
// paths:
//   1. "Track my own learning"    → AddTrackFlow (existing path)
//   2. "Join to tutor someone"    → Dashboard with Accept Invite CTA
//   3. "Skip for now"             → Dashboard with empty-state CTAs (W6.3)
//
// Displayed as part of the onboarding flow once a profile has been created.
// Replaces the unconditional forward push to AddTrackFlow.

import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Which path the user chose at the onboarding fork.
enum OnboardingIntent {
  /// Set up a learning track right now (→ AddTrackFlow).
  trackMyLearning,

  /// The user is joining to tutor a child (→ dashboard + Accept Invite CTA).
  joiningToTutor,

  /// Skip for now (→ dashboard + empty-state CTAs).
  skipForNow,
}

/// Branch-chooser screen shown after profile creation.
///
/// The caller (OnboardingScreen) embeds this as a phase step. The chosen
/// [OnboardingIntent] is returned via [onChosen].
class OnboardingIntentStep extends StatelessWidget {
  const OnboardingIntentStep({required this.onChosen, super.key});

  final ValueChanged<OnboardingIntent> onChosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.onboardingIntentHeading,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.colors.brandInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.onboardingIntentSubtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.colors.brandInkMuted,
              ),
            ),
            const SizedBox(height: 32),
            _IntentCard(
              icon: Icons.menu_book_rounded,
              iconBgColor: const Color(0xFFE4E7EF),
              iconColor: context.colors.brandBlueDeep,
              title: l10n.onboardingIntentTrackTitle,
              subtitle: l10n.onboardingIntentTrackSubtitle,
              onTap: () => onChosen(OnboardingIntent.trackMyLearning),
            ),
            const SizedBox(height: 14),
            // "Join to tutor someone" intentionally omitted here — tutor access
            // is reached via an invite link / the empty-login tutor entry, not
            // the first-run intent chooser.
            _IntentCard(
              icon: Icons.skip_next_rounded,
              iconBgColor: const Color(0xFFEAF5EA),
              iconColor: const Color(0xFF3A7C3A),
              title: l10n.onboardingIntentSkipTitle,
              subtitle: l10n.onboardingIntentSkipSubtitle,
              onTap: () => onChosen(OnboardingIntent.skipForNow),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: iconBgColor,
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.colors.brandInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.colors.brandInkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.brandInkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
