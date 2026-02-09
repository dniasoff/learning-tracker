import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Route guard that redirects unauthenticated users to the sign-in route.
///
/// When the auth state is `null` (no signed-in user), pushes the sign-in
/// path and aborts the current navigation. When a valid user exists,
/// allows navigation to proceed.
class AuthGuard extends AutoRouteGuard {
  AuthGuard({required FirebaseAuth firebaseAuth})
    : _firebaseAuth = firebaseAuth;

  final FirebaseAuth _firebaseAuth;

  @override
  FutureOr<void> onNavigation(NavigationResolver resolver, StackRouter router) {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      resolver.next();
    } else {
      router.pushPath('/sign-in');
      resolver.next(false);
    }
  }
}
