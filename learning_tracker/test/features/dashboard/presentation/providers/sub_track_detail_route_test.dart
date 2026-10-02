// Story 2.11 (DNI-502) AC-5: *View {name} →* opens that sub-track's detail
// in the production router, or is not offered at all.
//
// The real AppRouter, not a test router: whenever it registers Story 2.6's
// (DNI-497) `SubTrackDetailRoute`, the Dashboard's detail path must resolve
// to it, top level, carrying the requested sub-track id. While it does not
// (on integ/sub-tracks before DNI-497 merges), the path resolves to nothing,
// so the shortfall card hides the action rather than opening another
// screen. DNI-502 therefore depends on DNI-497 to ship AC-5: the
// integ/sub-tracks to dev merge gate is bead learning-tracker-fyh.217.
//
// The routed-tap test pumps the production route table with Story 2.6's
// route contract added and taps View on the real shortfall cards, so the
// push is proven against every route the app has today.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_forecast_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/parent_on_track_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/shortfall_warning_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/dashboard/forecast_fixtures.dart';
import '../../../../helpers/pump_app.dart';

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

  testWidgets('with Story 2.6\'s route contract added to the production '
      'route table, View {name} opens exactly that sub-track\'s detail', (
    tester,
  ) async {
    final router = _ProductionTablePlusDetail();
    await tester.pumpWidget(
      pumpApp(
        theme: AppTheme.lightTheme(),
        routerConfig: router.config(
          deepLinkBuilder: (_) => const DeepLink.path(_dashboardPath),
        ),
        overrides: forecastOverrides(
          state: forecastState([
            forecastCurriculumState(
              projection: const Projection(
                status: ProjectionStatus.behindPace,
                projectedFinish: '2029-03-14',
                deadline: '2029-09-10',
              ),
              dailyTarget: 3,
              subTracks: {
                schoolSubTrackId: shortfallSubTrack(
                  id: schoolSubTrackId,
                  name: 'School',
                  shortfall: 40,
                  lastNode: const NodeEntry(
                    level: 'chapter',
                    ref: 'Mishnah Berakhot 3',
                  ),
                  windowEnd: '2027-07-31',
                ),
                rebbeSubTrackId: shortfallSubTrack(
                  id: rebbeSubTrackId,
                  name: 'Rebbe',
                  shortfall: 12,
                  lastNode: const NodeEntry(
                    level: 'masechta',
                    ref: 'Mishnah Beitzah',
                  ),
                ),
              },
            ),
          ]),
          // The production opener, not a stand-in.
          detailOpener: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final (name, id) in [
      ('Rebbe', rebbeSubTrackId),
      ('School', schoolSubTrackId),
    ]) {
      await tester.tap(find.text('View $name'));
      await tester.pumpAndSettle();

      final top = router.topMatch;
      expect(top.name, 'SubTrackDetailRoute');
      expect(top.path, subTrackDetailRoutePath);
      expect(top.params.optString('subTrackId'), id);
      expect(find.text('sub-track detail $id'), findsOneWidget);

      await router.maybePop();
      await tester.pumpAndSettle();
      expect(router.topMatch.path, _dashboardPath);
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

/// Where the routed-tap test mounts the Dashboard forecast (the shortfall
/// cards under the on-track card), with the production opener.
const _dashboardPath = '/__dni502/dashboard';

/// Lets every navigation through, so the test exercises route matching
/// and the push, not the session guards.
class _PassGuard extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) =>
      resolver.next();
}

/// The production [AppRouter]'s whole route table, plus Story 2.6's
/// (DNI-497) route contract exactly as `story/DNI-497` registers it:
/// top-level `SubTrackDetailRoute` at [subTrackDetailRoutePath], behind the
/// auth guard. It proves the Dashboard's push lands on that route, with the
/// requested id, and that no route already in the app (the Manage tracks
/// hub at the path's prefix, a redirect, a wildcard) answers it first. The
/// real `SubTrackDetailRoute` replaces the contract stand-in once DNI-497
/// is on integ/sub-tracks (bead learning-tracker-fyh.217); the first test
/// above checks the real registration, so a different path or name there
/// fails this file.
class _ProductionTablePlusDetail extends RootStackRouter {
  final _app = AppRouter(
    authGuard: _PassGuard(),
    profileGuard: _ProfileGuard(),
    childModeGuard: _ChildModeGuard(),
    pinGuard: _PinGuard(),
  );

  @override
  List<AutoRoute> get routes => [
    NamedRouteDef(
      name: 'TestForecastDashboardRoute',
      path: _dashboardPath,
      builder: (context, data) => Scaffold(
        body: SingleChildScrollView(
          child: ParentForecastSection(
            belowCard: (f) => ShortfallWarningList(forecast: f),
          ),
        ),
      ),
    ),
    // The real detail screen needs the sub-track providers; the first test
    // checks its registration, this one the push.
    ..._app.routes.where((r) => r.name != 'SubTrackDetailRoute'),
    NamedRouteDef(
      name: 'SubTrackDetailRoute',
      path: subTrackDetailRoutePath,
      guards: [_app.authGuard],
      builder: (context, data) => Text(
        'sub-track detail '
        '${data.inheritedPathParams.getString('subTrackId')}',
      ),
    ),
  ];
}
