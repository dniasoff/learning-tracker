import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/app_intro_screen.dart'
    show kIntroSeen;
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
import 'package:shared_preferences/shared_preferences.dart';

/// Route guard that checks if onboarding is complete.
///
/// Unlike the old [AuthGuard], this guard NEVER touches Firebase and
/// NEVER hangs waiting for network. It checks local SharedPreferences
/// flags synchronously.
///
/// Flow:
/// - Onboarding complete → pass through to requested route
/// - Intro slides not seen → redirect to AppIntroRoute (4 promo slides)
/// - Intro seen but onboarding not complete → redirect to WelcomeRoute (sign-in/sign-up)
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
      final introSeen = prefs.getBool(kIntroSeen) ?? false;
      if (introSeen) {
        unawaited(router.replace(const WelcomeRoute()));
      } else {
        unawaited(router.replace(const AppIntroRoute()));
      }
      resolver.next(false);
    }
  }
}
