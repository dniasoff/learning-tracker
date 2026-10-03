// DNI-507 (Story 3.4) T4 / T5 / T6, AC-3: an adjusted catch-up recorded
// end to end — the engine plans the card (Story 3.2), the Adjust
// selection unticks Beitzah 3:3 in the Rebbe group, and the real
// `LearningCommands.recordCatchUp` (Story 3.3) writes exactly 13
// `catch_up` events on Shabbos with `pts_` entries for the main-track
// events only, the engine keeps Rebbe's position at 3:3, and one
// `catchup_completed` is emitted with mode `adjusted`. A failed write
// leaves nothing counted and can be recorded again without duplicates; an
// expired window writes nothing.
@Tags(['learning'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/services/catch_up_selection_service.dart';

import '../../../../helpers/learner_state/catch_up_adjust_fixtures.dart';
import '../../../../helpers/learner_state/catch_up_card_harness.dart';
import '../../../../helpers/learner_state/catch_up_command_harness.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';

NodeEntry _leaf(String ref) => NodeEntry(level: 'mishnah', ref: ref);

/// Seder Moed › Beitzah, perakim 2 and 3, ten mishnayos each.
InMemoryCorpus _beitzahCorpus() => InMemoryCorpus(engineCurriculum, [
  CorpusNode(moed, [
    CorpusNode(const NodeEntry(level: 'masechta', ref: 'Mishnah Beitzah'), [
      for (final perek in [2, 3])
        CorpusNode(NodeEntry(level: 'chapter', ref: 'Mishnah Beitzah $perek'), [
          for (final r in beitzahRun(perek, 1, 10)) CorpusNode(_leaf(r)),
        ]),
    ]),
  ]),
]);

/// Rebbe: Beitzah perek 3, ten a day, learns on Shabbos.
final _rebbe = SubTrack(
  id: adjustRebbe,
  curriculumId: engineCurriculum,
  name: 'Rebbe',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 70,
  weeksPerYear: 40,
  learnsOnShabbos: true,
  ground: const [NodeEntry(level: 'chapter', ref: 'Mishnah Beitzah 3')],
  lastChangeId: ulidC,
);

LearnerState _state(List<LearningEvent> events, DateTime now) =>
    const LearnerStateEngine().run(
      engineInputs(
        events: events,
        subTracks: [_rebbe],
        settingsHistory: catchUpHistory,
        nowUtc: now,
        corpora: {engineCurriculum: _beitzahCorpus()},
      ),
    );

/// The pending Shabbos card: the planner's four main-track tasks
/// (Beitzah 2:7–2:10, stage 1) and the engine-planned Rebbe leaves.
CatchUpCard<AdjustTask> _card(LearnerState state, DateTime now) {
  final windows = catchUpCardWindowsAt(catchUpHistory, now);
  return projectCatchUpCards<AdjustTask>(
    windows: windows,
    mainTasksByDay: [
      [for (final r in beitzahRun(2, 7, 10)) newTask(r)],
    ],
    curriculumOf: (_) => engineCurriculum,
    state: state,
    subTracks: [_rebbe],
  ).single;
}

/// Shabbos's Rebbe group with Beitzah 3:3 unticked: 13 leaves.
CatchUpAction _adjustedWithout33(CatchUpCard<AdjustTask> card) {
  final selection = adjustSelectionOf(
    card,
  ).toggle(adjustKey(adjustRebbe, catchUpShabbos), beitzah(3, 3));
  return catchUpAdjustedAction(selection, card.window)!;
}

void main() {
  group('AC-3: Record 13 mishnayos', () {
    test('the card plans the Rebbe leaves from the engine position', () {
      final card = _card(_state(const [], catchUpSunday), catchUpSunday);
      final day = card.groups.single.days.single;
      expect(day.subTracks.single.leaves, beitzahRun(3, 1, 10));
      expect(day.mainTasks, hasLength(4));
    });

    test('exactly 13 catch_up events on Shabbos, none for 3:3; points for '
        'the main track only; Rebbe stays at 3:3; one adjusted analytics '
        'event', () async {
      final h = CatchUpCommandHarness();
      final card = _card(_state(const [], h.now), h.now);
      final action = _adjustedWithout33(card);
      expect(action.mode, CatchUpMode.adjusted);

      final result = await h.commands.recordCatchUp(action);
      expect(result, isA<CaptureSuccess>());
      final events = h.written;
      expect(events, hasLength(13));
      expect({for (final e in events) (e.source, e.ref)}, hasLength(13));
      for (final e in events) {
        expect(e.isLearn, isTrue);
        expect(e.dateState, DateState.catchUp);
        expect(e.learnedOn, catchUpShabbos);
        expect(e.actor, catchUpParent);
      }
      expect(events.where((e) => e.ref == beitzah(3, 3)), isEmpty);
      final main = [
        for (final e in events)
          if (e.source == LearningEvent.sourceMain) e,
      ];
      final rebbe = [
        for (final e in events)
          if (e.source == adjustRebbe) e,
      ];
      expect(main.map((e) => e.ref), beitzahRun(2, 7, 10));
      expect(main.every((e) => e.stage == 1), isTrue);
      expect(rebbe, hasLength(9));
      expect(rebbe.every((e) => e.stage == null), isTrue);
      // AD-50: every main-track event has its pts_ entry in its own chunk;
      // no sub-track event earns main-track points.
      expect(
        {for (final a in h.port.awards) a.eventId},
        {for (final e in main) e.id},
      );
      for (final chunk in h.port.chunks) {
        final ids = {for (final e in chunk.events) e.id};
        for (final a in chunk.awards) {
          expect(ids, contains(a.eventId));
        }
      }

      final after = _state(events, h.now);
      expect(
        after[engineCurriculum]!.subTracks[adjustRebbe]!.position,
        beitzah(3, 3),
      );
      expect(catchUpRecorded(card.window, engineCurriculum, after), isTrue);

      final analytics = h.analytics.catchups.single;
      expect(analytics.mode, CatchUpMode.adjusted);
      expect(analytics.curriculumId, engineCurriculum);
      expect(analytics.eventCount, 13);
      expect(analytics.lockedDaysOffered, 1);
      expect(analytics.lockedDaysRecorded, 1);
    });
  });

  group('AC-3 / AC-7: failure, retry and expiry', () {
    test('a rejected write counts nothing and keeps the card; recording '
        'again writes the 13 once with one analytics event', () async {
      final h = CatchUpCommandHarness()..port.rejectAttempts.add(0);
      final card = _card(_state(const [], h.now), h.now);
      final action = _adjustedWithout33(card);
      final failed = await h.commands.recordCatchUp(action);
      expect(failed, const CaptureResult.rejected(CaptureRejection.notSaved));
      expect(h.log().counted.learns, isEmpty);
      expect(h.analytics.catchups, isEmpty);
      expect(await h.pending(), isEmpty);
      expect(
        catchUpRecorded(
          card.window,
          engineCurriculum,
          _state(h.written, h.now),
        ),
        isFalse,
      );

      final retried = await h.commands.recordCatchUp(action);
      expect(retried, isA<CaptureSuccess>());
      final counted = h.log().counted.learns;
      expect(counted, hasLength(13));
      expect({for (final e in counted) (e.source, e.ref)}, hasLength(13));
      expect(h.analytics.catchups, hasLength(1));
    });

    test('an expired window writes no catch-up events', () async {
      final window = catchUpWindow(catchUpShabbosLock(), catchUpHistory);
      final open = _card(_state(const [], catchUpSunday), catchUpSunday);
      final action = _adjustedWithout33(open);
      final h = CatchUpCommandHarness(
        now: window.endUtc.add(const Duration(milliseconds: 1)),
      );
      final result = await h.commands.recordCatchUp(action);
      expect(
        result,
        const CaptureResult.rejected(CaptureRejection.catchUpEnded),
      );
      expect(h.port.attempts, isEmpty);
      expect(h.analytics.catchups, isEmpty);
    });
  });
}
