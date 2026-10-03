// Story 2.11 (DNI-502) AC-5: *View {name} →* opens that sub-track's detail
// in the production router.
//
// The real AppRouter, not a test router: Story 2.6's (DNI-497) typed
// `SubTrackDetailRoute` is registered top level, so the Dashboard's push
// lands on it carrying the requested sub-track id. The routed-tap test
// pumps the whole production route table (guards let every navigation
// through) and taps View on the real shortfall cards, so the push reaches
// the real `SubTrackDetailScreen`, not a stand-in. A moved or renamed route
// fails this file.
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/parent_on_track_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/shortfall_warning_card.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/sub_track_detail_screen.dart';
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
  sacredTimeLocationGuard: _AuthGuard(),
);

void main() {
  test('the production router registers SubTrackDetailRoute top level and '
      'matches it with the requested sub-track id', () {
    final router = _productionRouter();
    expect(
      router.routes.map((r) => r.name),
      contains(SubTrackDetailRoute.name),
    );

    for (final id in [schoolSubTrackId, rebbeSubTrackId]) {
      final match = router.matcher.matchByRoute(
        SubTrackDetailRoute(subTrackId: id),
      );
      expect(match, isNotNull, reason: 'no route for $id');
      expect(match!.name, SubTrackDetailRoute.name);
      expect(match.params.optString('subTrackId'), id);
      expect(match.redirectedFrom, isNull);
    }
  });

  testWidgets('in the production route table, View {name} opens exactly '
      'that sub-track\'s detail screen', (tester) async {
    final router = _ProductionTableWithDashboard();
    await tester.pumpWidget(
      pumpApp(
        theme: AppTheme.lightTheme(),
        routerConfig: router.config(
          deepLinkBuilder: (_) => const DeepLink.path(_dashboardPath),
        ),
        overrides:
            forecastOverrides(
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
            ) +
            [
              // The real detail screen renders over a failed read, so this test
              // needs no sub-track data: it proves the route and the id.
              subTrackDetailProvider.overrideWith(
                (ref, id) =>
                    AsyncError(StateError('detail $id'), StackTrace.empty),
              ),
            ],
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
      expect(top.name, SubTrackDetailRoute.name);
      expect(top.params.optString('subTrackId'), id);
      expect(router.currentPath, '/settings/tracks/sub-tracks/$id');
      expect(
        find.byWidgetPredicate(
          (w) => w is SubTrackDetailScreen && w.subTrackId == id,
        ),
        findsOneWidget,
      );

      await router.maybePop();
      await tester.pumpAndSettle();
      expect(router.topMatch.path, _dashboardPath);
    }
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

/// The production [AppRouter]'s whole route table, including Story 2.6's
/// (DNI-497) real `SubTrackDetailRoute`, plus a route that mounts the
/// Dashboard forecast (the shortfall cards under the on-track card). It
/// proves the Dashboard's push lands on that route, with the requested id,
/// and that no route already in the app (the Manage tracks hub at the
/// path's prefix, a redirect, a wildcard) answers it first.
class _ProductionTableWithDashboard extends RootStackRouter {
  final _app = AppRouter(
    authGuard: _PassGuard(),
    profileGuard: _ProfileGuard(),
    childModeGuard: _ChildModeGuard(),
    pinGuard: _PinGuard(),
    sacredTimeLocationGuard: _PassGuard(),
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
    ..._app.routes,
  ];
}
