import 'package:flutter/material.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Onboarding phase: child-mode handoff — tell the parent to hand the device
/// to the child and offer further actions.
class OnboardingHandoffStep extends StatelessWidget {
  const OnboardingHandoffStep({
    super.key,
    required this.profileName,
    required this.onStartLearning,
    required this.onAddAnotherTrack,
    required this.onAddAnotherLearner,
  });

  final String? profileName;
  final VoidCallback onStartLearning;
  final VoidCallback onAddAnotherTrack;
  final VoidCallback onAddAnotherLearner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final name = profileName ?? l10n.onboardingHandoffFallbackName;
    return SafeArea(
      top: false,
      // Scroll escape valve: the body is a fixed pile of widgets, so a plain
      // SingleChildScrollView lets it scroll instead of overflowing on short
      // screens / large text, while Center keeps it vertically centred when
      // there is spare room (preserving the normal-screen appearance).
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.onboardingHandoffAllSetUp(name),
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.onboardingHandoffDeviceHint(name),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.onboardingHandoffRewardsHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                FilledButton(
                  onPressed: onStartLearning,
                  child: Text(l10n.startLearning),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onAddAnotherTrack,
                  child: Text(l10n.addAnotherTrack),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onAddAnotherLearner,
                  child: Text(l10n.addAnotherLearner),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
