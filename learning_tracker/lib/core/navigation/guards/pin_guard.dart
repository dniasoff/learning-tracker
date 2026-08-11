import 'package:auto_route/auto_route.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';

final _log = AppLogger.instance;

/// Route guard that protects PIN-gated routes for any [PinScope].
///
/// The scope is resolved at navigation time via [getScope] (typically a
/// closure over the currently active profile + the kind of PIN the route
/// needs). The guard then dispatches `hasPin` / `verifyPin` to the
/// scope-appropriate [PinService] method:
///
///   * [PinScopeParent] → `hasProfilePin` / `verifyProfilePin`
///   * [PinScopeTutor]  → `hasTutorPin` / `verifyTutorPin`
///
/// Successful verification primes a per-`(scope, profileId)` session cache so
/// subsequent guarded navigations skip the prompt. Call [lock] (e.g. on
/// sign-out or leaving the gated mode) to invalidate the session.
///
/// Adding a new PIN-gated route is one line — declare a new [PinScope]
/// variant + a `PinService` method pair; route configs just need a closure
/// that returns the new scope.
class PinGuard extends AutoRouteGuard {
  PinGuard({
    required this.pinService,
    required this.promptForPin,
    required this.getScope,
    required this.pinSetupRoute,
    this.onSessionAuthenticated,
    this.onSessionLocked,
  });

  final PinService pinService;

  /// Opens a UI prompt where the user enters and verifies their PIN.
  /// Returns `true` if the PIN was correct, `false` if cancelled or wrong.
  final Future<bool> Function() promptForPin;

  /// Resolves the [PinScope] required by the route being navigated to, or
  /// `null` if access should be denied (e.g. no active profile selected).
  final PinScope? Function() getScope;

  /// Builds the [PageRouteInfo] to push when no PIN has been set yet for the
  /// resolved scope. Injected by the caller (the app-layer router wiring)
  /// rather than imported here — `core/navigation/` must not depend on
  /// `app/router/` (AUD-core-navigation-01: this guard used to import
  /// `core/navigation/app_router.dart`, a re-export shim for
  /// `app/router/app_router.dart`, which itself imports this file — a real
  /// app→core→app import cycle).
  final PageRouteInfo Function() pinSetupRoute;

  /// Called when a `(scope, profileId)` becomes authenticated this session.
  final void Function(PinScope scope)? onSessionAuthenticated;

  /// Called when the PIN session is cleared.
  final void Function()? onSessionLocked;

  /// `(scopeKind, profileId)` that successfully entered its PIN in the
  /// current session. Parent and tutor scopes are tracked independently so
  /// authenticating one does not grant the other.
  PinScope? _authenticatedScope;

  /// Invalidates the cached session, forcing the next guarded navigation to
  /// prompt for the PIN again.
  void lock() {
    _authenticatedScope = null;
    onSessionLocked?.call();
  }

  /// Marks the parent-mode PIN as authenticated for [profileId] in the
  /// current session. Convenience wrapper for flows that verify the parent
  /// PIN outside the guard (e.g. PIN entry route).
  void markAuthenticated(String profileId) {
    _authenticatedScope = PinScope.parent(profileId);
    onSessionAuthenticated?.call(_authenticatedScope!);
  }

  /// Marks an arbitrary [scope] as authenticated for the current session.
  void markScopeAuthenticated(PinScope scope) {
    _authenticatedScope = scope;
    onSessionAuthenticated?.call(scope);
  }

  @override
  Future<void> onNavigation(
    NavigationResolver resolver,
    StackRouter router,
  ) async {
    // Fail-safe wrapper (no-lockout invariant): `promptForPin` and the PIN-setup
    // route can throw (e.g. PinLockoutException after too many attempts, or a
    // secure-storage error). An unhandled throw would escape onNavigation and
    // leave AutoRoute's resolver completer un-completed forever — a permanent
    // hang on a PIN-gated route. This is a SECURITY gate, so on any unexpected
    // error we fail CLOSED (block the navigation): the user stays on the current
    // screen and can retry, rather than being stranded or silently let through.
    try {
      final scope = getScope();
      if (scope == null) {
        resolver.next(false);
        return;
      }

      if (_authenticatedScope == scope) {
        resolver.next(true);
        return;
      }

      final hasPinSet = await _hasPin(scope);
      if (!hasPinSet) {
        final result = await router.push<bool>(pinSetupRoute());
        final ok = result ?? false;
        if (ok) {
          _authenticatedScope = scope;
          onSessionAuthenticated?.call(scope);
        }
        resolver.next(ok);
        return;
      }

      final verified = await promptForPin();
      if (verified) {
        _authenticatedScope = scope;
        onSessionAuthenticated?.call(scope);
      }
      resolver.next(verified);
    } catch (error, stack) {
      _log.error(
        event: 'pin_guard_failed_closed',
        exception: error,
        stackTrace: stack,
      );
      if (!resolver.isResolved) resolver.next(false);
    }
  }

  Future<bool> _hasPin(PinScope scope) {
    return switch (scope) {
      PinScopeParent(:final profileId) => pinService.hasProfilePin(profileId),
      PinScopeTutor(:final profileId) => pinService.hasTutorPin(profileId),
    };
  }
}
