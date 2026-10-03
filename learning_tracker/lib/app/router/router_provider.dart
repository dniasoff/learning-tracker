import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/guards/auth_guard.dart';
import 'package:learning_tracker/app/router/guards/sacred_time_location_guard.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/own_session_guard.dart';
import 'package:learning_tracker/core/navigation/guards/parent_session_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/features/notifications/data/fcm_parent_push_service.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/parent_pin_keypad_dialog.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_time_location_access_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_pin_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/tutor_pin_entry_dialog.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Riverpod provider that creates and owns the [AppRouter] singleton.
///
/// Guards are wired to real [PinService] instances so that PIN verification
/// uses secure storage rather than hard-coded stubs.
final routerProvider = Provider<AppRouter>((ref) {
  final pinSvc = ref.watch(pinServiceProvider);

  return AppRouter(
    navigatorKey: navigatorKey,
    authGuard: AuthGuard(
      activeAccountProfileCount: () =>
          ref.read(profileRepositoryProvider).countProfiles(),
    ),
    profileGuard: ProfileGuard(
      getProfiles: () => ref.read(profileRepositoryProvider).getProfiles(),
      getSelectedProfileId: () => ref.read(selectedProfileIdProvider),
      setSelectedProfileId: (profileId) {
        ref.read(selectedProfileIdProvider.notifier).select(profileId);
      },
      isTutoredSession: () =>
          ref.read(activeTutoredProfileSelectionProvider) != null,
      profilePickerRoute: () => const ProfilePickerRoute(),
    ),
    childModeGuard: ChildModeGuard(
      getProfileById: (profileId) =>
          ref.read(profileRepositoryProvider).getProfileById(profileId),
      getSelectedProfileId: () => ref.read(selectedProfileIdProvider),
      // In a tutored session the active profile is the talmid's own id —
      // resolve it so the child-mode-gated parent-management routes open
      // for tutors (TUT-02/TUT-06).
      getActiveProfileId: () => ref.read(activeProfileIdProvider),
      isTutoredSession: () =>
          ref.read(activeTutoredProfileSelectionProvider) != null,
    ),
    parentSessionGuard: ParentSessionGuard(
      // listen (not read) keeps the auto-dispose session provider alive
      // until its future resolves.
      isParentSession: () async {
        final sub = ref.listen(parentSessionProvider.future, (_, _) {});
        try {
          return await sub.read();
        } finally {
          sub.close();
        }
      },
    ),
    // DNI-513: parent-only views refuse a tutored session.
    ownSessionGuard: OwnSessionGuard(
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
        final tutoredSelection = ref.read(
          activeTutoredProfileSelectionProvider,
        );
        if (tutoredSelection != null) {
          return PinScope.tutor(tutoredSelection.tutorOwnProfileId);
        }
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
      // DNI-515 (AD-39): a parent unlock registers this install for tutor
      // change pushes; every lock clears the local parent-session marker at
      // once and then deletes the install's token. Never in a tutored session.
      onParentSessionChanged: (profileId) {
        final push = ref.read(parentPushServiceProvider);
        if (push == null) return;
        if (profileId == null) {
          unawaited(push.onParentLocked());
        } else if (ref.read(activeTutoredProfileSelectionProvider) == null) {
          unawaited(push.onParentUnlocked(profileId));
        }
      },
    ),
    // DNI-481 AC-3 / AUD-sacred_time-08: the city picker writes the active
    // learner's lock settings. Keyed on the DEVICE HOLDER (T-37, as the
    // Settings card's gate): a child holder with a Parent PIN must have just
    // verified it in-app (a one-shot pass) or verify it now.
    sacredTimeLocationGuard: SacredTimeLocationGuard(
      getSelectedProfileId: () => ref.read(selectedProfileIdProvider),
      getProfileById: (profileId) =>
          ref.read(profileRepositoryProvider).getProfileById(profileId),
      hasProfilePin: pinSvc.hasProfilePin,
      consumeAccess: (profileId) =>
          ref.read(sacredTimeLocationAccessProvider).consume(profileId),
      promptForPin: (profileId) async {
        final context = navigatorKey.currentContext;
        if (context == null) return false;
        return showParentPinVerificationDialog(
          context,
          profileId: profileId,
          pinService: pinSvc,
          analytics: ref.read(analyticsServiceProvider),
          subtitle: AppLocalizations.of(
            context,
          )?.pinDialogSubtitleLocationAccess,
        );
      },
    ),
  );
});

/// Global navigator key bound to the auto_route root navigator. Guards use
/// this key's [BuildContext] to show PIN entry dialogs from outside the
/// widget tree (the guard callback doesn't have its own context).
final navigatorKey = GlobalKey<NavigatorState>();
