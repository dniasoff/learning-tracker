import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/logging/logger.dart';

final _log = AppLogger.instance;

/// Route guard for parent-only write surfaces that live outside parent mode
/// (sub-track create/edit, Story 2.4 / DNI-495 AC-3; ruling: one guard,
/// reused by the later sub-track stories).
///
/// [ChildModeGuard] + [PinGuard] fit routes that exist only in parent mode
/// (a parent supervising a child profile), and they refuse an adult
/// profile. A sub-track form serves both an adult learner (who is the
/// parent) and a parent acting for a child, so this guard asks one
/// question, [isParentSession]: an adult profile, or a child profile whose
/// parent PIN was verified this session. A child without that session —
/// including a direct route or deep link — is refused and stays where it
/// is.
///
/// A parent-only read surface reachable from a page every session can
/// open (the lifetime report under Lifetime, Story 5.2 / DNI-517 AC-2)
/// uses [redirectingTo]: a refused navigation, a deep link included, then
/// lands on that page instead of staying where it was.
///
/// Fails closed: any error resolving the session blocks the navigation.
class ParentSessionGuard extends AutoRouteGuard {
  ParentSessionGuard({
    required Future<bool> Function() isParentSession,
    PageRouteInfo Function()? deniedRoute,
  }) : _isParentSession = isParentSession,
       _deniedRoute = deniedRoute;

  /// A guard that refuses every navigation: the default for routers built
  /// without session wiring (tests that never reach a parent-only route).
  ParentSessionGuard.denyAll() : _isParentSession = _deny, _deniedRoute = null;

  static Future<bool> _deny() async => false;

  final Future<bool> Function() _isParentSession;

  /// Where a refused navigation goes; null stays put.
  final PageRouteInfo Function()? _deniedRoute;

  /// This guard's session check, sending a refused navigation to [route].
  ParentSessionGuard redirectingTo(PageRouteInfo Function() route) =>
      ParentSessionGuard(isParentSession: _isParentSession, deniedRoute: route);

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    var allowed = false;
    try {
      allowed = await _isParentSession();
    } catch (error, stack) {
      _log.error(
        event: 'parent_session_guard_failed_closed',
        exception: error,
        stackTrace: stack,
      );
    }
    if (resolver.isResolved) return;
    resolver.next(allowed);
    final denied = _deniedRoute;
    if (!allowed && denied != null) unawaited(router.navigate(denied()));
  }
}
