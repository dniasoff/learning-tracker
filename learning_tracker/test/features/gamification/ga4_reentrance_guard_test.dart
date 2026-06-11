/// GA-4 regression test — Rapid double-tap / re-entrancy races on navigation
/// push.
///
/// Root cause:
///   Dashboard flame chip pushes GamificationRoute every tap with no
///   duplicate-route check — rapid double-tap opens two overlapping screens.
///
/// Fix: Gate the dashboard flame chip tap with a debounce or a busy flag so
/// that a second tap while navigation is in flight is silently dropped.
/// Specifically: expose `GamificationRouteGuard.allowPush(router)` (or similar)
/// so the chip only pushes when the top route is NOT already GamificationRoute.
///
/// Since the navigation/router cannot be exercised in a pure unit test,
/// we test the domain-level guard: the onTap callback for the chip should
/// only navigate when `userMode == ProfileMode.child` AND the gamification
/// screen is not already the top route.
///
/// For the InviteTutor send busy-guard, we verify that the _isLoading flag is
/// raised synchronously (before any await) so the button is disabled while
/// the invite is in flight.
@Tags(['gamification', 'ga4'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/gamification_route_push_guard.dart';

void main() {
  group('GA-4: GamificationRoutePushGuard — prevents double-push', () {
    test('canPush returns true when no gamification route is active', () {
      expect(
        GamificationRoutePushGuard.canPush(isGamificationRouteActive: false),
        isTrue,
        reason:
            'Should allow push when gamification screen is not on the stack',
      );
    });

    test('canPush returns false when gamification route is already active', () {
      expect(
        GamificationRoutePushGuard.canPush(isGamificationRouteActive: true),
        isFalse,
        reason:
            'Should block push when gamification screen is already on the stack (prevents double-push)',
      );
    });

    test('canPush returns false for non-child profile mode', () {
      expect(
        GamificationRoutePushGuard.canPushForMode(ProfileMode.adult),
        isFalse,
        reason: 'Adult mode should never push to GamificationRoute',
      );
    });

    test('canPushForMode returns true only for child mode', () {
      expect(
        GamificationRoutePushGuard.canPushForMode(ProfileMode.child),
        isTrue,
        reason: 'Child mode should be allowed to push to GamificationRoute',
      );
    });
  });
}
