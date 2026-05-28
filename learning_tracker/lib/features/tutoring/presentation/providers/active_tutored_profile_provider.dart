// active_tutored_profile_provider — WS3.3c / WS3.3d
//
// Holds the active TutoredProfileSelection when a tutor has entered a
// talmid's profile context (after passing the TutorPinEntryGate).
//
// null  → no tutored-profile context active (normal own-profile mode).
// non-null → tutor is viewing a talmid; the value carries the grant + perms.
//
// Used by:
//   • router_provider.dart — to resolve PinScope.tutor() vs PinScope.parent()
//   • app_shell.dart — to show the "acting as tutor for X" indicator
//   • Permission-gated UI — to determine available actions (via activeTutorPermissionsProvider)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_tutored_profile_provider.g.dart';

/// Holds the current [TutoredProfileSelection] while the tutor is viewing a
/// talmid's profile context. Cleared when the tutor exits the talmid view.
///
/// `keepAlive: true` so the selection persists across route changes while the
/// tutor is inside the talmid's profile.
@Riverpod(keepAlive: true)
class ActiveTutoredProfileSelection extends _$ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() {
    // Account-switch reset is handled at the AppShell level via ref.listen
    // on authStateProvider — see app_shell.dart _AccountSwitchObserver.
    // Keeping the auth chain OUT of this build() means widget tests that
    // don't mount AppShell never materialise FirebaseAuth.instance.
    return null;
  }

  /// Enter a talmid's context after the TutorPinEntryGate passes.
  void enter(TutoredProfileSelection selection) => state = selection;

  /// Exit the talmid context (return to own profile).
  ///
  /// Also clears the resolved synthetic local profile id so a subsequent
  /// talmid entry starts from a clean slate.
  void exit() {
    ref.read(resolvedTutoredLocalProfileIdProvider.notifier).clear();
    state = null;
  }
}

/// Convenience provider: exposes the [TutorPermissions] for the currently
/// active tutored-profile context, or `null` when not in a tutored session.
///
/// UI affordances (edit tracks, rewards, goals, study days) should gate on
/// the relevant `canEdit*` field from this provider.
///
/// Example:
/// ```dart
/// final perms = ref.watch(activeTutorPermissionsProvider);
/// if (perms == null || perms.canEditRewards) {
///   // show the Rewards tile (owner always sees it; tutor sees it iff allowed)
/// }
/// ```
final activeTutorPermissionsProvider = Provider<TutorPermissions?>((ref) {
  final selection = ref.watch(activeTutoredProfileSelectionProvider);
  return selection?.permissions;
}, name: 'activeTutorPermissionsProvider');

/// Holds the **synthetic local profile id** that was returned by
/// [TutoredPullService.pull] for the currently active talmid mirror.
///
/// Set by S2 (T2.entry-pull) immediately after a successful pull so that
/// [activeProfileIdProvider] can resolve to the mirror without an async hop.
/// Cleared by [ActiveTutoredProfileSelection.exit].
///
/// `keepAlive: true` — must outlive route changes inside the talmid view.
@Riverpod(keepAlive: true)
class ResolvedTutoredLocalProfileId extends _$ResolvedTutoredLocalProfileId {
  @override
  int? build() {
    // Account-switch reset is coordinated by the same AppShell observer that
    // resets ActiveTutoredProfileSelection — exit() calls clear() on this
    // provider, so no direct auth watch needed here.
    return null;
  }

  void resolve(int localProfileId) => state = localProfileId;

  void clear() => state = null;
}
