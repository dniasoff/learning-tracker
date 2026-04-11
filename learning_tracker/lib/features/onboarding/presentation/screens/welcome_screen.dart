import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/auth/presentation/providers/connectivity_providers.dart';

@RoutePage()
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

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
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // Epic 20.6: signup is mandatory at first launch.
                  // Route by current connectivity — online → cloud,
                  // offline → local. Uses the last emitted value from
                  // connectivityStreamProvider so the decision is
                  // made from the already-running checker, no extra
                  // await or timing budget needed.
                  onPressed: () => _getStarted(context, ref),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Get Started'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.router.push(const SignInRoute()),
                child: const Text('Already have an account? Sign in'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _getStarted(BuildContext context, WidgetRef ref) {
    final connectivity = ref.read(connectivityStreamProvider);
    // Default to "online" when the stream hasn't produced a value
    // yet — matches the v2 §3 rule "ambiguous network → try cloud
    // first and fall back gracefully on Firebase failure".
    final isOnline = connectivity.maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );
    if (isOnline) {
      context.router.push(AccountCreationRoute());
    } else {
      context.router.push(LocalSignupRoute());
    }
  }
}
