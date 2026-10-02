/// Riverpod providers for the Story 1.2 (DNI-464) learner-state
/// repositories: `learning_events` and `sub_tracks`.
///
/// Kept out of `repository_providers.dart` (orchestrator ruling: new
/// providers in separate files) and built only on the existing seams:
///
/// - the repositories get their Firestore handle ONLY from
///   [activeAccountFirebaseProvider] (parent AD-1/AD-24 named-app handles);
/// - the `{uid}` path segment of the active learner's OWN profile comes ONLY
///   from the persisted path uid, [PathUidResolver.pathUidFor] (AD-24 rule 2,
///   orchestrator ruling B1) — never from the live Auth uid
///   (`AccountFirebaseHandles.uid`), so an AD-19 anonymous-uid remap cannot
///   split or strand the learner's tree. In a tutored session the owner uid
///   is the validated grant's `parent_uid` from
///   [resolveActiveAccountAndProfile] (ruling B10). Either way the pair is
///   wrapped in a [LearnerScope];
/// - no active account, no active profile, an account whose path uid is
///   not yet bound, or an active account id with no authenticated session
///   ([AccountNotAuthenticatedException] — signed out, or restored before
///   sign-in) resolves to `null` ("not ready"), never a terminal error
///   (orchestrator ruling B1: "treat a null or unauthenticated handle as not
///   ready"). Every other resolution failure still surfaces as an error;
/// - an account with a pending AD-19 re-home (a non-null
///   `previousFirebaseUid` breadcrumb after an anon-uid remap) is REFUSED
///   with [LearnerScopeRehomePendingException]: the learner's events,
///   sub-tracks and change log still live under the old uid, so reading the
///   new, empty namespace would publish an empty log and writing there would
///   split the account's data. The scope opens only once the re-home
///   consumer (follow-up bead, outside Story 1.2) has moved the tree and
///   cleared the breadcrumb.
///
/// The named-app Auth wiring itself (bead `learning-tracker-gd7`, DNI-520)
/// changes what happens INSIDE those seams (who calls
/// `PathUidResolver.reconcileLiveUid`), not this file.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/registry/path_uid_resolver.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_change_log_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_event_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_points_amount_reader.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/c0_stub.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_doc_reader.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// The [PathUidResolver] over the device registry — the single accessor
/// for the persisted `users/{uid}` path segment (AD-24 rule 2).
final learnerStatePathUidResolverProvider = Provider<PathUidResolver>(
  (ref) => PathUidResolver(ref.watch(deviceRegistryProvider)),
);

/// The device-registry account rows, live. Watched by
/// [activeLearnerScopeProvider] only as a change trigger, so a
/// `PathUidResolver.reconcileLiveUid` bind or remap re-resolves the scope.
final _registryAccountsProvider = StreamProvider<List<DeviceAccount>>(
  (ref) => ref.watch(deviceRegistryProvider).watchAllAccounts(),
);

/// The active account was remapped to a new path uid (AD-19 anon-uid reset)
/// and its `users/{previousUid}/…` tree has not been re-homed yet, so no
/// learner-state read or write may address either namespace.
final class LearnerScopeRehomePendingException implements Exception {
  /// Creates the exception.
  const LearnerScopeRehomePendingException({
    required this.accountId,
    required this.previousUid,
    required this.pathUid,
  });

  /// The device-registry account id.
  final String accountId;

  /// The pre-remap uid whose tree still holds the learner's data.
  final String previousUid;

  /// The newly persisted path uid (not yet populated).
  final String pathUid;

  @override
  String toString() =>
      'LearnerScopeRehomePendingException: account $accountId was remapped '
      'and its learner data has not been re-homed yet';
}

/// The active account's Firestore handles, or null while no account is
/// active OR the active account id has no authenticated session
/// ([AccountNotAuthenticatedException]) — ruling B1: an unauthenticated
/// handle is "not ready", not a crash. Watching the shared provider's
/// `.future` keeps the dependency, so the sign-in that re-sets the id
/// re-resolves every learner-state provider. Any other failure propagates.
Future<AccountFirebaseHandles?> _readyHandles(Ref ref) async {
  try {
    return await ref.watch(activeAccountFirebaseProvider.future);
  } on AccountNotAuthenticatedException {
    return null;
  }
}

