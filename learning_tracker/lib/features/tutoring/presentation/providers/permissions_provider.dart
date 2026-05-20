// permissionsProvider — W4.35
//
// Single Riverpod provider that resolves the effective [ResolvedSession] for
// the current profile selection. This is the single source of truth for UI
// affordances — every screen that conditionally enables/disables tutor-only
// or owner-only actions must read this provider.
//
// The provider is parameterised by [ProfileSelection] so different parts of
// the widget tree can read the session for different profile views without
// conflicts.
//
// NOTE: This provider currently returns a static owner session because the
// TutorGrant repository (data layer) is not yet wired up. When W6.x lands
// the tutor flow, this provider will be updated to detect active tutor grants
// for the caller and return a [ResolvedSession.forTutor] when appropriate.
//
// The provider shape is stable — callers should depend on [ResolvedSession]
// now, even if it always returns the owner session in v1.

import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'permissions_provider.g.dart';

/// Riverpod provider that resolves the [ResolvedSession] for a given
/// [ProfileSelection].
///
/// Pass a [ProfileSelection] as the argument:
/// ```dart
/// final session = ref.watch(permissionsProvider(
///   OwnProfileSelection(profileId: '42', ownerUid: uid),
/// ));
/// ```
///
/// The provider returns [AsyncValue<ResolvedSession>] so callers can
/// handle loading/error states.
///
/// keepAlive: false (auto-disposed when all listeners leave) — the session
/// is re-resolved when the user navigates to a profile view.
@riverpod
Future<ResolvedSession> permissions(Ref ref, ProfileSelection selection) async {
  switch (selection) {
    case OwnProfileSelection():
      // Owner (parent or self-learner) — full permissions, no grant check.
      return ResolvedSession.forOwner(
        selection: selection,
        isChildMode: false, // TODO(W6.x): read from profile settings
      );

    case TutoredProfileSelection():
      // Tutor view — permissions come from the grant.
      return ResolvedSession.forTutor(selection: selection);
  }
}
