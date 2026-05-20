import 'package:flutter/material.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Onboarding phase: final "all set" screen.
class OnboardingDoneStep extends StatelessWidget {
  const OnboardingDoneStep({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(l10n.allSet, style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }
}
