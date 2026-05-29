import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/app_intro_screen.dart'
    show kIntroSeen;
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
import 'package:shared_preferences/shared_preferences.dart';

final _log = AppLogger.instance;

/// Unified auth/onboarding guard (Epic 20 §4, Epic 21 multi-account).
///
/// Collapses the v1 `AuthGuard` + `LocalAuthGuard` pair into a single
/// guard. Decision tree:
///
/// - Onboarding complete → pass through
/// - Intro slides not seen → redirect to [AppIntroRoute]
/// - Intro seen, onboarding incomplete, accounts on device → [AccountPickerRoute]
/// - Intro seen, onboarding incomplete, no accounts → [SignInRoute]
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
    // Fail-safe wrapper (no-lockout invariant): the first-launch gate runs on
    // every guarded navigation, and an unhandled throw here (a SharedPreferences
    // platform-channel failure, a corrupt/locked device_registry DB) would
    // escape onNavigation and leave AutoRoute's NavigationResolver completer
    // un-completed forever — a permanent navigation hang. On any unexpected
    // error we route to the always-reachable SignInRoute rather than hang.
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboarded = prefs.getBool(kOnboardingComplete) ?? false;

      if (onboarded) {
        resolver.next();
        return;
      }

      final introSeen = prefs.getBool(kIntroSeen) ?? false;
      if (!introSeen) {
        unawaited(router.replace(const AppIntroRoute()));
        resolver.next(false);
        return;
      }

      // Epic 21: check if accounts exist on the device. If so,
      // route to the account picker instead of the welcome screen.
      final registry = DeviceRegistryDatabase(
        driftDatabase(name: 'device_registry'),
      );
      try {
        final accounts = await registry.getAllAccounts();
        if (accounts.isNotEmpty) {
          unawaited(router.replace(const AccountPickerRoute()));
        } else {
          unawaited(router.replace(const SignInRoute()));
        }
      } finally {
        await registry.close();
      }
      resolver.next(false);
    } catch (error, stack) {
      _log.error(
        event: 'auth_guard_failed_safe_to_signin',
        exception: error,
        stackTrace: stack,
      );
      if (!resolver.isResolved) {
        unawaited(router.replace(const SignInRoute()));
        resolver.next(false);
      }
    }
  }
}
