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
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_entry_dialog.dart';

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
    // Profile-aware pass-through: reuse the app's already-open per-account user
    // DB connection (via getDb(), the same lazy ref.read used by the other
    // guards) to count own profiles — never a second connection to the live
    // DB file. When the active account already has a profile, AuthGuard lets it
    // through even if the device-global onboarding flag is false.
    authGuard: AuthGuard(
      activeAccountProfileCount: () => getDb().profileDao.countOwnProfiles(),
    ),
    restoreGuard: RestoreGuard(
      getDatabase: getDb,
      hasCloudAccount: () => ref.read(authStateProvider).isCloudBorn,
      deviceRestoreRoute: () => const DeviceRestoreRoute(),
    ),
    profileGuard: ProfileGuard(
      getDatabase: getDb,
      getSelectedProfileId: () => ref.read(selectedProfileIdProvider),
      // P2-2: forward the ULID ProfileGuard already resolved synchronously
      // — this used to be a bare `select(id)`, which cleared
      // activeProfileDocIdProvider to null on every auto-select redirect.
      // P2-10: `ProfileGuard`'s own `setSelectedProfileId` field is now
      // typed `{required String ulid}` — the resolve-or-throw on a legacy
      // null-ulid Drift row happens inside `ProfileGuard` itself (the class
      // that actually holds the nullable Drift row), so by the time this
      // closure runs, `ulid` is already a proven non-null `String`; this
      // closure has nothing left to enforce, only to forward.
      setSelectedProfileId: (id, {required String ulid}) {
        ref.read(selectedProfileIdProvider.notifier).select(id, ulid: ulid);
      },
      getAccountId: () => ref.read(currentAccountIdProvider),
      isTutoredSession: () =>
          ref.read(activeTutoredProfileSelectionProvider) != null,
      profilePickerRoute: () => const ProfilePickerRoute(),
    ),
    childModeGuard: ChildModeGuard(
      getDatabase: getDb,
      getSelectedProfileId: () => ref.read(selectedProfileIdProvider),
      // In a tutored session the active profile is the synthetic talmid mirror
      // (a child profile) — resolve it so the child-mode-gated parent-
      // management routes open for tutors (TUT-02/TUT-06).
      getActiveProfileId: () => ref.read(activeProfileIdProvider),
      isTutoredSession: () =>
          ref.read(activeTutoredProfileSelectionProvider) != null,
    ),
    pinGuard: PinGuard(
      pinService: pinSvc,
      pinSetupRoute: () => const PinFlowSetupRoute(),
      // C2: dispatch the prompt on the resolved PinScope. Tutor-scoped routes
      // verify against the Tutor PIN service (keyed on the tutor's OWN profile
      // id); parent-scoped routes use the existing parent-PIN dialog.
      promptForPin: () async {
        final context = navigatorKey.currentContext;
        if (context == null) return false;

        // Tutor scope takes precedence when a talmid context is active.
        final tutoredSelection = ref.read(
          activeTutoredProfileSelectionProvider,
        );
        if (tutoredSelection != null) {
          final tutorOwnId = tutoredSelection.tutorOwnProfileId;
          final tutorPinSvc = ref.read(tutorPinServiceProvider);
          return showTutorPinVerificationDialog(
            context,
            tutorOwnProfileId: tutorOwnId,
            tutorPinService: tutorPinSvc,
          );
        }

        final profileId = ref.read(selectedProfileIdProvider);
        if (profileId == null) return false;
        return showParentPinVerificationDialog(
          context,
          profileId: profileId,
          pinService: pinSvc,
          analytics: ref.read(analyticsServiceProvider),
        );
      },
      // WS3.3c / C1: resolve PinScope from the active profile selection.
      // OwnProfileSelection  → PinScope.parent(profileId) for parent-mode routes.
      // TutoredProfileSelection → PinScope.tutor(tutorOwnProfileId) for
      //   talmid-view routes. The Tutor PIN is per-tutor (one PIN across all
      //   talmidim) so the scope keys on the tutor's OWN profile id — the same
      //   namespace the entry gate uses — NOT on the talmid's profileId.
      getScope: () {
        // Check if there is an active tutored-profile context first.
        final tutoredSelection = ref.read(
          activeTutoredProfileSelectionProvider,
        );
        if (tutoredSelection != null) {
          return PinScope.tutor(tutoredSelection.tutorOwnProfileId);
        }
        // Fall back to parent-mode scope for own-profile routes.
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
        // Tutor scope: no separate session token needed — the
        // TutorPinEntryGate widget manages the talmid-view lifecycle directly.
      },
      onSessionLocked: () {
        ref.read(parentPinAuthenticatedProfileIdProvider.notifier).clear();
        // If a tutored session was active, exit it on lock.
        if (ref.read(activeTutoredProfileSelectionProvider) != null) {
          ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
        }
      },
    ),
  );
});

/// Global navigator key bound to the auto_route root navigator. Guards use
/// this key's [BuildContext] to show PIN entry dialogs from outside the
/// widget tree (the guard callback doesn't have its own context).
final navigatorKey = GlobalKey<NavigatorState>();
