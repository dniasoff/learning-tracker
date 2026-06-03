import 'package:flutter/material.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Onboarding phase: shown after a track is added, offering to add another
/// track or proceed to learning.
class OnboardingAddAnotherPromptStep extends StatelessWidget {
  const OnboardingAddAnotherPromptStep({
    super.key,
    required this.trackCount,
    required this.lastTrackLabel,
    required this.onStartLearning,
    required this.onAddAnotherTrack,
  });

  final int trackCount;
  final String? lastTrackLabel;
  final VoidCallback onStartLearning;
  final VoidCallback onAddAnotherTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Your track "${lastTrackLabel ?? ""}" is ready!',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You have $trackCount track${trackCount == 1 ? '' : 's'} set up.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
