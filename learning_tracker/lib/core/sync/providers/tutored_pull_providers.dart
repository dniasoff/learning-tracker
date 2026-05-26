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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/core/sync/merge/merge_router.dart';
import 'package:learning_tracker/core/sync/providers/firestore_instance_provider.dart';
import 'package:learning_tracker/core/sync/providers/merge_router_provider.dart';
import 'package:learning_tracker/core/sync/tutored_pull_service.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';

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
  authState: ref.read(authStateProvider),
  firestore: ref.read(firebaseFirestoreProvider),
  auth: ref.read(authRepositoryProvider),
  database: ref.read(userDatabaseProvider),
  mergeRouter: ref.read(mergeRouterProvider),
  parentUid: parentUid,
);

/// Variant that accepts a [WidgetRef] (from [ConsumerWidget] / [ConsumerState]
/// callbacks where only [WidgetRef] is available, not [Ref]).
TutoredPullService buildTutoredPullServiceFromWidget({
  required WidgetRef ref,
  required String parentUid,
}) => _build(
  authState: ref.read(authStateProvider),
  firestore: ref.read(firebaseFirestoreProvider),
  auth: ref.read(authRepositoryProvider),
  database: ref.read(userDatabaseProvider),
  mergeRouter: ref.read(mergeRouterProvider),
  parentUid: parentUid,
);

TutoredPullService _build({
  required AuthState authState,
  required FirebaseFirestore firestore,
  required AuthRepository auth,
  required UserDatabase database,
  required MergeRouter mergeRouter,
  required String parentUid,
}) {
  if (!authState.isCloudBorn) {
    throw StateError(
      'buildTutoredPullService called for a non-cloud-born account',
    );
  }

  // T1.gateway — parent-scoped gateway: reads at users/{parentUid}/…
  final parentGateway = FirestoreGatewayImpl(
    firestore: firestore,
    authRepository: auth,
    activeAccountUid: () => parentUid,
  );

  return TutoredPullService(
    gateway: parentGateway,
    dispatcher: mergeRouter,
    profileDao: database.profileDao,
  );
}
