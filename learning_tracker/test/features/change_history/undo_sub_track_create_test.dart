/// DNI-514 AC-4 / AC-5 (integration): a parent undoes a tutor's sub-track
/// create through the governed undo, over the real sub-track commands, the
/// in-memory sub-track and change-log stores and the learner-state engine.
///
/// * AC-4: an unchanged create is tombstoned (`ended_at`, `end_reason =
///   undo`, never deleted); the sub-track leaves Learn and the hub's active
///   group, its unlearnt ground returns to the main track (FR-12) and its
///   learning events still count.
/// * AC-5: after the tutor added ground, undoing the create reports
///   "changed since by Rav Cohen" and writes nothing; once the ground
///   addition is undone, undoing the create succeeds.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/predicates.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/change_history/domain/undo/history_undo_status.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/undo_result.dart';

import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state/governed_harness.dart';
import '../../helpers/learner_state/in_memory_ports.dart';
import '../../helpers/learner_state_fixtures.dart';

const _rav = Actor(
  uid: 'rav-uid',
  role: ActorRole.tutor,
  displayName: 'Rav Cohen',
);

/// The engine fixture's "today" (`engineAt(10000)`).
const _today = '2026-09-07';

/// The sub-track the tutor creates (ULID [ulidD]).
const _subTrackId = ulidD;

final class _World {
  _World() {
    parent = GovernedHarness(store: store, subTracks: subTracks);
    var n = 0;
    tutor = SubTrackCommands(
      scope: parent.scope,
      actor: _rav,
      subTracks: subTracks,
      intent: intent
        ..emit(
          parent.scope,
          LearnerIntent(
            settings: c0Settings,
            mainTracks: {
              engineCurriculum: MainTrackIntent(
                curriculumId: engineCurriculum,
                track: MainTrack(
                  curriculumId: engineCurriculum,
                  state: MainTrackState.active,
                ),
              ),
            },
            goals: const {},
          ),
        ),
      today: () => _today,
      nowUtc: () => engineAt(9000),
      newId: () => '01JTEST000000000000000${(++n).toString().padLeft(4, '0')}',
      ackTimeout: const Duration(milliseconds: 50),
      readTimeout: const Duration(seconds: 2),
    );
    addTearDown(tutor.dispose);
    addTearDown(subTracks.dispose);
    addTearDown(intent.dispose);
  }

  final store = InMemoryChangeLogRepository();
  final subTracks = InMemorySubTrackRepository();
  final intent = InMemoryGovernedIntentRepository();
  late final GovernedHarness parent;
  late final SubTrackCommands tutor;

  /// One sub-track event, learnt by the tutor's talmid: Berakhot 2:1.
  final events = [
    engineLearn(1, 'Mishnah Berakhot 2:1', source: _subTrackId, minutes: 9100),
  ];

  /// Sub-track entries live in the same `change_log` collection as every
  /// other governed entry; the in-memory stores keep them apart, so copy
  /// them into the change-log store the undo reads.
  void syncLog() =>
      store.seed(parent.scope, [for (final (_, e) in subTracks.entries) e]);

  SubTrack get subTrack =>
      subTracks.tracksOf(parent.scope).singleWhere((t) => t.id == _subTrackId);

  Future<String> create() async {
    await tutor.createSubTrack(
      const SubTrackDraft(
        curriculumId: engineCurriculum,
        name: 'Rebbe',
        type: SubTrackType.ongoing,
        windowStart: '2026-09-01',
        ratePerWeek: 2,
        weeksPerYear: 40,
        learnsOnShabbos: false,
        ground: [berakhot2],
      ),
      subTrackId: _subTrackId,
    );
    syncLog();
    return subTracks.entries.last.$2.id;
  }

  Future<UndoResult> undo(String actionId) async {
    final result = UndoResult.of(await parent.commands.undoAction(actionId));
    syncLog();
    return result;
  }

