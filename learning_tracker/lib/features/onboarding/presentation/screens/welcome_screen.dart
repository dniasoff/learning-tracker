import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/auth/presentation/providers/connectivity_providers.dart';

/// Welcome screen — the first non-intro surface a brand-new user
/// sees. Shows a single signup call-to-action whose destination is
/// chosen by the live connectivity stream:
///
/// - Online  → "Get Started"            → cloud-born signup
/// - Offline → "Create Offline Account" → local-born signup
///
/// The "Already have an account? Sign in" link routes to the
/// cloud-born sign-in screen when online, and to the local-born
/// sign-in screen when offline.
@RoutePage()
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Live-watch so the buttons update the instant connectivity flips.
    // Default to "online" during the initial loading tick so a
    // cold-start first render doesn't flash the offline UI while
    // the checker is still resolving.
    final connectivity = ref.watch(connectivityStreamProvider);
    final isOnline = connectivity.maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.menu_book_rounded,
                size: 96,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Torah Learning Tracker',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Track your Torah learning journey with structured progress '
                'tracking across multiple curricula.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (!isOnline) ...[
                const SizedBox(height: 24),
                _OfflineHint(theme: theme),
              ],
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Epic 21.5: always route to the same unified
                    // signup page. It handles both tiers inline based
                    // on connectivity.
                    context.router.push(AccountCreationRoute());
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Get Started'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  if (isOnline) {
                    context.router.push(const SignInRoute());
                  } else {
                    context.router.push(const LocalSignInRoute());
                  }
                },
                child: const Text('Already have an account? Sign in'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineHint extends StatelessWidget {
  const _OfflineHint({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_off,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          "You're offline — you'll sign up without cloud backup",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
