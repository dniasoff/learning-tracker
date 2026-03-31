import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
import 'package:shared_preferences/shared_preferences.dart';

/// Route guard that redirects unauthenticated users to sign-in or intro.
///
/// If onboarding has been completed before, skips the intro carousel and goes
/// directly to [SignInRoute]. Otherwise shows [AppIntroRoute].
class AuthGuard extends AutoRouteGuard {
  AuthGuard({required FirebaseAuth firebaseAuth})
    : _firebaseAuth = firebaseAuth;

  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    final user = await _firebaseAuth.authStateChanges().first;
    if (user != null) {
      resolver.next();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final onboarded = prefs.getBool(kOnboardingComplete) ?? false;
      unawaited(
        router.replace(onboarded ? const SignInRoute() : const AppIntroRoute()),
      );
      resolver.next(false);
    }
  }
}
