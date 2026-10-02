import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/logging/logger.dart';

final _log = AppLogger.instance;

/// Route guard that refuses a tutored session: a tutor's device acting for
/// a talmid.
///
/// [ChildModeGuard] deliberately admits a tutored session (a tutor has
/// parent-equivalent management of the talmid), and [PinGuard] then asks
/// for the tutor PIN. A view that only the learner's own parent may open —
/// the parent Change history (Story 4.5 / DNI-513 AC-1, EXPERIENCE role
/// matrix: "Change history + Undo" is parent only) — adds this guard so a
/// tutor cannot reach it, even by deep link.
///
/// Fails closed: any error resolving the session blocks the navigation.
class OwnSessionGuard extends AutoRouteGuard {
  OwnSessionGuard({required bool Function() isTutoredSession})
    : _isTutoredSession = isTutoredSession;

  /// A guard that refuses every navigation: the default for routers built
  /// without session wiring (tests that never reach a parent-only route).
  OwnSessionGuard.denyAll() : _isTutoredSession = _always;

  static bool _always() => true;

  final bool Function() _isTutoredSession;

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    try {
      resolver.next(!_isTutoredSession());
    } catch (error, stack) {
      _log.error(
        event: 'own_session_guard_failed_closed',
        exception: error,
        stackTrace: stack,
      );
      if (!resolver.isResolved) resolver.next(false);
    }
  }
}
