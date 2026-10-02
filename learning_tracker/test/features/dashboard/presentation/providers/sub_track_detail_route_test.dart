// Story 2.11 (DNI-502) AC-5: *View {name} →* opens that sub-track's detail
// in the production router, or is not offered at all.
//
// The real AppRouter, not a test router: whenever it registers Story 2.6's
// (DNI-497) `SubTrackDetailRoute`, the Dashboard's detail path must resolve
// to it, top level, carrying the requested sub-track id. While it does not
// (on integ/sub-tracks before DNI-497 merges), the path resolves to nothing,
// so the shortfall card hides the action rather than opening another
// screen. Guards are never run: this is route matching only.
import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_forecast_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/dashboard/forecast_fixtures.dart';

class _AuthGuard extends Mock implements AutoRouteGuard {}

class _ProfileGuard extends Mock implements ProfileGuard {}

class _ChildModeGuard extends Mock implements ChildModeGuard {}

class _PinGuard extends Mock implements PinGuard {}

AppRouter _productionRouter() => AppRouter(
  authGuard: _AuthGuard(),
  profileGuard: _ProfileGuard(),
  childModeGuard: _ChildModeGuard(),
  pinGuard: _PinGuard(),
);

void main() {
  test('the production router resolves the detail path to the requested '
      'sub-track whenever SubTrackDetailRoute is registered', () {
    final router = _productionRouter();
    final registered = router.routeCollection
        .findPathTo('SubTrackDetailRoute')
        .isNotEmpty;

    for (final id in [schoolSubTrackId, rebbeSubTrackId]) {
      final matches = router.matcher.match(subTrackDetailPath(id));
      if (registered) {
        // DNI-497 is in the tree: the Dashboard path must land on it.
        expect(matches, isNotNull, reason: 'no route for $id');
        expect(matches!.single.name, 'SubTrackDetailRoute');
        expect(matches.single.path, subTrackDetailRoutePath);
        expect(matches.single.params.optString('subTrackId'), id);
        expect(resolvesSubTrackDetail(router, id), isTrue);
      } else {
        // Not yet: nothing (no wildcard, no other screen) answers the
        // path, so View is hidden.
        expect(matches, isNull);
        expect(resolvesSubTrackDetail(router, id), isFalse);
      }
    }
  });

  test('the Manage tracks hub path is not mistaken for the detail', () {
    final router = _productionRouter();
    // The hub is registered at the detail path's prefix; only a full match
    // on the detail route counts.
    expect(router.matcher.match('/settings/tracks'), isNotNull);
    expect(resolvesSubTrackDetail(router, ''), isFalse);
  });
}
