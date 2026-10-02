// DNI-480 (Story 1.18) AC-1, unit level: the engine's AD-50 earning set as
// the points readers consume it. DNI-468 owns `earningEventIds` (ruling
// B4(c)); this file is the story's consume-and-gap test, one scenario that
// exercises every rule together, plus the cross-device cases the readers
// rely on (two devices ticking the same leaf, a replayed capture).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

void main() {
  const engine = LearnerStateEngine();
  final subTrack = engineUlid(900);

  // September 2026: the 1st is a Tuesday. The fixture learner's fail-closed
  // Shabbos lock runs Fri 4th 12:00Z → Sun 6th 01:00Z.
  int on(int day, {int hour = 10}) => (day - 1) * 1440 + hour * 60;
  String sep(int day) => '2026-09-${day.toString().padLeft(2, '0')}';
  final inLock = on(5, hour: 10);

  MainTrackConfigDoc stageDoc(int order, {int delay = 0}) => MainTrackConfigDoc(
    collection: MainTrackConfigDoc.stages,
    docId: '${engineCurriculum}_$order',
    curriculumId: engineCurriculum,
    fields: {
      'stage_order': order,
      'schedule_type': 'delay',
      'delay_days': delay,
    },
  );

  LearnerState run(List<LearningEvent> events) => engine.run(
    engineInputs(
      events: events,
      intents: {
        engineCurriculum: engineIntent(
          stages: [stageDoc(1), stageDoc(2, delay: 1), stageDoc(3, delay: 7)],
        ),
      },
      nowUtc: engineAt(on(20)),
    ),
  );

  LearningEvent learn(
    int id,
    String ref, {
    required int minutes,
    int? stage,
    String source = LearningEvent.sourceMain,
    DateState dateState = DateState.dated,
    int? originalMinutes,
    int day = 1,
  }) => engineLearn(
    id,
    ref,
    minutes: minutes,
    stage: stage,
    source: source,
    dateState: dateState,
    originalMinutes: originalMinutes,
    learnedOn: sep(day),
  );

  Set<String> ids(Iterable<int> ns) => {for (final n in ns) engineUlid(n)};

  test('earningEventIds include only first main learn and eligible scheduled '
      'reviews', () {
    const a = 'Mishnah Berakhot 1:1';
    const b = 'Mishnah Berakhot 1:2';
    const c = 'Mishnah Berakhot 1:3';
    const d = 'Mishnah Berakhot 2:1';
    const e = 'Mishnah Berakhot 2:2';
    const f = 'Mishnah Peah 1:1';
    const g = 'Mishnah Peah 1:2';
    final state = run([
      // a: first main learn earns; its duplicate main tick does not; the
      // due stage-2 review on the 2nd earns once; a second stage-2 review
      // the same day does not.
      learn(1, a, minutes: on(1), stage: 1),
      learn(2, a, minutes: on(1, hour: 11), stage: 1),
      learn(3, a, minutes: on(2), stage: 2, day: 2),
      learn(4, a, minutes: on(2, hour: 12), stage: 2, day: 2),
      // b: a sub-track tick first blocks the later main tick.
      learn(5, b, minutes: on(1, hour: 9), source: subTrack),
      learn(6, b, minutes: on(1, hour: 18), stage: 1),
      // c: before_tracking first blocks the later main tick.
      learn(7, c, minutes: on(1), dateState: DateState.beforeTracking),
      learn(8, c, minutes: on(1, hour: 18), stage: 1),
      // d: the first main learn is voided, so the next counted main learn
      // earns instead.
      learn(9, d, minutes: on(1), stage: 1),
      engineVoid(10, 9, minutes: on(1, hour: 12)),
      learn(11, d, minutes: on(2), stage: 1, day: 2),
      // e: a lock-ignored main learn neither earns nor blocks.
      learn(12, e, minutes: inLock, stage: 1, day: 5),
      learn(13, e, minutes: on(7), stage: 1, day: 7),
      // f: a catch_up main event earns as a first learn; a stage-2 review
      // done before it is due (same day) does not.
      learn(14, f, minutes: on(1), dateState: DateState.catchUp),
      learn(15, f, minutes: on(1, hour: 12), stage: 2),
      // g: an imported copy recorded later but originally earlier than a
      // sub-track tick is ordered by original_recorded_at, so it earns.
      learn(16, g, minutes: on(1, hour: 9), source: subTrack),
      learn(17, g, minutes: on(1, hour: 18), stage: 1, originalMinutes: 480),
    ]);

    expect(state.earningEventIds, ids([1, 3, 11, 13, 14, 17]));
    expect(state.lockIgnoredEventIds, ids([12]));
    expect(state.countedEventIds.containsAll(state.earningEventIds), isTrue);
  });

  test('two devices ticking the same leaf at the same instant earn once, by '
      'event id', () {
    const a = 'Mishnah Berakhot 1:1';
    final state = run([
      learn(31, a, minutes: on(1), stage: 1),
      learn(30, a, minutes: on(1), stage: 1),
    ]);
    expect(state.earningEventIds, ids([30]));
  });

  test('a replayed capture of the same event earns once, and only its pts_ '
      'row counts', () {
    const a = 'Mishnah Berakhot 1:1';
    final event = learn(1, a, minutes: on(1), stage: 1);
    final state = run([event, event]);
    expect(state.earningEventIds, ids([1]));

    final totals = pointsTotals([
      PointsLedgerRow(id: 'pts_${event.id}', amount: 5, eventId: event.id),
      PointsLedgerRow(id: 'pts_${event.id}', amount: 5, eventId: event.id),
    ], state.earningEventIds);
    expect(totals, const PointsTotals(balance: 5, lifetimeEarned: 5));
  });
}
