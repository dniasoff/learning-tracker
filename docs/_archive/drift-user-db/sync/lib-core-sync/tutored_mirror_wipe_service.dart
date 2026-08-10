// tutored_mirror_wipe_service.dart — T5.lifecycle
//
// Purges the local tutored-profile mirror when the grant is revoked, resigned,
// or the tutor signs out.  Two triggers, one deletion path:
//
//   (1) Revoke/resign — parent or tutor terminates the grant server-side; the
//       client detects the terminal state on pull/refresh and calls
//       wipeMirrorForGrant() for each grant no longer present in the
//       authoritative CF result (see `incomingTutorGrantsProvider` in
//       manage_tutors_providers.dart, the D18 revoke-reconcile path).
//   (2) Sign-out — wipe every tutored mirror for the current account so no
//       child data persists for the next user of the device.
//
// AUD-core-sync-28: this file previously also exposed a batch revoke-reconcile
// method plus a companion owner-account-id resolution helper
// (tutored_pull_providers.dart), built to guard against
// `currentAccountIdProvider` resolving to the talmid's `learner_profiles.id`
// during a tutored session. That premise does not hold: `currentAccountIdProvider`
// (profile_providers.dart) is derived solely from `authStateProvider`, which is
// driven only by Firebase-session/local-account resolution and never by
// `activeTutoredProfileSelectionProvider` / `resolvedTutoredLocalProfileIdProvider`
// (the providers that DO carry the talmid's local id — see `activeProfileIdProvider`
// in active_profile_provider.dart, a *different* provider). The described failure
// mode was therefore unreachable, the removed helpers had zero production callers,
// and the shipped reconcile path in `incomingTutorGrantsProvider` already resolves
// the owner account id correctly via `currentAccountIdProvider`. See
// `test/sync/tutored_wipe_wrong_id_test.dart` for the regression proof that
// `currentAccountIdProvider` cannot leak the talmid's id.
//
// The FK `ON DELETE CASCADE` on MOST per-profile child tables means deleting
// the learner_profiles row cascades to most mirrored rows (completions,
// streak_events, learning_ledger, bookmarks, goals, etc.). AUD-core-database-01
// correction: 6 tables carry NO such FK (curriculum_tracks, daily_plans,
// outbox, point_configs, profile_programs, study_day_configs) — ProfileDao's
// deleteTutoredMirrorByGrantId / deleteAllTutoredMirrors explicitly clear
// those 6 first, in the same transaction as the profile-row delete, so this
// service still needs no extra step of its own — but the purge is NOT purely
// FK-cascade. See ProfileDao for the compensating deletes.
//
// Intentionally thin — no Riverpod import; callers inject the provider-clear
// callback so this service stays in core/ without a features/ dependency.

import 'package:learning_tracker/core/database/daos/profile_dao.dart';

/// Purges one or all tutored-profile mirrors from local Drift storage.
///
/// Call [wipeMirrorForGrant] when a specific grant is revoked or resigned —
/// this is what the D18 incoming-grants reconcile path
/// (`incomingTutorGrantsProvider` in manage_tutors_providers.dart) calls, once
/// per grant id that is no longer in the authoritative CF result, scoped by
/// `currentAccountIdProvider` (confirmed safe — see the file header).
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
    // Must use getTutoredMirrorsForAccount — getProfilesByAccount excludes mirrors.
    final rows = await _profileDao.getTutoredMirrorsForAccount(accountId);
    final tutoredGrantIds = rows
        .where((p) => p.tutorGrantId != null)
        .map((p) => p.tutorGrantId!)
        .toList();

    await _profileDao.deleteAllTutoredMirrors(accountId);

    for (final grantId in tutoredGrantIds) {
      _onWipe?.call(grantId);
    }
  }
}
