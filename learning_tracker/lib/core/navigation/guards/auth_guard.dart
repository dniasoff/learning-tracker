import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/app_intro_screen.dart'
    show kIntroSeen;
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
import 'package:shared_preferences/shared_preferences.dart';

/// Unified auth/onboarding guard (Epic 20 §4).
///
/// Collapses the v1 `AuthGuard` + `LocalAuthGuard` pair into a single
/// guard. Decision tree:
///
/// - Onboarding complete → pass through
/// - Intro slides not seen → redirect to [AppIntroRoute]
/// - Intro seen but onboarding incomplete → redirect to [WelcomeRoute]
///
/// Signed-in / signed-out session status is owned by `AuthStateNotifier`,
/// read downstream by individual screens. This guard only governs the
/// first-launch gate and never touches Firebase — see 19.6 startup
/// hardening for why that matters.
class AuthGuard extends AutoRouteGuard {
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
