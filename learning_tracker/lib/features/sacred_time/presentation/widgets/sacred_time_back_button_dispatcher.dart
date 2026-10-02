/// The router's root back-button dispatcher, which swallows system back
/// while a Sacred Time lock is in force (AD-36, UX-DR-166: "during lock
/// back is blocked"; DNI-481 AC-1).
///
/// [SacredTimeLockOverlay] sits in the `MaterialApp.router` builder slot,
/// ABOVE the router's navigator, so no `PopScope` of its own can stop a
/// pop: the router asks its back-button dispatcher first. This dispatcher
/// answers "handled" while locked, so no route behind the overlay is
/// popped and the app is not left.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A [RootBackButtonDispatcher] that consumes back while [isLocked].
class SacredTimeBackButtonDispatcher extends RootBackButtonDispatcher {
  /// Creates the dispatcher over the lock predicate [isLocked].
  SacredTimeBackButtonDispatcher({required this.isLocked});

  /// Whether a lock is in force now.
  final bool Function() isLocked;

  @override
  Future<bool> didPopRoute() {
    if (isLocked()) return SynchronousFuture<bool>(true);
    return super.didPopRoute();
  }
}

/// [config] with its back-button dispatcher replaced by a
/// [SacredTimeBackButtonDispatcher] over [isLocked]; every other part of
/// the router config is kept.
RouterConfig<T> withSacredTimeBackBlock<T>(
  RouterConfig<T> config, {
  required bool Function() isLocked,
}) => RouterConfig<T>(
  routeInformationProvider: config.routeInformationProvider,
  routeInformationParser: config.routeInformationParser,
  routerDelegate: config.routerDelegate,
  backButtonDispatcher: SacredTimeBackButtonDispatcher(isLocked: isLocked),
);
