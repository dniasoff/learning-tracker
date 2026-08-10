// tutored_pull_service.dart — T1.trigger
//
// One-shot pull that fetches a tutored child's data from the parent's Firestore
// namespace into the tutor's local Drift under a synthetic read-only profile.
//
// Called at talmid-entry and at manual-refresh.  No live listeners (D2).
// Data isolation is enforced by:
//   (a) the synthetic profile row is flagged is_tutored=true,
//   (b) rows are merged under the synthetic local id, never the real remote id,
//   (c) the outbox ignores rows whose profile is_tutored (T1.isolation).

import 'package:learning_tracker/core/database/daos/profile_dao.dart';
import 'package:learning_tracker/core/sync/exceptions/firestore_permission_denied_exception.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:learning_tracker/core/sync/tutored_mirror_wipe_service.dart';

/// Result of a tutored pull attempt.
enum TutoredPullResult {
  /// Data was fetched and merged into the synthetic local profile.
  success,

  /// The gateway denied access — grant may have been revoked.
  permissionDenied,

  /// Any other error during the pull.
  error,
}

/// Pulls a tutored child's Firestore data into the tutor's local Drift.
///
/// Creates (or refreshes) a synthetic `learner_profiles` row flagged
/// `is_tutored = true` (T1.profile) and then runs
/// [PullPipeline.pullForTutoredProfile] (T1.pull-decouple) against the
/// parent's Firestore namespace.  The resulting rows are stored under the
/// synthetic local id so the existing UI providers render the talmid unchanged.
///
/// On [TutoredPullResult.permissionDenied] the grant has been revoked —
/// [wipeService] (if supplied) is called to purge the stale mirror so it
/// does not persist until next launch.
///
/// Intentionally thin — holds NO Riverpod state; callers supply the resolved
/// gateway + dispatcher so tests can substitute fakes.
class TutoredPullService {
  TutoredPullService({
    required FirestoreGateway gateway,
    required MergeDispatcher dispatcher,
    required ProfileDao profileDao,
    TutoredMirrorWipeService? wipeService,
    DateTime Function()? clock,
  }) : _gateway = gateway,
       _dispatcher = dispatcher,
       _profileDao = profileDao,
       _wipeService = wipeService,
       _clock = clock ?? DateTime.now;

  final FirestoreGateway _gateway;
  final MergeDispatcher _dispatcher;
  final ProfileDao _profileDao;
  final TutoredMirrorWipeService? _wipeService;
  final DateTime Function() _clock;

  /// Upsert the synthetic local profile and pull all child collections.
  ///
  /// [accountId]        — the tutor's own Drift account row id (FK).
  /// [parentUid]        — parent's Firebase UID (Firestore path root).
  /// [remoteProfileId]  — child's profile id within the parent's account.
  /// [grantId]          — the active tutor grant id.
  /// [childDisplayName] — displayed in the UI; refreshed on every pull.
  /// [childMode]        — 'child' or 'adult' (from the grant / profile doc).
  ///
  /// Returns the **synthetic local profile id** on success, so the caller
  /// can install it as the active resolved profile (S2 task).
  Future<({int localProfileId, TutoredPullResult result})> pull({
    required int accountId,
    required String parentUid,
    required String remoteProfileId,
    required String grantId,
    required String childDisplayName,
    required String childMode,
  }) async {
    // AUD-core-sync-04 — the upsert must be inside a try/catch of its own:
    // a DB failure here (busy, unique-constraint violation on grantId, disk
    // I/O) is a soft error like every other failure path in this method
    // (EH-2: a raw exception must never propagate into presentation). No
    // local id exists yet on this path, so callers — which ignore
    // localProfileId on the error branch — get the same `0` sentinel the
    // caller-side pull timeout already uses.
    final int localId;
    try {
      // T1.profile — stable upsert; re-entry with same triple reuses the row.
      localId = await _profileDao.upsertTutoredProfile(
        accountId: accountId,
        parentUid: parentUid,
        remoteChildProfileId: remoteProfileId,
        grantId: grantId,
        displayName: childDisplayName,
        mode: childMode,
        now: _clock(),
      );
    } on Exception {
      return (localProfileId: 0, result: TutoredPullResult.error);
    }

    // T1.pull-decouple — read parent namespace, merge under synthetic local id.
    final pipeline = PullPipeline(gateway: _gateway, dispatcher: _dispatcher);

    final int failureCount;
    try {
      // Bug 3: pullForTutoredProfile is now per-collection resilient — one
      // collection's merge/DB error (e.g. a point_configs FK violation) no
      // longer aborts the whole pull, so the remaining collections still land
      // and the scheduler projection can compute. It returns the count of
      // collections that failed; a non-zero count is a SOFT error (partial
      // refresh) that must NOT wipe the mirror.
      failureCount = await pipeline.pullForTutoredProfile(
        parentUid: parentUid,
        remoteProfileId: remoteProfileId,
        localProfileId: localId,
      );
    } on FirestorePermissionDeniedException {
      // Grant was revoked — tutor_active_access deleted by Cloud Function.
      // Purge the stale mirror so it does not persist until next launch.
      await _wipeService?.wipeMirrorForGrant(grantId);
      return (
        localProfileId: localId,
        result: TutoredPullResult.permissionDenied,
      );
    } on Exception {
      // A failure inside the pull pipeline (rare — pullForTutoredProfile is
      // itself per-collection resilient, see the Bug 3 note above) that
      // still escaped to here — surface as a soft error; do NOT wipe (not a
      // revocation).
      return (localProfileId: localId, result: TutoredPullResult.error);
    }

    if (failureCount > 0) {
      // Partial refresh — report soft error so the caller can hint "couldn't
      // fully refresh", but keep the (partial) mirror.
      return (localProfileId: localId, result: TutoredPullResult.error);
    }

    return (localProfileId: localId, result: TutoredPullResult.success);
  }
}
