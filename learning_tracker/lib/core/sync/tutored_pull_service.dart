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
/// Intentionally thin — holds NO Riverpod state; callers supply the resolved
/// gateway + dispatcher so tests can substitute fakes.
class TutoredPullService {
  TutoredPullService({
    required FirestoreGateway gateway,
    required MergeDispatcher dispatcher,
    required ProfileDao profileDao,
  }) : _gateway = gateway,
       _dispatcher = dispatcher,
       _profileDao = profileDao;

  final FirestoreGateway _gateway;
  final MergeDispatcher _dispatcher;
  final ProfileDao _profileDao;

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
    // T1.profile — stable upsert; re-entry with same triple reuses the row.
    final localId = await _profileDao.upsertTutoredProfile(
      accountId: accountId,
      parentUid: parentUid,
      remoteChildProfileId: remoteProfileId,
      grantId: grantId,
      displayName: childDisplayName,
      mode: childMode,
      now: DateTime.now(),
    );

    // T1.pull-decouple — read parent namespace, merge under synthetic local id.
    final pipeline = PullPipeline(gateway: _gateway, dispatcher: _dispatcher);

    try {
      await pipeline.pullForTutoredProfile(
        parentUid: parentUid,
        remoteProfileId: remoteProfileId,
        localProfileId: localId,
      );
    } on FirestorePermissionDeniedException {
      return (
        localProfileId: localId,
        result: TutoredPullResult.permissionDenied,
      );
    } on Exception {
      return (localProfileId: localId, result: TutoredPullResult.error);
    }

    return (localProfileId: localId, result: TutoredPullResult.success);
  }
}
