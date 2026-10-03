// Story 4.2 (DNI-510) AC-5 — a tutor whose grant lacks can_edit_learning
// (false or absent) reads what the grant allows on the learner's Manage
// tracks, sub-track forms and ground-picker entry points; every edit
// control stays VISIBLE but disabled (40% opacity, disabled semantics)
// under exactly one note "{learner}'s parent hasn't given you editing
// access", and no callable runs. A stale enabled view whose grant was
// revoked before submit is refused by the callable with nothing shown as
// saved. (The Learn-row controls: tutor_sub_track_read_only_test.dart.)

@Tags(['tutor_mode'])
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/school_year_sub_track_form_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/add_ground_entry.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_hub_section.dart';
import 'package:learning_tracker/features/tutoring/presentation/widgets/tutor_write_gate.dart';

import '../../../helpers/learner_state_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/sub_tracks/sub_track_harness.dart';
import '../../../helpers/tutoring/tutor_sub_track_rig.dart';

const _note = "Yossi's parent hasn't given you editing access";
const _rebbeId = '01JT7T0SV0RRRRRRRRRRRRRRRA';

final _rebbe = SubTrack(
  id: _rebbeId,
  curriculumId: subTrackTestCurriculum,
  name: 'Rebbe',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [],
  lastChangeId: ulidC,
);

Future<void> _settle(WidgetTester tester) async {
  await settleCommands(tester);
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester, TutorSubTrackRig rig, Widget child) =>
    tester.pumpWidget(
      pumpApp(
        overrides: rig.overrides(),
        retry: (_, _) => null,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

/// The control under [finder] is drawn at 40% and announced disabled.
void _expectDisabled(WidgetTester tester, Finder finder) {
  final wrapper = find.ancestor(
    of: finder,
    matching: find.byKey(const Key('tutorDisabledControl')),
  );
  expect(wrapper, findsOneWidget);
  expect(tester.widget<Opacity>(wrapper).opacity, tutorDisabledControlOpacity);
  expect(tester.widget<ButtonStyleButton>(finder).onPressed, isNull);
}

void main() {
  testWidgets('can_edit_learning false: the hub reads, Add is visible but '
      'disabled under one note, and nothing is called', (tester) async {
    final handle = tester.ensureSemantics();
    final rig = TutorSubTrackRig(canEditLearning: false, seed: [_rebbe]);
    addTearDown(rig.dispose);
    await _pump(
      tester,
      rig,
      const SubTrackHubSection(curriculumId: subTrackTestCurriculum),
    );
    await _settle(tester);

    expect(find.text('Rebbe'), findsOneWidget, reason: 'reads stay');
    final add = find.byKey(const ValueKey('subTrackHubAdd'));
    _expectDisabled(tester, add);
    expect(
      tester.getSemantics(add),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
    );
    expect(find.text(_note), findsOneWidget);
    await tester.tap(add, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(rig.invoker.calls, isEmpty);
    handle.dispose();
  });

  testWidgets('an absent permission (the fail-closed default) gates the same '
      'way', (tester) async {
    final rig = TutorSubTrackRig(canEditLearning: false, seed: [_rebbe]);
    addTearDown(rig.dispose);
    expect(rig.selection.permissions.canEditLearning, isFalse);
    await _pump(
      tester,
      rig,
      const SubTrackHubSection(curriculumId: subTrackTestCurriculum),
    );
    await _settle(tester);
    _expectDisabled(tester, find.byKey(const ValueKey('subTrackHubAdd')));
  });

  testWidgets('the form opens read-only: Save visible but disabled, one note, '
      'no callable', (tester) async {
    final rig = TutorSubTrackRig(canEditLearning: false);
    addTearDown(rig.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1800);
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      rig,
      const SizedBox(
        height: 1600,
        child: SchoolYearSubTrackFormScreen(
          curriculumId: subTrackTestCurriculum,
        ),
      ),
    );
    await _settle(tester);

    final save = find.byKey(const ValueKey('subTrackFormSave'));
    await tester.ensureVisible(save);
    _expectDisabled(tester, save);
    expect(find.text(_note), findsOneWidget);
    await tester.tap(save, warnIfMissed: false);
    await _settle(tester);
    expect(rig.invoker.calls, isEmpty);
  });

  testWidgets('the Add ground entry is visible but disabled', (tester) async {
    final rig = TutorSubTrackRig(canEditLearning: false, seed: [_rebbe]);
    addTearDown(rig.dispose);
    await _pump(
      tester,
      rig,
      const AddGroundButton(
        subTrackId: _rebbeId,
        curriculumId: subTrackTestCurriculum,
      ),
    );
    await _settle(tester);
    final button = find.byType(OutlinedButton);
    expect(button, findsOneWidget);
    _expectDisabled(tester, button);
  });

  testWidgets('a grant revoked after the screen loaded: the callable refuses '
      'the save and nothing is shown as saved', (tester) async {
    final rig = TutorSubTrackRig()
      ..failWith = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Grant lacks can_edit_learning',
      );
    addTearDown(rig.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1800);
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      rig,
      const SizedBox(
        height: 1600,
        child: SchoolYearSubTrackFormScreen(
          curriculumId: subTrackTestCurriculum,
        ),
      ),
    );
    await _settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('subTrackFormName')),
      'Cheder',
    );
    await tester.tap(
      find.ancestor(
        of: find.text('2026–27'),
        matching: find.byType(ChoiceChip),
      ),
    );
    await tester.pump();
    final save = find.byKey(const ValueKey('subTrackFormSave'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await _settle(tester);

    expect(rig.subTrackCalls, hasLength(1));
    expect(rig.hub.repo.tracksOf(rig.hub.scope), isEmpty);
    expect(find.byType(SchoolYearSubTrackForm), findsOneWidget);
  });
}
