import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/widgets/scrollable_fill_body.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class EmptyDashboard extends StatelessWidget {
  final String name;
  final String greeting;
  final bool isChildMode;

  const EmptyDashboard({
    super.key,
    required this.name,
    required this.greeting,
    required this.isChildMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final accent = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    // Overflow-safe fill: centres on normal screens, scrolls on short ones.
    return ScrollableFillBody(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$greeting,',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                name,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.2),
                      accent.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.menu_book_rounded, color: accent, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.noTracksYet,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isChildMode ? l10n.askGrownUpToAddTrack : l10n.firstTrackPrompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (!isChildMode) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.router.push(
                      TrackManagementHubRoute(startAdding: true),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addTrack),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
