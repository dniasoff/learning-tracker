// Story 2.9 (DNI-500) AC-7, AC-8 — the Dashboard's "Sub-tracks ({n})"
// section: one neutral summary card per onHome track from the engine
// projection, detail on tap, parent-only Manage, absent when empty and a
// section-local error with retry.
@Tags(['dashboard'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/core/widgets/inline_async_error.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_sub_track_card.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/sub_tracks/dashboard_harness.dart';
import '../../../../helpers/sub_tracks/sub_track_home_fixtures.dart';
import '../../../../helpers/sub_tracks/sub_track_test_engine.dart';

final class _RecordingNavigator implements SubTrackNavigator {
  final List<String> details = [];
  int hub = 0;

  @override
  bool canOpen(SubTrackDestination destination) => true;

  @override
  void openDetail(BuildContext context, SubTrackHomeItem item) =>
      details.add(item.subTrackId);

  @override
  void openGroundPicker(BuildContext context, SubTrackHomeItem item) {}

  @override
  void openHub(BuildContext context) => hub++;

  @override
  void openUpTo(BuildContext context, SubTrackHomeItem item) {}
}

Future<_RecordingNavigator> _pump(
  WidgetTester tester, {
  SubTrackViewerRole role = SubTrackViewerRole.parent,
  Stream<LearnerState> Function()? states,
  bool wired = true,
  DashboardMockRouter? router,
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final engine = SubTrackTestEngine();
  addTearDown(engine.dispose);
  final navigator = _RecordingNavigator();
  await tester.pumpWidget(
    dashboardApp(
      router: router ?? acceptingRouter(),
      subTracks: [
        ...subTrackEngineOverrides(
          engine: engine,
          commands: EngineBackedCommands(engine),
          role: role,
          states: states,
        ),
        // Unwired: the production RoutedSubTrackNavigator.
        if (wired) subTrackNavigatorProvider.overrideWithValue(navigator),
      ],
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1));
  return navigator;
}

double _bar(WidgetTester tester, String id) => tester
    .widget<AnimatedProgressBar>(
      find.byKey(Key('dashboardSubTrackProgress-$id')),
    )
    .value;

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(DashboardFakeRoute());
  });

  testWidgets('one card per onHome track with name, Next, ticked count and '
      'a progress bar of ticked / (ticked + remaining path)', (tester) async {
    await _pump(tester);
    expect(find.text('Sub-tracks (2)'), findsOneWidget);
    expect(find.byType(DashboardSubTrackCard), findsNWidgets(2));
    expect(find.text('Next: Berachos 1:4'), findsOneWidget);
    expect(find.text('Next: Peah 2:1'), findsOneWidget);
    // School: 3 ticked, remaining path 1:4–1:5 (2) → 3/5.
    expect(find.text('3 ticked'), findsOneWidget);
    expect(_bar(tester, schoolId), closeTo(0.6, 1e-9));
    // Rebbe: nothing ticked yet → 0, not NaN.
    expect(find.text('0 ticked'), findsOneWidget);
    expect(_bar(tester, rebbeId), 0);
    // Neutral cards: no sub-track-level status.
    for (final status in ['On track', 'Behind pace', 'Too early to tell']) {
      expect(
        find.descendant(
          of: find.byType(DashboardSubTracksSection),
          matching: find.textContaining(status),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('a card opens its detail (AC-7)', (tester) async {
    final navigator = await _pump(tester);
    await tester.tap(find.text('Rebbe'));
    await tester.pump();
    expect(navigator.details, [rebbeId]);
  });

  testWidgets('production navigator: a card opens the sub-track detail '
      'route (DNI-497), and Manage still opens the hub', (tester) async {
    final router = acceptingRouter();
    await _pump(tester, wired: false, router: router);
    await tester.tap(find.text('Rebbe'));
    await tester.pump();
    final pushed = verify(
      () => router.push<Object?>(
        captureAny(),
        onFailure: any(named: 'onFailure'),
      ),
    ).captured;
    expect(
      pushed.single,
      isA<SubTrackDetailRoute>().having(
        (r) => r.args?.subTrackId,
        'subTrackId',
        rebbeId,
      ),
    );
    final manage = tester.widget<TextButton>(
      find.byKey(const Key('dashboardSubTracksManage')),
    );
    expect(manage.onPressed, isNotNull);
  });

  testWidgets('Manage opens the hub for a parent', (tester) async {
    final navigator = await _pump(tester);
    await tester.tap(find.byKey(const Key('dashboardSubTracksManage')));
    await tester.pump();
    expect(navigator.hub, 1);
  });

  testWidgets('Manage is absent for the child', (tester) async {
    await _pump(tester, role: SubTrackViewerRole.child);
    expect(find.text('Sub-tracks (2)'), findsOneWidget);
    expect(find.byKey(const Key('dashboardSubTracksManage')), findsNothing);
  });

  testWidgets('no active sub-track: the section is absent', (tester) async {
    await _pump(
      tester,
      states: () => Stream.value(
        homeLearnerState([
          homeState(schoolId, onHome: false),
          homeState(rebbeId, onHome: false),
        ]),
      ),
    );
    expect(find.byKey(const Key('dashboardSubTracksSection')), findsNothing);
    expect(find.textContaining('Sub-tracks'), findsNothing);
  });

  testWidgets('a load error is inline in the section with retry; the rest '
      'of the Dashboard renders', (tester) async {
    await _pump(
      tester,
      states: () => Stream<LearnerState>.error(StateError('down')),
    );
    final error = find.byKey(const Key('dashboardSubTracksError'));
    expect(error, findsOneWidget);
    expect(
      find.descendant(of: error, matching: find.text('Retry')),
      findsOneWidget,
    );
    expect(tester.widget(error), isA<InlineAsyncError>());
    expect(find.byType(DashboardSubTrackCard), findsNothing);
    expect(find.text('Active tracks'), findsWidgets);
  });
}
