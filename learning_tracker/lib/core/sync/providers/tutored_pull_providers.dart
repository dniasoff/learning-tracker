// tutored_pull_providers.dart — T1.gateway + T1.trigger (Riverpod layer)
//
// Wires the parent-scoped [FirestoreGatewayImpl] and the [TutoredPullService].
//
// Design: the parent-scoped gateway cannot be stored at provider-construction
// time because the parentUid is only known at talmid-entry time.  Instead we
// expose a factory function [buildTutoredPullService] that callers invoke at
// entry time with the concrete parentUid.  The own-data gateway in
// outbox_providers.dart is unchanged.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/firestore_gateway_impl.dart';
import 'package:learning_tracker/core/sync/providers/firestore_instance_provider.dart';
import 'package:learning_tracker/core/sync/providers/merge_router_provider.dart';
import 'package:learning_tracker/core/sync/tutored_pull_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';

/// Build a [TutoredPullService] scoped to [parentUid]'s Firestore namespace.
///
/// Call this at talmid-entry time (inside a callback that has [Ref] or
/// [WidgetRef] access).  The resulting service is used for a single pull
/// session and then discarded — it is NOT cached in Riverpod state.
///
/// The parent-scoped [FirestoreGatewayImpl] is a mirror of the one in
/// outbox_providers.dart, but with `activeAccountUid` fixed to [parentUid]
/// so all Firestore paths read from `users/{parentUid}/…`.  The own-data
/// gateway (and outbox) are completely untouched.
TutoredPullService buildTutoredPullService({
  required Ref ref,
  required String parentUid,
}) {
  final authState = ref.read(authStateProvider);
  if (!authState.isCloudBorn) {
    throw StateError(
      'buildTutoredPullService called for a non-cloud-born account',
    );
  }

  final firestore = ref.read(firebaseFirestoreProvider);
  final auth = ref.read(authRepositoryProvider);
  final database = ref.read(userDatabaseProvider);
  final mergeRouter = ref.read(mergeRouterProvider);

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
