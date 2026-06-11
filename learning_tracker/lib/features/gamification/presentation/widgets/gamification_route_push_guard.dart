/// GA-4: Guard that prevents double-push of GamificationRoute from the
/// dashboard flame chip.
///
/// Root cause: tapping the chip rapidly in child mode called
/// `context.router.push(const GamificationRoute())` on every tap, pushing
/// two overlapping Gamification screens onto the stack.
///
/// Fix: check whether GamificationRoute is already the top-most route before
/// pushing. The guard is also mode-gated: only child profiles have a
/// Gamification screen (adults have no points).
library;

import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';

/// Pure static helpers so the push logic can be unit-tested without a
/// widget tree or router instance.
class GamificationRoutePushGuard {
  const GamificationRoutePushGuard._();

  /// Returns `true` when it is safe to push GamificationRoute.
  ///
  /// [isGamificationRouteActive] — `true` if the route is already the top of
  /// the current navigation stack (caller must resolve this from the router).
  static bool canPush({required bool isGamificationRouteActive}) =>
      !isGamificationRouteActive;

  /// Returns `true` only for [ProfileMode.child].
  ///
  /// The gamification screen is child-only; for adults the chip is a passive
  /// streak indicator with no navigation.
  static bool canPushForMode(ProfileMode mode) => mode == ProfileMode.child;
}
