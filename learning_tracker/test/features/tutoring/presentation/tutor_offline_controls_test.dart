// Story 4.2 (DNI-510) AC-6 — when the tutor device goes offline with a
// tutor surface open, every tutor write control there (Save, Add, the
// ground actions) is disabled with "Online required" and re-enables when
// connectivity returns, with nothing queued and nothing optimistic. A save
// that loses the connection mid-flight is not replayed on reconnect: only
// an explicit retry sends it again.

@Tags(['tutor_mode'])
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/school_year_sub_track_form_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_hub_section.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/sub_tracks/sub_track_harness.dart';
import '../../../helpers/tutoring/tutor_sub_track_rig.dart';

const _onlineRequired = 'Online required';

Future<void> _settle(WidgetTester tester) async {
  await settleCommands(tester);
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester, TutorSubTrackRig rig, Widget child) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1800);
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    pumpApp(
      overrides: rig.overrides(),
      retry: (_, _) => null,
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

const _form = SizedBox(
  height: 1600,
  child: SchoolYearSubTrackFormScreen(curriculumId: subTrackTestCurriculum),
);

Finder get _save => find.byKey(const ValueKey('subTrackFormSave'));

bool _enabled(WidgetTester tester, Finder finder) =>
    tester.widget<ButtonStyleButton>(finder).onPressed != null;

Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('subTrackFormName')),
    'Cheder',
  );
  await tester.tap(
    find.ancestor(of: find.text('2026–27'), matching: find.byType(ChoiceChip)),
  );
  await tester.pump();
  await tester.ensureVisible(_save);
}

void main() {
  testWidgets('the hub Add disables with "Online required" offline and '
      're-enables on reconnect; nothing is queued', (tester) async {
    final rig = TutorSubTrackRig();
    addTearDown(rig.dispose);
    await _pump(
      tester,
      rig,
      const SubTrackHubSection(curriculumId: subTrackTestCurriculum),
    );
    await _settle(tester);
    final add = find.byKey(const ValueKey('subTrackHubAdd'));
    expect(_enabled(tester, add), isTrue);
    expect(find.text(_onlineRequired), findsNothing);

    rig.setOnline(false);
    await _settle(tester);
    expect(_enabled(tester, add), isFalse);
    expect(find.text(_onlineRequired), findsOneWidget);

    rig.setOnline(true);
    await _settle(tester);
    expect(_enabled(tester, add), isTrue);
    expect(find.text(_onlineRequired), findsNothing);
    expect(rig.invoker.calls, isEmpty);
  });

  testWidgets('an open form keeps its values offline, Save waits for the '
      'connection, and a reconnect saves only when tapped', (tester) async {
    final rig = TutorSubTrackRig();
    addTearDown(rig.dispose);
    await _pump(tester, rig, _form);
    await _settle(tester);
    await _fill(tester);

    rig.setOnline(false);
    await _settle(tester);
    expect(_enabled(tester, _save), isFalse);
    expect(find.text(_onlineRequired), findsOneWidget);
    await tester.tap(_save, warnIfMissed: false);
    await _settle(tester);
    expect(rig.invoker.calls, isEmpty, reason: 'nothing queued');

    rig.setOnline(true);
    await _settle(tester);
    expect(_enabled(tester, _save), isTrue);
    expect(rig.invoker.calls, isEmpty, reason: 'no replay on reconnect');

    await tester.tap(_save);
    await _settle(tester);
    expect(rig.subTrackCalls, hasLength(1));
    expect(rig.hub.repo.tracksOf(rig.hub.scope), hasLength(1));
  });

  testWidgets('a save that loses the connection mid-flight is reported, not '
      'replayed on reconnect; an explicit retry replays the same action', (
    tester,
  ) async {
    final rig = TutorSubTrackRig();
    addTearDown(rig.dispose);
    await _pump(tester, rig, _form);
    await _settle(tester);
    await _fill(tester);

    final gate = Completer<void>();
    rig
      ..hold = gate
      ..failWith = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'connection lost',
      );
    await tester.tap(_save);
    await settleCommands(tester);
    rig.setOnline(false);
    gate.complete();
    await _settle(tester);

    expect(rig.subTrackCalls, hasLength(1));
    expect(rig.hub.repo.tracksOf(rig.hub.scope), isEmpty);
    expect(find.byType(SchoolYearSubTrackForm), findsOneWidget);

    rig
      ..hold = null
      ..failWith = null
      ..setOnline(true);
    await _settle(tester);
    expect(rig.subTrackCalls, hasLength(1), reason: 'not queued for replay');

    ScaffoldMessenger.of(tester.element(_save)).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(_save);
    await _settle(tester);
    final ids = {for (final c in rig.subTrackCalls) c.args['subTrackId']};
    expect(rig.subTrackCalls, hasLength(2));
    expect(ids, hasLength(1), reason: 'the retry replays the frozen create');
    expect(rig.hub.repo.tracksOf(rig.hub.scope), hasLength(1));
  });
}
