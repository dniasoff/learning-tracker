// Story 2.10 (DNI-501) AC-3 integration: an adjusted Up to… run on a
// sub-track, end to end through the real LearningCommands and engine.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_capture_section.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/pump_app.dart';
import 'helpers/capture_harness.dart';
import 'helpers/up_to_fixtures.dart';

/// Tuesday 2026-09-01 20:00Z: unlocked for the UTC fixture learner.
final _evening = engineAt(1200);

Future<CaptureRig> _pump(WidgetTester tester, {CaptureRig? rig}) async {
  final r =
      rig ??
      CaptureRig(
        now: _evening,
        subTracks: [fixtureSubTrack(schoolId, 'School')],
      );
  addTearDown(r.dispose);
  useSurface(tester, phoneSize);
  await tester.pumpWidget(
    pumpApp(
      overrides: r.overrides(),
      child: const Scaffold(
        body: SingleChildScrollView(child: SubTrackCaptureSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return r;
}

String _status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(Key('subTrackRowStatus-$schoolId'))).data!;

Future<void> _pickTargetUntick(WidgetTester tester) async {
  await tester.tap(find.byKey(Key('subTrackUpTo-$schoolId')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Berakhot 2:2'));
  await tester.pump();
  await tester.tap(find.byKey(const Key('upToRowTick-3')));
  await tester.pump();
}

void main() {
  testWidgets('one dated event per included leaf with the sub-track source; '
      'skipped leaves get none; the position becomes the first unticked '
      'leaf; Undo voids all of them', (tester) async {
    final rig = await _pump(tester);
    expect(_status(tester), 'Next: Berakhot 1:1');
    await _pickTargetUntick(tester);
    await tester.tap(find.byKey(const Key('upToRecord')));
    await tester.pumpAndSettle();

    final learns = rig.written.where((e) => e.isLearn).toList();
    expect(
      [for (final e in learns) e.ref],
      [
        'Mishnah Berakhot 1:1',
        'Mishnah Berakhot 1:2',
        'Mishnah Berakhot 1:3',
        'Mishnah Berakhot 2:2',
      ],
    );
    for (final e in learns) {
      expect(e.source, schoolId);
      expect(e.dateState, DateState.dated);
      expect(e.learnedOn, '2026-09-01');
      expect(e.stage, isNull);
    }
    expect(rig.awards, isEmpty, reason: 'no pts_ for a sub-track (AD-50)');
    expect(_status(tester), 'Next: Berakhot 2:1');
    expect(find.text('Recorded 4'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    final voids = rig.written.where((e) => e.isVoid).toList();
    expect({for (final v in voids) v.targetId}, {for (final e in learns) e.id});
    expect(_status(tester), 'Next: Berakhot 1:1');
  });

  testWidgets('the row moves on in the same frame, before the write is '
      'acknowledged', (tester) async {
    final rig = await _pump(tester);
    rig.port.holdNext();
    await _pickTargetUntick(tester);
    await tester.tap(find.byKey(const Key('upToRecord')));
    await tester.pump();
    await tester.pump();
    expect(rig.port.heldCount, 1);
    expect(_status(tester), 'Next: Berakhot 2:1');
    rig.port.release();
    await tester.pumpAndSettle();
    expect(_status(tester), 'Next: Berakhot 2:1');
  });

  testWidgets('a later run never writes an already-recorded leaf twice', (
    tester,
  ) async {
    final rig = await _pump(
      tester,
      rig: CaptureRig(
        now: _evening,
        subTracks: [fixtureSubTrack(schoolId, 'School')],
        seed: [
          engineLearn(
            1,
            'Mishnah Berakhot 1:3',
            source: schoolId,
            minutes: 600,
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(Key('subTrackUpTo-$schoolId')));
    await tester.pumpAndSettle();
    expect(find.text('already recorded'), findsOneWidget);
    await tester.tap(find.text('Berakhot 2:2'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('upToRecord')));
    await tester.pumpAndSettle();
    expect(
      [for (final e in rig.written) e.ref],
      [
        'Mishnah Berakhot 1:1',
        'Mishnah Berakhot 1:2',
        'Mishnah Berakhot 2:1',
        'Mishnah Berakhot 2:2',
      ],
    );
    expect(find.text('All ground recorded'), findsOneWidget);
  });

  testWidgets('Cancel records nothing (AC-4)', (tester) async {
    final rig = await _pump(tester);
    await _pickTargetUntick(tester);
    await tester.tap(find.byKey(const Key('upToCancel')));
    await tester.pumpAndSettle();
    expect(rig.port.attempts, isEmpty);
    expect(_status(tester), 'Next: Berakhot 1:1');
  });

  test('a bulk run chunks at ≤ 450 writes, each chunk self-contained '
      '(AD-54)', () async {
    final leaves = [for (var i = 1; i <= 460; i++) 'Mishnah Long 1:$i'];
    final rig = CaptureRig(
      now: _evening,
      corpus: longCorpus(leaves),
      subTracks: [
        fixtureSubTrack(
          schoolId,
          'School',
          ground: const [NodeEntry(level: 'masechta', ref: 'Mishnah Long')],
        ),
      ],
    );
    addTearDown(rig.dispose);
    await rig.commands.capture(
      curriculumId: engineCurriculum,
      refs: leaves,
      source: schoolId,
      dateState: DateState.dated,
    );
    expect(rig.port.chunks.length, 2);
    for (final c in rig.port.chunks) {
      expect(c.events.length + c.awards.length, lessThanOrEqualTo(450));
    }
    expect(rig.written.length, 460);
    // Main: an event and its pts_ entry are never split across chunks.
    final main = CaptureRig(now: _evening, corpus: longCorpus(leaves));
    addTearDown(main.dispose);
    await main.commands.capture(
      curriculumId: engineCurriculum,
      refs: leaves,
      source: LearningEvent.sourceMain,
      dateState: DateState.dated,
      stage: 1,
    );
    for (final c in main.port.chunks) {
      expect(c.events.length + c.awards.length, lessThanOrEqualTo(450));
      expect(
        {for (final a in c.awards) a.eventId},
        {for (final e in c.events) e.id},
      );
    }
    expect(main.awards.length, 460);
  });
}
