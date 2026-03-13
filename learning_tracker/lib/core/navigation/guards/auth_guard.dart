import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';

/// Route guard that redirects unauthenticated users to the sign-in route.
///
/// Uses [FirebaseAuth.authStateChanges] for a proper async auth check rather
/// than the synchronous [FirebaseAuth.currentUser], which may not reflect the
/// latest authentication state on first load.
///
/// Uses [StackRouter.replace] so the sign-in page replaces the protected route
/// and does not leave it on the back stack.
class AuthGuard extends AutoRouteGuard {
  AuthGuard({required FirebaseAuth firebaseAuth})
    : _firebaseAuth = firebaseAuth;

  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    final user = await _firebaseAuth.authStateChanges().first;
    if (user != null) {
      resolver.next();
    } else {
      unawaited(router.replace(const SignInRoute()));
      resolver.next(false);
    }
  }
}
