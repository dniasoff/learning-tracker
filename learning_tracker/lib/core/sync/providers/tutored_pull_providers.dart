// tutored_pull_providers.dart — T1.gateway + T1.trigger (Riverpod layer)
//
// Wires the parent-scoped [FirestoreGatewayImpl] and the [TutoredPullService].
//
// Design: the parent-scoped gateway cannot be stored at provider-construction
// time because the parentUid is only known at talmid-entry time.  Instead we
// expose factory functions ([buildTutoredPullService] for Ref callers,
// [buildTutoredPullServiceFromWidget] for WidgetRef callers) that callers
// invoke at entry time with the concrete parentUid.  The own-data gateway in
// outbox_providers.dart is unchanged.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/providers/firestore_instance_provider.dart';
import 'package:learning_tracker/core/sync/providers/merge_router_provider.dart';
import 'package:learning_tracker/core/sync/tutored_mirror_wipe_service.dart';
import 'package:learning_tracker/core/sync/tutored_pull_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;

/// Build a [TutoredPullService] scoped to [parentUid]'s Firestore namespace.
///
/// Call this at talmid-entry time (inside a callback that has [Ref] access).
/// The resulting service is used for a single pull session and then discarded
/// — it is NOT cached in Riverpod state.
///
/// The parent-scoped [FirestoreGatewayImpl] is a mirror of the one in
/// outbox_providers.dart, but with `activeAccountUid` fixed to [parentUid]
/// so all Firestore paths read from `users/{parentUid}/…`.  The own-data
/// gateway (and outbox) are completely untouched.
TutoredPullService buildTutoredPullService({
  required Ref ref,
  required String parentUid,
}) => _build(
  hasFirebaseSession: ref.read(authRepositoryProvider).currentUser != null,
  gateway: FirestoreGatewayImpl(
    firestore: ref.read(firebaseFirestoreProvider),
    authRepository: ref.read(authRepositoryProvider),
    activeAccountUid: () => parentUid,
  ),
  database: ref.read(userDatabaseProvider),
  mergeRouter: ref.read(mergeRouterProvider),
);

/// Variant that accepts a [WidgetRef] (from [ConsumerWidget] / [ConsumerState]
/// callbacks where only [WidgetRef] is available, not [Ref]).
TutoredPullService buildTutoredPullServiceFromWidget({
  required WidgetRef ref,
  required String parentUid,
}) => _build(
  hasFirebaseSession: ref.read(authRepositoryProvider).currentUser != null,
  gateway: FirestoreGatewayImpl(
    firestore: ref.read(firebaseFirestoreProvider),
    authRepository: ref.read(authRepositoryProvider),
    activeAccountUid: () => parentUid,
  ),
  database: ref.read(userDatabaseProvider),
  mergeRouter: ref.read(mergeRouterProvider),
);

TutoredPullService _build({
  required bool hasFirebaseSession,
  required FirestoreGatewayImpl gateway,
  required UserDatabase database,
  required MergeRouter mergeRouter,
  TutoredMirrorWipeService? wipeService,
}) {
  // The pull reads the PARENT's Firestore namespace; authorisation is by the
  // tutor's live Firebase session (Firestore rules check request.auth.uid via
  // hasActiveTutorAccess), NOT by the local app account's tier. Gating on
  // authState.isCloudBorn was the wrong proxy: in a multi-account session the
  // app tier can lag behind a valid Firebase session (the active account DB is
  // mounted after auth-state restore), which would wrongly abort a pull that
  // Firestore would have authorised. Require only a live Firebase session.
  if (!hasFirebaseSession) {
    throw StateError(
      'buildTutoredPullService called without a Firebase session',
    );
  }

  return TutoredPullService(
    gateway: gateway,
    dispatcher: mergeRouter,
    profileDao: database.profileDao,
    wipeService: wipeService,
  );
}

/// Build a [TutoredMirrorWipeService] for the current account.
///
/// [onWipe] is called after each mirror deletion (per grantId) — inject a
/// callback that clears `resolvedTutoredLocalProfileIdProvider` and calls
/// `ActiveTutoredProfileSelection.exit()` when the wiped grant is active.
TutoredMirrorWipeService buildTutoredMirrorWipeService({
  required Ref ref,
  void Function(String grantId)? onWipe,
}) {
  final db = ref.read(userDatabaseProvider);
  return TutoredMirrorWipeService(profileDao: db.profileDao, onWipe: onWipe);
}

/// Variant that accepts a [WidgetRef].
TutoredMirrorWipeService buildTutoredMirrorWipeServiceFromWidget({
  required WidgetRef ref,
  void Function(String grantId)? onWipe,
}) {
  final db = ref.read(userDatabaseProvider);
  return TutoredMirrorWipeService(profileDao: db.profileDao, onWipe: onWipe);
}
