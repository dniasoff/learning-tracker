// Story 4.2 (DNI-510) AC-2 — a tutor in tutor mode with editing access,
// online, uses the parent's shared Manage tracks surfaces: the tutor-mode
// bar reads "Tutor mode · {tutor name}" with Switch; the Sub-tracks group,
// the school-year form, the ground edits and the lifecycle actions all
// save through TutorWriteService (`tutorUpsertSubTrack`), never the owner
// commands or a client Firestore write, and a change shows only after the
// callable has succeeded.
//
// Main-track settings: study days, program and the deadline goal already
// save through TutorGovernedWrites (DNI-486, tutor_governed_writes_test /
// s1_tutored_write_router_test); the main-track order, the stage set and
// the scope have no contract-sound tutor callable yet and stay disabled
// (beads learning-tracker-fyh.226 / .227 / .212).

@Tags(['tutor_mode'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_shell.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_detail_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_lifecycle_sync_provider.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/screens/school_year_sub_track_form_screen.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_hub_section.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state_fixtures.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/sub_tracks/sub_track_harness.dart';
import '../../../helpers/tutoring/tutor_learning_harness.dart';
import '../../../helpers/tutoring/tutor_sub_track_rig.dart';

const _rebbeId = '01JT7T0SV0RRRRRRRRRRRRRRRA';

SubTrack _rebbe({List<NodeEntry> ground = const []}) => SubTrack(
  id: _rebbeId,
  curriculumId: subTrackTestCurriculum,
  name: 'Rebbe',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 5,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: ulidC,
);

/// Lets the real tutor commands (root-zone timers) and the mirror settle.
Future<void> _settle(WidgetTester tester) async {
  await settleCommands(tester);
  await tester.pumpAndSettle();
}

Future<void> _pumpForm(WidgetTester tester, TutorSubTrackRig rig) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    pumpApp(
      overrides: rig.overrides(),
      retry: (_, _) => null,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SchoolYearSubTrackFormScreen(
                    curriculumId: subTrackTestCurriculum,
                  ),
                ),
              ),
              child: const Text('open-form'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open-form'));
  await _settle(tester);
}

Finder _chip(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip));

