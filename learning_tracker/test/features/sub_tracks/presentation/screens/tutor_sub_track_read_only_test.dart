// Story 2.9 (DNI-500) AC-9, as Story 4.2 (DNI-510) AC-1 / AC-5 changed it —
// on a tutor device WITHOUT editing access the sub-track rows are
// read-only: every write control is visible but disabled (40%, disabled
// semantics), one note says "{learner}'s parent hasn't given you editing
// access", and no sub-track write reaches LearningCommands. A permitted
// tutor's controls are enabled (tutor_sub_track_capture_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_sub_track_card.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_write_availability.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/sub_tracks/dashboard_harness.dart';
import '../../../../helpers/sub_tracks/sub_track_home_fixtures.dart';
import '../../../../helpers/sub_tracks/sub_track_test_engine.dart';

const _note = "Yossi's parent hasn't given you editing access";

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
          availability: TutorWriteAvailability.noEditAccess,
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

  testWidgets('a groundless and a fully recorded row show Add ground '
      'disabled for a tutor without editing access', (tester) async {
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
      availability: TutorWriteAvailability.noEditAccess,
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
    expect(find.text('All ground recorded'), findsOneWidget);
    expect(
      _dimmed(tester, find.byKey(const Key('subTrackHomeAddGround-$rebbeId'))),
      isTrue,
    );
    expect(find.text(_note), findsOneWidget);
  });

  testWidgets('Dashboard: the cards render for the tutor with Manage and no '
      'read-only note (Story 4.2: the cards hold no write control)', (
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
    expect(find.text(_note), findsNothing);
    expect(find.byKey(const Key('dashboardSubTracksManage')), findsOneWidget);
  });
}
