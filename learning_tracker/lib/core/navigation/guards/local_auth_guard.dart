import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
import 'package:shared_preferences/shared_preferences.dart';

/// Route guard that checks if onboarding is complete.
///
/// Unlike the old [AuthGuard], this guard NEVER touches Firebase and
/// NEVER hangs waiting for network. It checks a local SharedPreferences
/// flag synchronously.
///
/// Semantic: "has completed onboarding" — NOT "has Firebase account".
class LocalAuthGuard extends AutoRouteGuard {
  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool(kOnboardingComplete) ?? false;

    if (onboarded) {
      resolver.next();
    } else {
      unawaited(router.replace(const AppIntroRoute()));
      resolver.next(false);
    }
  }
}