void main() {
  testWidgets('the tutor-mode bar reads "Tutor mode · {tutor name}" with '
      'Switch (UX-DR-38)', (tester) async {
    const selection = TutoredProfileSelection(
      profileId: profileUlid,
      ownerUid: tutorFixtureOwnerUid,
      grantId: tutorFixtureGrantId,
      permissions: TutorPermissions(canEditLearning: true),
      tutorOwnProfileId: 'tutor-own-profile',
    );
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          activeTutoredProfileSelectionProvider.overrideWith(
            () => FixedTutoredSelection(selection),
          ),
          profileListStreamProvider.overrideWith(
            (ref) => Stream.value([
              LearnerProfileEntity(
                profileId: 'tutor-own-profile',
                displayName: tutorRigTutorName,
                mode: ProfileMode.adult,
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
              ),
            ]),
          ),
        ],
        child: const Scaffold(body: TutorModeIndicatorBar()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tutor mode · $tutorRigTutorName'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('tutorModeIndicatorBarSwitch'))),
      isA<Size>().having((s) => s.height, 'height', greaterThanOrEqualTo(48)),
    );
  });

  testWidgets('the Sub-tracks group opens for the tutor with Add enabled and '
      'no note', (tester) async {
    final rig = TutorSubTrackRig(seed: [_rebbe()]);
    addTearDown(rig.dispose);
    await tester.pumpWidget(
      pumpApp(
        overrides: rig.overrides(),
        retry: (_, _) => null,
        child: const Scaffold(
          body: SingleChildScrollView(
            child: SubTrackHubSection(curriculumId: subTrackTestCurriculum),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Rebbe'), findsOneWidget);
    final add = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('subTrackHubAdd')),
    );
    expect(add.onPressed, isNotNull);
    expect(find.byKey(const Key('tutorWriteNote')), findsNothing);
    expect(find.byKey(const Key('tutorDisabledControl')), findsNothing);
  });

  testWidgets('a school-year sub-track created from the shared form is one '
      'tutorUpsertSubTrack create, shown only after the callable answered', (
    tester,
  ) async {
    final rig = TutorSubTrackRig();
    addTearDown(rig.dispose);
    await _pumpForm(tester, rig);
    await tester.enterText(
      find.byKey(const ValueKey('subTrackFormName')),
      'Cheder',
    );
    await tester.tap(_chip('2026–27'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('subTrackFormSave')));
    await tester.tap(find.byKey(const ValueKey('subTrackFormSave')));
    await _settle(tester);

    final call = rig.subTrackCalls.single;
    expect(call.args['op'], 'create');
    expect(call.args['grantId'], tutorFixtureGrantId);
    expect(call.args['ownerUid'], tutorFixtureOwnerUid);
    expect((call.args['fields'] as Map)['name'], 'Cheder');
    // The row reached the talmid's mirror through the server only: the
    // owner write path (applyGovernedChange) was never used.
    expect(rig.hub.repo.calls, isEmpty);
    expect(rig.hub.repo.tracksOf(rig.hub.scope).single.academicYear, 2026);
    expect(find.byType(SchoolYearSubTrackForm), findsNothing);
  });

  test('a ground reorder or removal is one tutorUpsertSubTrack edit with no '
      'optimistic order while the callable is in flight', () async {
    final rig = TutorSubTrackRig(
      seed: [
        _rebbe(ground: const [peah, berakhot1]),
      ],
    );
    addTearDown(rig.dispose);
    final container = ProviderContainer(overrides: rig.overrides());
    addTearDown(container.dispose);
    final sub = container.listen(
      subTrackGroundEditorProvider(_rebbeId),
      (_, _) {},
    );
    addTearDown(sub.close);

    final editor = container.read(
      subTrackGroundEditorProvider(_rebbeId).notifier,
    );
    final saved = editor.commit(
      const [berakhot1, peah],
      prior: const [peah, berakhot1],
    );
    expect(sub.read().pending, isNull, reason: 'no optimistic order');
    expect(sub.read().busy, isTrue, reason: 'controls held');
    expect(await saved, isTrue);

    final call = rig.subTrackCalls.single;
    expect(call.args['op'], 'edit');
    expect((call.args['fields'] as Map)['ground'], [
      {'level': 'chapter', 'ref': 'Mishnah Berakhot 1'},
      {'level': 'masechta', 'ref': 'Mishnah Peah'},
    ]);
    expect(rig.hub.repo.tracksOf(rig.hub.scope).single.ground, const [
      berakhot1,
      peah,
    ]);
    expect(sub.read().busy, isFalse);
  });

  test(
    'End, Delete and Add next year go through tutorUpsertSubTrack',
    () async {
      final school = SubTrack(
        id: ulidD,
        curriculumId: subTrackTestCurriculum,
        name: 'School',
        type: SubTrackType.schoolYear,
        academicYear: 2026,
        windowStart: '2026-09-01',
        windowEnd: '2027-07-31',
        ratePerWeek: 8,
        weeksPerYear: 36,
        learnsOnShabbos: true,
        ground: const [],
        lastChangeId: ulidE,
      );
      final rig = TutorSubTrackRig(seed: [school, _rebbe()]);
      addTearDown(rig.dispose);
      final container = ProviderContainer(overrides: rig.overrides());
      addTearDown(container.dispose);

      final next = await saveNextYearSubTrack(
        container.read,
        const SubTrackDraft(
          curriculumId: subTrackTestCurriculum,
          name: 'School',
          type: SubTrackType.schoolYear,
          academicYear: 2027,
          windowStart: '2027-09-01',
          windowEnd: '2028-07-31',
          ratePerWeek: 8,
          weeksPerYear: 36,
          learnsOnShabbos: true,
          ground: [],
        ),
        sourceId: ulidD,
        yearLabel: '2027–28',
      );
      expect(next, isA<CaptureSuccess>());
      expect(await rig.commands.endSubTrack(_rebbeId), isA<CaptureSuccess>());
      expect(await rig.commands.deleteSubTrack(ulidD), isA<CaptureSuccess>());

      expect(
        [for (final c in rig.subTrackCalls) c.args['op']],
        ['create', 'end', 'delete'],
      );
      expect(rig.hub.repo.calls, isEmpty, reason: 'no owner write');
      final stored = {
        for (final t in rig.hub.repo.tracksOf(rig.hub.scope)) t.id: t,
      };
      expect(stored[_rebbeId]!.endReason, SubTrackEndReason.ended);
      expect(stored[ulidD]!.endReason, SubTrackEndReason.deleted);
      expect(stored.values.where((t) => t.academicYear == 2027), hasLength(1));
    },
  );
}
