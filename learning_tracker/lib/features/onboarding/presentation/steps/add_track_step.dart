import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/onboarding/presentation/steps/profile_creation_step.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/presentation/screens/add_track_flow_screen.dart';

/// Step that hosts the [AddTrackFlow] sub-flow.
///
/// When the user completes a track the step advances automatically; if they
/// cancel (and a profile already exists) we skip to the completion step.
class OnboardingAddTrackStep extends OnboardingStep {
  const OnboardingAddTrackStep({
    required this.data,
    required this.onTrackAdded,
    required this.onCancel,
  });

  final OnboardingProfileData data;

  /// Called each time a track is successfully added (to update track count).
  final void Function(AddTrackResult result) onTrackAdded;

  /// Called when the user cancels without adding a track.
  final void Function() onCancel;

  @override
  String get id => 'addTrack';

  @override
  Widget build(BuildContext context, WidgetRef ref, OnboardingStepContext ctx) {
    return AddTrackFlow(
      profileId: data.createdProfileId ?? 0,
      isOnboarding: true,
      onComplete: (result) {
        onTrackAdded(result);
        ctx.advance();
      },
      onCancel: onCancel,
    );
  }
}

/// Step shown after a track is successfully added, prompting whether to add
/// another or start learning.
class AddAnotherPromptStep extends OnboardingStep {
  const AddAnotherPromptStep({
    required this.data,
    required this.trackCount,
    required this.lastTrackLabel,
    required this.onAddAnother,
    required this.onStartLearning,
  });

  final OnboardingProfileData data;
  final int trackCount;
  final String? lastTrackLabel;
  final VoidCallback onAddAnother;
  final VoidCallback onStartLearning;

  @override
  String get id => 'addAnotherPrompt';

  @override
  Widget build(BuildContext context, WidgetRef ref, OnboardingStepContext ctx) {
    return _AddAnotherPromptWidget(
      trackCount: trackCount,
      lastTrackLabel: lastTrackLabel,
      onAddAnother: onAddAnother,
      onStartLearning: onStartLearning,
    );
  }
}

class _AddAnotherPromptWidget extends StatelessWidget {
  const _AddAnotherPromptWidget({
    required this.trackCount,
    required this.lastTrackLabel,
    required this.onAddAnother,
    required this.onStartLearning,
  });

  final int trackCount;
  final String? lastTrackLabel;
  final VoidCallback onAddAnother;
  final VoidCallback onStartLearning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Center(
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
                child: Text(
                  AppLocalizations.of(context)!.onboardingStartLearning,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAddAnother,
                child: Text(
                  AppLocalizations.of(context)!.onboardingAddAnotherTrack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Handoff step shown at the end of child-mode onboarding.
class HandoffStep extends OnboardingStep {
  const HandoffStep({
    required this.data,
    required this.onStartLearning,
    required this.onAddAnotherTrack,
    required this.onAddAnotherLearner,
  });

  final OnboardingProfileData data;
  final VoidCallback onStartLearning;
  final VoidCallback onAddAnotherTrack;
  final VoidCallback onAddAnotherLearner;

  @override
  String get id => 'handoff';

  @override
  Widget build(BuildContext context, WidgetRef ref, OnboardingStepContext ctx) {
    return _HandoffWidget(
      profileName: data.profileName,
      onStartLearning: onStartLearning,
      onAddAnotherTrack: onAddAnotherTrack,
      onAddAnotherLearner: onAddAnotherLearner,
    );
  }
}

class _HandoffWidget extends StatelessWidget {
  const _HandoffWidget({
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
    return SafeArea(
      top: false,
      child: Center(
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
                "${profileName ?? 'Your child'}'s learning is all set up",
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Hand the device to ${profileName ?? 'your child'} to start learning',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'You can set up rewards later in Parent Mode',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: onStartLearning,
                child: Text(
                  AppLocalizations.of(context)!.onboardingStartLearning,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAddAnotherTrack,
                child: Text(
                  AppLocalizations.of(context)!.onboardingAddAnotherTrack,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onAddAnotherLearner,
                child: Text(
                  AppLocalizations.of(context)!.onboardingAddAnotherLearner,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Convenience app-bar titles for steps that show one.
class AddTrackAppBarTitle extends StatelessWidget {
  const AddTrackAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppBarTitle(text: 'Set Up a Track');
}

class AddAnotherPromptAppBarTitle extends StatelessWidget {
  const AddAnotherPromptAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) => const AppBarTitle(text: 'Track Ready!');
}

class HandoffAppBarTitle extends StatelessWidget {
  const HandoffAppBarTitle({super.key});

  @override
  Widget build(BuildContext context) =>
      const AppBarTitle(text: 'Setup Complete!');
}

/// Gradient decoration shared across the onboarding scaffold.
BoxDecoration onboardingGradientDecoration() {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppTheme.brandCreamCard,
        AppTheme.brandBlueSoft.withValues(alpha: 0.2),
        AppTheme.brandCream,
      ],
    ),
  );
}