/// The active learner's [LearnerScope], or null while no account or no
/// profile is active, while the active account is unauthenticated, or while
/// the active account's path uid is unbound.
/// A stale/invalid tutor selection, a non-ULID profile id, or an account id
/// with no registry row surfaces as an error (same contract as the
/// profile-scoped providers in `repository_providers.dart`), as does an
/// account with a pending re-home ([LearnerScopeRehomePendingException]).
final activeLearnerScopeProvider = FutureProvider<LearnerScope?>((ref) async {
  // Not ready while the active account is unauthenticated (ruling B1). The
  // shared seam below awaits the same handle, so gate on it first.
  if (await _readyHandles(ref) == null) return null;
  final resolved = await resolveActiveAccountAndProfile(ref);
  if (resolved == null) return null;
  final (_, grantOrLiveOwnerUid, profileId) = resolved;

  // Tutored session: the owner is the validated grant's parent_uid — another
  // account's namespace, not ours to resolve from our own registry row.
  if (ref.watch(activeTutoredProfileSelectionProvider) != null) {
    return LearnerScope(ownerUid: grantOrLiveOwnerUid, profileId: profileId);
  }

  // Own profile: the path uid is the PERSISTED one (ruling B1), never the
  // live Auth uid the shared seam returns for this branch.
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  await ref.watch(_registryAccountsProvider.future);
  final pathUid = await ref
      .watch(learnerStatePathUidResolverProvider)
      .pathUidFor(accountId);
  if (pathUid == null || pathUid.isEmpty) return null;

  // AD-19 remap not yet re-homed: refuse both namespaces (see library doc).
  // Read AFTER the path uid: the remap writes uid and breadcrumb in one
  // statement, so a new uid is never observed without its breadcrumb.
  final previousUid =
      (await ref.watch(deviceRegistryProvider).findById(accountId))
          ?.previousFirebaseUid;
  if (previousUid != null && previousUid.isNotEmpty) {
    throw LearnerScopeRehomePendingException(
      accountId: accountId,
      previousUid: previousUid,
      pathUid: pathUid,
    );
  }
  return LearnerScope(ownerUid: pathUid, profileId: profileId);
}, retry: (retryCount, error) => null);

/// [LearningEventRepository] over the active account's Firestore handle,
/// or null while no account is active or it is unauthenticated (ruling B1).
/// Scope is passed per call.
final learningEventRepositoryProvider =
    FutureProvider<LearningEventRepository?>((ref) async {
      final handles = await _readyHandles(ref);
      if (handles == null) return null;
      return FirestoreLearningEventRepository(firestore: handles.firestore);
    }, retry: (retryCount, error) => null);

/// [SubTrackRepository] over the active account's Firestore handle, or
/// null while no account is active or it is unauthenticated (ruling B1).
/// Scope is passed per call.
final subTrackRepositoryProvider = FutureProvider<SubTrackRepository?>((
  ref,
) async {
  final handles = await _readyHandles(ref);
  if (handles == null) return null;
  return FirestoreSubTrackRepository(firestore: handles.firestore);
}, retry: (retryCount, error) => null);

// C0 (DNI-524) contract providers. Each is a stub that resolves to
// `AsyncError(UnimplementedError)` until its owner story fills it; tests
// override them with the fakes in `test/helpers/learner_state/`. Like the
// repositories above, each resolves to null while the active account is
// not ready, and scope is passed per call.

/// [ChangeLogRepository] over the active account's Firestore handle, or
/// null while not ready (DNI-470). Scope is passed per call.
final changeLogRepositoryProvider = FutureProvider<ChangeLogRepository?>((
  ref,
) async {
  final handles = await _readyHandles(ref);
  if (handles == null) return null;
  return FirestoreChangeLogRepository(firestore: handles.firestore);
}, retry: (retryCount, error) => null);

/// [GovernedDocReader] over the active account's Firestore handle, or null
/// while not ready (DNI-470): the reads a governed write and its undo make
/// before they write. Scope is passed per call.
final governedDocReaderProvider = FutureProvider<GovernedDocReader?>((
  ref,
) async {
  final handles = await _readyHandles(ref);
  if (handles == null) return null;
  return FirestoreChangeLogRepository(firestore: handles.firestore);
}, retry: (retryCount, error) => null);

/// [GovernedIntentRepository] over the active account's Firestore handle,
/// or null while not ready.
///
/// C0 stub, filled by DNI-470 (1.8).
final governedIntentRepositoryProvider =
    FutureProvider<GovernedIntentRepository?>(
      (ref) => c0Stub('DNI-470', 'governedIntentRepositoryProvider'),
      retry: (retryCount, error) => null,
    );

/// [LearningWritePort] over the active account's Firestore handle, or null
/// while not ready. The chunked batch commit lives on
/// [FirestoreLearningEventRepository] (DNI-469; ruling B4(a)).
final learningWritePortProvider = FutureProvider<LearningWritePort?>((
  ref,
) async {
  final handles = await _readyHandles(ref);
  if (handles == null) return null;
  return FirestoreLearningEventRepository(firestore: handles.firestore);
}, retry: (retryCount, error) => null);

/// The live signed-in uid of the active account — the AD-46 `actor.uid`
/// of an owner write, which the rules require to equal
/// `request.auth.uid` — or null while not ready (DNI-469).
final activeAuthUidProvider = FutureProvider<String?>(
  (ref) async => (await _readyHandles(ref))?.authUid,
  retry: (retryCount, error) => null,
);

/// The AD-50 [PointsAmountReader] over the active account's Firestore
/// handle, or null while not ready (DNI-469).
final pointsAmountReaderProvider = FutureProvider<PointsAmountReader?>((
  ref,
) async {
  final handles = await _readyHandles(ref);
  if (handles == null) return null;
  return FirestorePointsAmountReader(firestore: handles.firestore);
}, retry: (retryCount, error) => null);

/// [OversizedGovernedWritePort] over the active account's callable
/// handle, or null while not ready.
///
/// C0 stub, filled by DNI-470 (1.8).
final oversizedGovernedWritePortProvider =
    FutureProvider<OversizedGovernedWritePort?>(
      (ref) => c0Stub('DNI-470', 'oversizedGovernedWritePortProvider'),
      retry: (retryCount, error) => null,
    );