  Map<String, Object?> state() {
    final whole = const LearnerStateEngine().run(
      engineInputs(events: events, subTracks: subTracks.tracksOf(parent.scope)),
    );
    final c = whole[engineCurriculum]!;
    return {
      'schedulable': c.schedulableRefs,
      'learnt': c.learntLeaves,
      'counted': whole.countedEventIds,
      'holds': c.subTracks[_subTrackId]?.holdsGround,
    };
  }
}

void main() {
  test('AC-4: undoing an unchanged create tombstones the sub-track; its '
      'ground returns to the main track and its events still count', () async {
    final w = _World();
    final create = await w.create();
    final live = w.state();
    expect(live['holds'], isTrue);
    expect(live['schedulable'], isNot(contains('Mishnah Berakhot 2:2')));
    expect(onHome(w.subTrack, _today), isTrue);

    final result = await w.undo(create);

    expect(result, isA<UndoApplied>());
    final s = w.subTrack;
    expect(s.endedAt, governedNow);
    expect(s.endReason, SubTrackEndReason.undo);
    expect(s.ground, const [berakhot2], reason: 'a tombstone, not a delete');
    expect(onHome(s, _today), isFalse, reason: 'leaves Learn and the hub');
    expect(holdsGround(s, _today), isFalse);
    final undoEntry = w.subTracks.entries.last.$2;
    expect(undoEntry.revertsActionId, create);
    expect(undoEntry.actor, parentActor);
    expect(
      HistoryUndoIndex(
        entries: w.store.entriesOf(w.parent.scope),
      ).governed([w.subTracks.entries.first.$2]),
      HistoryUndoStatus.undone,
    );

    final ended = w.state();
    expect(ended['holds'], isFalse);
    expect(ended['schedulable'], contains('Mishnah Berakhot 2:2'));
    expect(ended['schedulable'], isNot(contains('Mishnah Berakhot 2:1')));
    expect(ended['learnt'], contains('Mishnah Berakhot 2:1'));
    expect(ended['counted'], {engineUlid(1)});
  });

  test('AC-5: a create with ground added since reports "changed since by '
      'Rav Cohen" and writes nothing; undoing the ground addition first '
      'lets the create undo succeed', () async {
    final w = _World();
    final create = await w.create();
    await w.tutor.editSubTrack(
      _subTrackId,
      const SubTrackEdit(ground: [berakhot2, peah]),
    );
    w.syncLog();
    final groundEdit = w.subTracks.entries.last.$2.id;
    final writes = w.subTracks.calls.length;

    final first = await w.undo(create);

    expect(first, isA<UndoNothingToUndo>());
    final changedSince = (first as UndoNothingToUndo).changedSince;
    expect(changedSince, isNotEmpty);
    expect(changedSince.map((f) => f.changedBy).toSet(), {_rav});
    expect(w.subTracks.calls, hasLength(writes), reason: 'nothing written');
    expect(w.subTrack.isEnded, isFalse);

    expect(await w.undo(groundEdit), isA<UndoApplied>());
    expect(w.subTrack.ground, const [berakhot2]);
    expect(w.subTrack.isEnded, isFalse);

    final second = await w.undo(create);

    expect(second, isA<UndoApplied>());
    expect(w.subTrack.endReason, SubTrackEndReason.undo);
    expect(w.subTrack.ground, const [berakhot2]);
    expect(w.state()['schedulable'], contains('Mishnah Berakhot 2:2'));
  });

  test('a node-level ground entry keeps its storage shape through the '
      'restore', () async {
    // Guards the codec round trip the AC-5 restore relies on: `before`
    // holds the stored ground list, restored verbatim.
    final w = _World();
    await w.create();
    await w.tutor.editSubTrack(
      _subTrackId,
      const SubTrackEdit(
        ground: [
          berakhot2,
          NodeEntry(level: 'mishnah', ref: 'Mishnah Peah 1:1'),
        ],
      ),
    );
    w.syncLog();
    final edit = w.subTracks.entries.last.$2;
    expect(edit.before.values.single, [berakhot2.toStorage()]);
    await w.undo(edit.id);
    expect(w.subTrack.ground, const [berakhot2]);
    expect(w.events.single.isLearn, isTrue);
  });
}
