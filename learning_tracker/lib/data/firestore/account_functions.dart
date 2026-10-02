/// Cloud Functions on the ACTIVE account's named app (parent AD-1,
/// DNI-520).
///
/// A callable carries the ID token of whatever user is signed in on the
/// `FirebaseApp` it was built from. With Auth now living only on each
/// account's named app, `FirebaseFunctions.instance` (the default app) would
/// call every function unauthenticated; this resolver builds the callable
/// client from the active account's own app instead, so `context.auth` (and
/// App Check, activated per named app) matches the signed-in account.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway_impl.dart'
    show NotAuthenticatedException;
import 'package:learning_tracker/data/firestore/active_account_providers.dart';

/// Resolves the [FirebaseFunctions] client for the active account at call
/// time. Throws [NotAuthenticatedException] when no account is active.
typedef AccountFunctionsResolver = Future<FirebaseFunctions> Function();

/// The production [AccountFunctionsResolver]. Tests that exercise a
/// callable path inject their own `FirebaseFunctions` mock instead.
final accountFunctionsProvider = Provider<AccountFunctionsResolver>(
  (ref) => () async {
    final handles = await ref.read(activeAccountFirebaseProvider.future);
    if (handles == null) throw const NotAuthenticatedException();
    return FirebaseFunctions.instanceFor(app: handles.app);
  },
);
