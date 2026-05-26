// tutored_mirror_wipe_service.dart — T5.lifecycle
//
// Purges the local tutored-profile mirror when the grant is revoked, resigned,
// or the tutor signs out.  Three triggers, one deletion path:
//
//   (1) Revoke/resign — parent or tutor terminates the grant server-side; the
//       client detects the terminal state on pull/refresh and calls wipeMirror().
//   (2) Sign-out — wipe every tutored mirror for the current account so no
//       child data persists for the next user of the device.
//
// The FK `ON DELETE CASCADE` on every per-profile child table means deleting
// the learner_profiles row cascades to all mirrored rows in completions,
// streak_events, learning_ledger, bookmarks, goals, curriculum_tracks, etc.
// No explicit child-row deletion is needed.
//
// Intentionally thin — no Riverpod import; callers inject the provider-clear
// callback so this service stays in core/ without a features/ dependency.

import 'package:learning_tracker/core/database/daos/profile_dao.dart';

/// Purges one or all tutored-profile mirrors from local Drift storage.
///
/// Call [wipeMirrorForGrant] when a specific grant is revoked or resigned.
/// Call [wipeAllMirrors] on tutor sign-out.
///
/// [onWipe] is an optional callback invoked after the DB delete — use it to
/// clear the `resolvedTutoredLocalProfileIdProvider` and call
/// `ActiveTutoredProfileSelection.exit()` when the wiped grant is the active
/// talmid session.  Keeping those Riverpod calls out of this service ensures
/// the service is unit-testable without a widget tree.
class TutoredMirrorWipeService {
  TutoredMirrorWipeService({
    required ProfileDao profileDao,
    void Function(String grantId)? onWipe,
  }) : _profileDao = profileDao,
       _onWipe = onWipe;

  final ProfileDao _profileDao;
  final void Function(String grantId)? _onWipe;

  /// Purge the mirror for a single grant (revoke or resign).
  ///
  /// Idempotent — safe to call even when no mirror exists for [grantId].
  /// [onWipe] fires only if a row was actually deleted.
  Future<void> wipeMirrorForGrant(String grantId) async {
    final deleted = await _profileDao.deleteTutoredMirrorByGrantId(grantId);
    if (deleted > 0) {
      _onWipe?.call(grantId);
    }
  }

  /// Purge every tutored mirror belonging to [accountId] (sign-out).
  Future<void> wipeAllMirrors(int accountId) async {
    // Collect grant ids before deletion so we can fire onWipe for each.
    final rows = await _profileDao.getProfilesByAccount(accountId);
    final tutoredGrantIds = rows
        .where((p) => p.isTutored && p.tutorGrantId != null)
        .map((p) => p.tutorGrantId!)
        .toList();

    await _profileDao.deleteAllTutoredMirrors(accountId);

    for (final grantId in tutoredGrantIds) {
      _onWipe?.call(grantId);
    }
  }
}
