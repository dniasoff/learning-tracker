/// Who may use the sub-track editor surfaces, and whether their write
/// controls are enabled right now (Story 4.2, DNI-510, AC-1, AC-2, AC-5,
/// AC-6).
///
/// The Manage tracks Sub-tracks group, the school-year and ongoing forms,
/// the sub-track detail and the ground picker are shared by the parent and
/// a tutor in tutor mode:
///
/// * [subTrackEditorSessionProvider] — whether the session may OPEN them:
///   a parent session (an adult profile, or a child profile whose parent
///   PIN was verified), or any tutored session. A tutor without editing
///   access still opens them and reads what the grant allows (AC-5); a
///   child never does.
/// * [subTrackWritesBlockedProvider] — whether their write controls are
///   visible but disabled right now: only for a tutor, and exactly when
///   [tutorWriteAvailabilityProvider] blocks him (no `can_edit_learning`,
///   not positively online, or the tutor's device-user lock is active). The
///   parent's own gates are unchanged.
/// * [readSubTrackEditorSession] — the same answer read fresh at a command
///   boundary, so a save re-checks the session (a PIN lock, a revoked
///   grant or a dropped connection after the screen opened).
///
/// Editability comes from `can_edit_learning` alone (AD-53, deviation #7);
/// the server stays the final authority: `writeWithChangeLog` re-checks the
/// active grant on every tutor callable.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';

/// Whether the session may open the sub-track editor surfaces: a parent
/// session or a tutored session (Story 4.2 AC-2, AC-5). Fails closed (false)
/// while the profile resolves or on any read error.
final subTrackEditorSessionProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  if (ref.watch(activeTutoredProfileSelectionProvider) != null) return true;
  try {
    return await ref.watch(parentSessionProvider.future);
  } on Object {
    return false;
  }
});

/// Whether this session is a tutor's (tutor mode on a tutor device).
final subTrackTutorSessionProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(activeTutoredProfileSelectionProvider) != null,
);

/// Whether the sub-track write controls are visible but disabled right now
/// (UX-DR-36, UX-DR-158): a tutor without editing access, offline, or with
/// the tutor's device-user lock active (AC-5, AC-6). Never true for an owner
/// session.
final subTrackWritesBlockedProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(tutorWriteAvailabilityProvider).blocksTutor,
);

/// The live answer of the editor session at a command boundary: a tutor
/// may write only while [tutorWriteAvailabilityProvider] allows it now; a
/// parent only while the parent session holds. Fails closed.
Future<bool> readSubTrackEditorSession(WidgetRef ref) async {
  try {
    if (ref.read(activeTutoredProfileSelectionProvider) != null) {
      return ref.read(tutorWriteAvailabilityProvider).allowsWrite;
    }
  } on Object {
    return false;
  }
  ProviderSubscription<Future<bool>>? sub;
  try {
    sub = ref.listenManual(parentSessionProvider.future, (_, _) {});
    return await sub.read();
  } on Object {
    return false;
  } finally {
    sub?.close();
  }
}
