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
///
/// **Profile-aware pass-through (Epic 21 multi-account fix).** `kOnboardingComplete`
/// is a single device-global flag written only by the onboarding wizard's
/// terminal step. It is cleared on an account switch, and the DIRECT setup flow
/// (add-profile dialog → track management, no wizard) never re-sets it. So an
/// account that already has a profile+track could be dumped back into the
/// wizard when the flag is false. To fix this without a device-global write
/// (which would risk letting a genuinely-new 0-profile account skip onboarding),
/// the guard treats "the active account already has ≥1 learner profile" as
/// onboarded. The profile count is supplied by [activeAccountProfileCount],
/// which reuses the app's already-open per-account user DB connection
/// (`userDatabaseProvider`) rather than opening a second connection to the live
/// DB file — see `router_provider.dart` for the wiring. When the callback is
/// absent (default), the guard behaves exactly as before.
class AuthGuard extends AutoRouteGuard {
  /// Creates the guard.
  ///
  /// [activeAccountProfileCount] returns the number of own (non-tutored)
  /// learner profiles in the active account's user DB. Injected by
  /// `router_provider.dart` so the guard reuses the app's existing user-DB
  /// connection; left null in contexts (and tests) that exercise only the
  /// flag/registry branches.
  AuthGuard({Future<int> Function()? activeAccountProfileCount})
    : _activeAccountProfileCount = activeAccountProfileCount;

  final Future<int> Function()? _activeAccountProfileCount;

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

      // Profile-aware pass-through: the device-global kOnboardingComplete flag
      // is cleared on an account switch, but the active account may already
      // have a profile+track set up via the DIRECT (non-wizard) flow, which
      // never re-sets the flag. Treat "active account has ≥1 own profile" as
      // onboarded so an already-set-up account is not dumped back into the
      // wizard. This runs INSIDE the fail-safe try, so a DB/prefs error while
      // counting falls through to the safe SignInRoute redirect below — never
      // a hang, never a lockout. We only read (a COUNT), never write the flag:
      // a device-global write here would risk a genuinely-new 0-profile account
      // later skipping onboarding.
      final countProfiles = _activeAccountProfileCount;
      if (countProfiles != null && (await countProfiles()) > 0) {
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
