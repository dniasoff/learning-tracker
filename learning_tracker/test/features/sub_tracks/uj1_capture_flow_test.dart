// Story 2.10 (DNI-501) AC-12 integration: UJ-1. Main tasks in the morning;
// at bedtime School Up to… → target → untick 2:1 → Record 4 mishnayos, and
// Rebbe +1. Each source is captured in ≤ 4 taps (SM-4, prd-deviations #15).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_capture_section.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/pump_app.dart';
import 'helpers/capture_harness.dart';
import 'helpers/up_to_fixtures.dart';

/// Tuesday 2026-09-01 08:00Z and 20:00Z (UTC learner, unlocked).
final _morning = engineAt(480);
final _bedtime = engineAt(1200);

void main() {
  testWidgets('UJ-1: School reads Next: Berakhot 2:1; 4 School and 1 Rebbe '
      'events; distinct count rises by the new leaves; the streak is the '
      'morning main learning only; 4 taps and 1 tap', (tester) async {
    final rig = CaptureRig(
      now: _morning,
      subTracks: [
        fixtureSubTrack(schoolId, 'School'),
        fixtureSubTrack(rebbeId, 'Rebbe', ground: const [peah]),
      ],
    );
    addTearDown(rig.dispose);

    // Morning: today's main task, ticked (source main, first stage).
    final main = rig.state.curricula[engineCurriculum]!;
    expect(main.schedulableRefs.first, 'Mishnah Shabbat 1:1');
    await rig.commands.capture(
      curriculumId: engineCurriculum,
      refs: const ['Mishnah Shabbat 1:1'],
      source: LearningEvent.sourceMain,
      dateState: DateState.dated,
      stage: 1,
    );
    final morning = rig.state.curricula[engineCurriculum]!;
    final distinctBefore = morning.learntLeaves.length;
    expect(morning.streak?.current, 1);

    // Bedtime.
    rig.now = _bedtime;
    useSurface(tester, phoneSize);
    await tester.pumpWidget(
      pumpApp(
        overrides: rig.overrides(),
        child: const Scaffold(
          body: SingleChildScrollView(child: SubTrackCaptureSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var schoolTaps = 0;
    Future<void> schoolTap(Finder f) async {
      schoolTaps++;
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await schoolTap(find.byKey(Key('subTrackUpTo-$schoolId')));
    await schoolTap(find.text('Berakhot 2:2'));
    await schoolTap(find.byKey(const Key('upToRowTick-3'))); // 2:1
    expect(find.text('Record 4 mishnayos'), findsOneWidget);
    await schoolTap(find.byKey(const Key('upToRecord')));

    var rebbeTaps = 0;
    rebbeTaps++;
    await tester.tap(find.byKey(Key('subTrackPlusOne-$rebbeId')));
    await tester.pumpAndSettle();

    expect(schoolTaps, 4);
    expect(rebbeTaps, 1);
    expect(
      tester.widget<Text>(find.byKey(Key('subTrackRowStatus-$schoolId'))).data,
      'Next: Berakhot 2:1',
    );

    final bySource = <String, List<String>>{};
    for (final e in rig.written.where((e) => e.isLearn)) {
      (bySource[e.source!] ??= []).add(e.ref!);
    }
    expect(bySource[schoolId], [
      'Mishnah Berakhot 1:1',
      'Mishnah Berakhot 1:2',
      'Mishnah Berakhot 1:3',
      'Mishnah Berakhot 2:2',
    ]);
    expect(bySource[rebbeId], ['Mishnah Peah 1:1']);

    final after = rig.state.curricula[engineCurriculum]!;
    expect(after.learntLeaves.length, distinctBefore + 5);
    expect(after.subTracks[rebbeId]!.position, 'Mishnah Peah 1:2');
    // Sub-track events never extend the streak (AD-40): still the one
    // main day, and only the morning main event earns.
    expect(after.streak?.current, 1);
    expect(after.streak?.lastDay, '2026-09-01');
    expect(rig.awards, hasLength(1));
  });

  test('without the morning main task, the evening sub-track captures '
      'leave no streak (AD-40)', () async {
    final rig = CaptureRig(
      now: _bedtime,
      subTracks: [fixtureSubTrack(schoolId, 'School')],
    );
    addTearDown(rig.dispose);
    await rig.commands.capture(
      curriculumId: engineCurriculum,
      refs: const ['Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:2'],
      source: schoolId,
      dateState: DateState.dated,
    );
    final state = rig.state.curricula[engineCurriculum]!;
    expect(state.learntLeaves, hasLength(2));
    expect(state.streak?.current ?? 0, 0);
  });
}
