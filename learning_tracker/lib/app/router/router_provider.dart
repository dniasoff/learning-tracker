import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/guards/auth_guard.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/parent_mode/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

/// Riverpod provider that creates and owns the [AppRouter] singleton.
///
/// Guards are wired to real [PinService] instances so that PIN verification
/// uses secure storage rather than hard-coded stubs.
final routerProvider = Provider<AppRouter>((ref) {
  final pinSvc = ref.watch(pinServiceProvider);

  // Guards resolve the database lazily via getters rather than via a
  // watched field. Sign-in/signup flows invalidate userDatabaseProvider
  // to swap per-account DB files mid-flow — if the router watched the
  // provider, that invalidate would tear down the router, reset its
  // route state, and bounce brand-new sign-ins back to SignInRoute.
  UserDatabase getDb() => ref.read(userDatabaseProvider);

  return AppRouter(
    navigatorKey: navigatorKey,
    authGuard: AuthGuard(),
    restoreGuard: RestoreGuard(
      getDatabase: getDb,
      hasCloudAccount: () => ref.read(authStateProvider).isCloudBorn,
    ),
    profileGuard: ProfileGuard(
      getDatabase: getDb,
      getSelectedProfileId: () => ref.read(selectedProfileIdProvider),
      setSelectedProfileId: (id) =>
          ref.read(selectedProfileIdProvider.notifier).select(id),
      getAccountId: () => ref.read(currentAccountIdProvider),
    ),
    childModeGuard: ChildModeGuard(
      getDatabase: getDb,
      getSelectedProfileId: () => ref.read(selectedProfileIdProvider),
    ),
    pinGuard: PinGuard(
      pinService: pinSvc,
      promptForPin: () async {
        final context = navigatorKey.currentContext;
        if (context == null) return false;
        final profileId = ref.read(selectedProfileIdProvider);
        if (profileId == null) return false;
        return showParentPinVerificationDialog(
          context,
          profileId: profileId,
          pinService: pinSvc,
          analytics: ref.read(analyticsServiceProvider),
        );
      },
      // All currently-gated routes are parent-mode. Tutor-mode routes will
      // pass their own scope via a different closure when they land.
      getScope: () {
        final profileId = ref.read(selectedProfileIdProvider);
        if (profileId == null) return null;
        return PinScope.parent(profileId);
      },
      onSessionAuthenticated: (scope) {
        if (scope is PinScopeParent) {
          ref
              .read(parentPinAuthenticatedProfileIdProvider.notifier)
              .setAuthenticated(scope.profileId);
        }
      },
      onSessionLocked: () {
        ref.read(parentPinAuthenticatedProfileIdProvider.notifier).clear();
      },
    ),
  );
});

/// Global navigator key bound to the auto_route root navigator. Guards use
/// this key's [BuildContext] to show PIN entry dialogs from outside the
/// widget tree (the guard callback doesn't have its own context).
final navigatorKey = GlobalKey<NavigatorState>();
