// Story 2.9 (DNI-500) AC-9 — on a tutor device the sub-track rows and the
// Dashboard cards are read-only: every write control is visible but
// disabled (40%, disabled semantics), one note explains it, and no
// sub-track write reaches LearningCommands.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_sub_track_card.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/dashboard_harness.dart';
import '../../../../helpers/sub_tracks/sub_track_home_fixtures.dart';
import '../../../../helpers/sub_tracks/sub_track_test_engine.dart';

const _note = 'Editing sub-tracks from a tutor device is coming soon';

bool _dimmed(WidgetTester tester, Finder control) {
  final opacity = find.descendant(of: control, matching: find.byType(Opacity));
  return opacity.evaluate().isNotEmpty &&
      tester.widget<Opacity>(opacity.first).opacity == subTrackDisabledOpacity;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(DashboardFakeRoute());
  });

  testWidgets('Learn rows: +1 and Up to… visible, disabled at 40%, announced '
      'disabled; one note; tapping writes nothing', (tester) async {
    final handle = tester.ensureSemantics();
    final engine = SubTrackTestEngine();
    addTearDown(engine.dispose);
    final commands = EngineBackedCommands(engine);
    await tester.pumpWidget(
      pumpApp(
        overrides: subTrackEngineOverrides(
          engine: engine,
          commands: commands,
          role: SubTrackViewerRole.tutor,
        ),
        child: const Scaffold(
          body: SingleChildScrollView(child: AlsoLearningSection()),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text(_note), findsOneWidget);
    for (final id in [schoolId, rebbeId]) {
      for (final key in ['subTrackHomePlusOne-$id', 'subTrackHomeUpTo-$id']) {
        final control = find.byKey(Key(key));
        expect(control, findsOneWidget);
        expect(_dimmed(tester, control), isTrue, reason: key);
        await tester.tap(control, warnIfMissed: false);
      }
    }
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Record one mishna for School'),
      ),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Record up to, Rebbe')),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );
    await tester.pumpAndSettle();
    expect(commands.inner.calls, isEmpty);
    handle.dispose();
  });

  testWidgets('a groundless row shows Add ground disabled for the tutor; a '
      'fully recorded row exposes no Add ground', (tester) async {
    final engine = SubTrackTestEngine(
      grounds: {schoolId: const [], rebbeId: rebbeLeaves},
      ticked: {rebbeId: rebbeLeaves.toSet()},
    );
    addTearDown(engine.dispose);
    final overrides = subTrackEngineOverrides(
      engine: engine,
      commands: EngineBackedCommands(engine),
      role: SubTrackViewerRole.tutor,
      groundOf: const {schoolId: <NodeEntry>[]},
    );
    await tester.pumpWidget(
      pumpApp(
        overrides: overrides,
        child: const Scaffold(
          body: SingleChildScrollView(child: AlsoLearningSection()),
        ),
      ),
    );
    await _settle(tester);
    final addGround = find.byKey(const Key('subTrackHomeAddGround-$schoolId'));
    expect(addGround, findsOneWidget);
    expect(_dimmed(tester, addGround), isTrue);
    expect(
      find.byKey(const Key('subTrackHomeAddGround-$rebbeId')),
      findsNothing,
    );
    expect(find.text('All ground recorded'), findsOneWidget);
    expect(
      _dimmed(tester, find.byKey(const Key('subTrackHomePlusOne-$rebbeId'))),
      isTrue,
    );
    expect(find.text(_note), findsOneWidget);
  });

  testWidgets('Dashboard: cards render with one note and no Manage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = SubTrackTestEngine();
    addTearDown(engine.dispose);
    await tester.pumpWidget(
      dashboardApp(
        router: acceptingRouter(),
        subTracks: subTrackEngineOverrides(
          engine: engine,
          commands: EngineBackedCommands(engine),
          role: SubTrackViewerRole.tutor,
        ),
      ),
    );
    await _settle(tester);
    expect(find.byType(DashboardSubTrackCard), findsNWidgets(2));
    expect(find.text(_note), findsOneWidget);
    expect(find.byKey(const Key('dashboardSubTracksManage')), findsNothing);
  });
}
