/// DNI-470 AC-4 and AC-5: `undoAction` restores only the fields that still
/// hold the undone values, tombstones a create only while it is the doc's
/// last change, never undoes a settings seed, and an undo is final.
///
/// DNI-514 (Story 4.6) AC-1, AC-3, AC-5 and AC-10: a parent undoes a
/// tutor's action field by field, a later change is left alone and named,
/// a create is undoable again once every later change was undone, and a
/// same-field race is decided by commit order with both actions kept.
/// AC-6 / AC-7 (events): undo of a capture voids only its still-counted,
/// unlocked members under the capture's first event id, once; undo of a
/// void re-copies its target once.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_doc_reader.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/governed_action_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/undo_result.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learning_commands.dart';
import '../../../../helpers/learner_state/governed_harness.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _cid = 'mishnayos';
const _program = GovernedEntity.mainTrackProgram;
const _goal = GovernedEntity.goal;
const _goalId = '${_cid}_deadline';

ChangedFieldKey _k(String collection, String docId, String field) =>
    ChangedFieldKey(collection, docId, field);

/// A parent harness and a child harness on the SAME store (two devices).
(GovernedHarness, GovernedHarness) _twoDevices() {
  final parent = GovernedHarness();
  final child = GovernedHarness(
    actor: childActor,
    firstId: 200,
    store: parent.store,
    subTracks: parent.subTracks,
  );
  return (parent, child);
}

GovernedAction _programChange(Map<String, Object?> fields) =>
    oneEntity(_program, _cid, [patch(_program, _cid, fields)]);

const _rav = Actor(
  uid: 'rav-uid',
  role: ActorRole.tutor,
  displayName: 'Rav Cohen',
);
const _days = GovernedEntity.mainTrackStudyDays;

/// A parent harness and a tutor harness on the SAME store.
(GovernedHarness, GovernedHarness) _parentAndTutor() {
  final parent = GovernedHarness();
  final tutor = GovernedHarness(
    actor: _rav,
    firstId: 200,
    store: parent.store,
    subTracks: parent.subTracks,
  );
  return (parent, tutor);
}

GovernedAction _deadline(String date) => oneEntity(_goal, _goalId, [
  patch(_goal, _goalId, {'target_date': date}),
]);

/// Event commands over a fixed log (the SDK cache) at [now].
final class _Events {
  _Events(List<LearningEvent> log, {DateTime? now})
    : reads = FakeLearningCommandReads(
        history: c0SettingsHistory(),
        log: log,
        corpora: {engineCurriculum: mishnayosCorpus()},
      ) {
    commands = DefaultLearningCommands(
      scope: c0Scope(),
      actor: parentActor,
      reads: reads,
      writePort: port,
      gate: const LockWindowCaptureGate(),
      analytics: RecordingLearningAnalytics(),
      failureReporter: RecordingLearningFailureReporter(),
      clock: () => now ?? engineAt(600),
      newUlid: (_) => engineUlid(_seq++),
      ackWait: const Duration(milliseconds: 40),
      pointsWait: const Duration(milliseconds: 40),
    );
    addTearDown(commands.dispose);
  }

  final FakeLearningCommandReads reads;
  final port = InMemoryLearningWritePort();
  late final DefaultLearningCommands commands;
  int _seq = 30000;

  List<LearningEvent> get written => [for (final c in port.chunks) ...c.events];

  /// Shows everything committed so far in the read log.
  void sync() {
    final all = {...reads.eventLog, ...written};
    reads.eventLog
      ..clear()
      ..addAll(all);
  }

  /// The engine's distinct learnt count over the current log.
  int distinctLearnt() => const LearnerStateEngine()
      .run(engineInputs(events: reads.eventLog))[engineCurriculum]!
      .distinctLearnt;
}

/// A reader that hands out [store]'s current doc and, on the first read,
/// runs [interleave] AFTER taking that snapshot: a write that commits
/// between the undo's read and its own commit.
final class _RacingReader implements GovernedDocReader {
  _RacingReader(this.inner, this.interleave);

  final GovernedDocReader inner;
  Future<void> Function()? interleave;

  @override
  Future<Map<String, Object?>?> currentDoc(
    LearnerScope scope,
    String collection,
    String docId,
  ) async {
    final snapshot = await inner.currentDoc(scope, collection, docId);
    final race = interleave;
    interleave = null;
    if (race != null) await race();
    return snapshot;
  }

  @override
  Future<ChangeLogEntry?> entry(LearnerScope scope, String entryId) =>
      inner.entry(scope, entryId);
}

/// A child-session learn of [ref] at minute 0 (one capture).
LearningEvent _childLearn(int id, String ref) => LearningEvent.learn(
  id: engineUlid(id),
  curriculumId: engineCurriculum,
  ref: ref,
  source: LearningEvent.sourceMain,
  dateState: DateState.dated,
  learnedOn: '2026-09-01',
  recordedAt: engineAt(0),
  actor: childActor,
);

/// [_Events] on a child session.
final class _ChildEvents {
  _ChildEvents(List<LearningEvent> log)
    : reads = FakeLearningCommandReads(
        history: c0SettingsHistory(),
        log: log,
        corpora: {engineCurriculum: mishnayosCorpus()},
      ) {
    commands = DefaultLearningCommands(
      scope: c0Scope(),
      actor: childActor,
      reads: reads,
      writePort: port,
      gate: const LockWindowCaptureGate(),
      analytics: RecordingLearningAnalytics(),
      failureReporter: RecordingLearningFailureReporter(),
      clock: () => engineAt(600),
      newUlid: (_) => engineUlid(_seq++),
      ackWait: const Duration(milliseconds: 40),
      pointsWait: const Duration(milliseconds: 40),
    );
    addTearDown(commands.dispose);
  }

  final FakeLearningCommandReads reads;
  final port = InMemoryLearningWritePort();
  late final DefaultLearningCommands commands;
  int _seq = 30000;
}

void main() {
  group('AC-4: field-level undo keeps concurrent edits', () {
    test('restores only the fields still equal to after; the others are '
        'changed since, by the actor of the latest change', () async {
      final (parent, child) = _twoDevices();
      parent.seedDoc('profile_programs', _cid, {
        'curriculum_id': _cid,
        'program_id': 'mishna_yomi',
        'tracking_start_date': '2026-01-01',
      });
      await parent.commands.applyGovernedChange(
        _programChange({
          'program_id': 'daf',
          'tracking_start_date': '2026-02-01',
        }),
      );
      final a = engineUlid(100);
      await child.commands.applyGovernedChange(
        _programChange({'program_id': 'amud'}),
      );

      final result = await parent.commands.undoAction(a);

      final undo = parent.batches.last;
      expect(undo.entry.revertsActionId, a);
      expect(undo.entry.id, engineUlid(101));
      expect(undo.entry.actionId, engineUlid(101));
      expect(undo.entry.before, {
        _k('profile_programs', _cid, 'tracking_start_date').key: '2026-02-01',
      });
      expect(undo.entry.after, {
        _k('profile_programs', _cid, 'tracking_start_date').key: '2026-01-01',
      });
      expect(parent.doc('profile_programs', _cid), {
        'curriculum_id': _cid,
        'program_id': 'amud',
        'tracking_start_date': '2026-01-01',
        'last_change_id': engineUlid(101),
      });
      expect(
        result,
        CaptureResult.success(
          changeIds: [engineUlid(101)],
          actionId: engineUlid(101),
          changedSince: [
            ChangedSinceField(
              _k('profile_programs', _cid, 'program_id'),
              childActor,
            ),
          ],
        ),
      );
    });

    test('a restored absent field is cleared (null), not defaulted', () async {
      final h = GovernedHarness()
        ..seedDoc('profile_programs', _cid, {'program_id': 'daf'});
      await h.commands.applyGovernedChange(
        _programChange({'tracking_start_ref': 'Mishnah Berakhot 1:1'}),
      );
      await h.commands.undoAction(engineUlid(100));
      expect(h.doc('profile_programs', _cid)!['tracking_start_ref'], isNull);
      expect(h.batches.last.entry.after, {
        _k('profile_programs', _cid, 'tracking_start_ref').key: null,
      });
    });

    test('every member entity is undone in one action, each entry '
        'reverting A', () async {
      final h = GovernedHarness()
        ..seedDoc('profile_programs', _cid, {'program_id': 'a'})
        ..seedDoc('learner_profiles', profileUlid, {'time_zone': 'UTC'});
      await h.commands.applyGovernedChange(
        GovernedAction([
          GovernedEntityChange(
            entity: _program,
            entityId: _cid,
            docs: [
              patch(_program, _cid, {'program_id': 'b'}),
            ],
          ),
          GovernedEntityChange(
            entity: GovernedEntity.learnerSettings,
            entityId: profileUlid,
            docs: [
              patch(GovernedEntity.learnerSettings, profileUlid, {
                'time_zone': 'Asia/Jerusalem',
              }),
            ],
          ),
        ]),
      );
      final result = await h.commands.undoAction(engineUlid(100));
      final undo = h.batches.skip(2).toList();
      expect(undo.map((b) => b.entry.revertsActionId), [
        engineUlid(100),
        engineUlid(100),
      ]);
      expect(undo.map((b) => b.entry.actionId).toSet(), {engineUlid(102)});
      expect(h.doc('profile_programs', _cid)!['program_id'], 'a');
      expect(h.doc('learner_profiles', profileUlid)!['time_zone'], 'UTC');
      expect((result as CaptureSuccess).changeIds, hasLength(2));
    });

    test('undo of a create tombstones the doc while its last_change_id is '
        'still the create', () async {
      final h = GovernedHarness();
      await h.commands.applyGovernedChange(
        oneEntity(_goal, _goalId, [
          patch(_goal, _goalId, {
            'goal_type': 'deadline',
            'target_date': '2027-06-01',
            'curriculum_id': _cid,
          }),
        ]),
      );
      final result = await h.commands.undoAction(engineUlid(100));
      final undo = h.batches.last.entry;
      expect(undo.revertsActionId, engineUlid(100));
      expect(undo.after, {_k('goals', _goalId, 'ended_at').key: governedNow});
      expect(undo.before, {_k('goals', _goalId, 'ended_at').key: null});
      expect(h.doc('goals', _goalId)!['ended_at'], governedNow);
      expect(h.doc('goals', _goalId)!['target_date'], '2027-06-01');
      expect((result as CaptureSuccess).changedSince, isEmpty);
    });

    test('a stale create (changed since) is not tombstoned: every field is '
        'changed since and nothing is written', () async {
      final (parent, child) = _twoDevices();
      await parent.commands.applyGovernedChange(
        oneEntity(_goal, _goalId, [
          patch(_goal, _goalId, {
            'goal_type': 'deadline',
            'target_date': '2027-06-01',
            'curriculum_id': _cid,
          }),
        ]),
      );
      await child.commands.applyGovernedChange(
        oneEntity(_goal, _goalId, [
          patch(_goal, _goalId, {'target_date': '2027-09-01'}),
        ]),
      );
      final batches = parent.batches.length;

      final result = await parent.commands.undoAction(engineUlid(100));

      expect(parent.batches, hasLength(batches));
      expect(parent.doc('goals', _goalId)!['ended_at'], isNull);
      expect(
        result,
        CaptureResult.success(
          changedSince: [
            ChangedSinceField(_k('goals', _goalId, 'goal_type'), childActor),
            ChangedSinceField(_k('goals', _goalId, 'target_date'), childActor),
            ChangedSinceField(
              _k('goals', _goalId, 'curriculum_id'),
              childActor,
            ),
          ],
        ),
      );
    });

    test('the changed-since actor is unknown when the latest entry cannot '
        'be read', () async {
      final h = GovernedHarness()
        ..seedDoc('profile_programs', _cid, {'program_id': 'a'});
      await h.commands.applyGovernedChange(_programChange({'program_id': 'b'}));
      h.seedDoc('profile_programs', _cid, {
        'program_id': 'c',
        'last_change_id': ulidE,
      });
      final result = await h.commands.undoAction(engineUlid(100));
      expect(
        (result as CaptureSuccess).changedSince.single.changedBy,
        unknownChangeActor,
      );
    });

    test('a learnerSettings seed entry (before all-null) offers no undo; a '
        'later settings change does', () async {
      final h = GovernedHarness();
      final seed = ChangeLogEntry(
        id: ulidA,
        entity: GovernedEntity.learnerSettings,
        entityId: profileUlid,
        actionId: ulidA,
        before: {
          'learner_profiles/$profileUlid.time_zone': null,
          'learner_profiles/$profileUlid.in_israel': null,
        },
        after: {
          'learner_profiles/$profileUlid.time_zone': 'UTC',
          'learner_profiles/$profileUlid.in_israel': false,
        },
        at: t0,
        actor: parentActor,
      );
      h.store.seed(h.scope, [seed]);
      h.seedDoc('learner_profiles', profileUlid, {
        'time_zone': 'UTC',
        'in_israel': false,
        'last_change_id': ulidA,
      });
      expect(DefaultGovernedLearningCommands.isSettingsSeed(seed), isTrue);

      expect(
        await h.commands.undoAction(ulidA),
        const CaptureResult.rejected(CaptureRejection.undoNotOffered),
      );
      expect(h.batches, isEmpty);

      await h.commands.applyGovernedChange(
        oneEntity(GovernedEntity.learnerSettings, profileUlid, [
          patch(GovernedEntity.learnerSettings, profileUlid, {
            'in_israel': true,
          }),
        ]),
      );
      expect(
        await h.commands.undoAction(engineUlid(100)),
        isA<CaptureSuccess>(),
      );
      expect(h.doc('learner_profiles', profileUlid)!['in_israel'], isFalse);
    });

    test('an undo whose restore spans more than 10 docs goes online with '
        'reverts_action_id, and offline is onlineRequired', () async {
      final big = GovernedHarness(firstId: 300);
      for (var i = 0; i < 11; i++) {
        big.seedDoc('track_learning_order', 'o$i', {'user_sort_order': i});
      }
      big.store.seed(big.scope, [
        ChangeLogEntry(
          id: ulidA,
          entity: GovernedEntity.mainTrackOrder,
          entityId: _cid,
          actionId: ulidA,
          before: {
            for (var i = 0; i < 11; i++)
              'track_learning_order/o$i.user_sort_order': i + 100,
          },
          after: {
            for (var i = 0; i < 11; i++)
              'track_learning_order/o$i.user_sort_order': i,
          },
          at: t0,
          actor: parentActor,
        ),
      ]);
      big.oversized.online = false;
      expect(
        await big.commands.undoAction(ulidA),
        const CaptureResult.onlineRequired(),
      );
      big.oversized.online = true;
      await big.commands.undoAction(ulidA);
      final (_, request) = big.oversized.requests.single;
      expect(request.revertsActionId, ulidA);
      expect(request.entries.single.change.docs, hasLength(11));
      expect(big.batches, isEmpty);
    });
  });

  group('AC-5: an undo is final', () {
    test('undoing an undo is rejected before any write; the undone action '
        'is marked reverted for every device', () async {
      final h = GovernedHarness()
        ..seedDoc('profile_programs', _cid, {'program_id': 'a'});
      await h.commands.applyGovernedChange(_programChange({'program_id': 'b'}));
      await h.commands.undoAction(engineUlid(100));
      expect(
        await h.store.watchIsReverted(h.scope, engineUlid(100)).first,
        isTrue,
      );
      final issued = List.of(h.changeLog.issued);
      final reads = List.of(h.reader.reads);

      expect(
        await h.commands.undoAction(engineUlid(101)),
        const CaptureResult.rejected(CaptureRejection.undoIsFinal),
      );
      expect(h.changeLog.issued, issued);
      expect(h.reader.reads, reads, reason: 'rejected before any doc read');
    });

    test('an action already undone offers no second undo', () async {
      final h = GovernedHarness()
        ..seedDoc('profile_programs', _cid, {'program_id': 'a'});
      await h.commands.applyGovernedChange(_programChange({'program_id': 'b'}));
      await h.commands.undoAction(engineUlid(100));
      expect(
        await h.commands.undoAction(engineUlid(100)),
        const CaptureResult.rejected(CaptureRejection.undoNotOffered),
      );
      expect(h.batches, hasLength(2));
    });

    test('an unknown or malformed action id writes nothing', () async {
      final h = GovernedHarness();
      expect(
        await h.commands.undoAction(ulidE),
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
      expect(
        await h.commands.undoAction('nope'),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(h.changeLog.issued, isEmpty);
    });
  });

  group('DNI-514 AC-1/AC-3: a parent undoes a tutor action field by field', () {
    test('a fully eligible tutor action is reverted by one parent action: '
        'one entry per entity, a new action id, each reverting it', () async {
      final (parent, tutor) = _parentAndTutor();
      parent
        ..seedDoc('goals', _goalId, {
          'goal_type': 'deadline',
          'target_date': '2027-07-01',
          'curriculum_id': _cid,
        })
        ..seedDoc('study_day_configs', _cid, {
          'curriculum_id': _cid,
          'study_days': [0, 1, 2],
        });
      await tutor.commands.applyGovernedChange(
        GovernedAction([
          ..._deadline('2027-06-01').changes,
          ...oneEntity(_days, _cid, [
            patch(_days, _cid, {
              'study_days': [0, 1],
            }),
          ]).changes,
        ]),
      );
      final a = engineUlid(200);

      final result = UndoResult.of(await parent.commands.undoAction(a));

      final undo = parent.batches.skip(2).map((b) => b.entry).toList();
      expect(undo, hasLength(2));
      expect(undo.map((e) => e.actionId).toSet(), {engineUlid(100)});
      expect(undo.map((e) => e.revertsActionId).toSet(), {a});
      expect(undo.map((e) => e.actor.role).toSet(), {ActorRole.parent});
      expect(undo.map((e) => e.entity), [_goal, _days]);
      expect(parent.doc('goals', _goalId)!['target_date'], '2027-07-01');
      expect(parent.doc('study_day_configs', _cid)!['study_days'], [0, 1, 2]);
      expect(result, isA<UndoApplied>());
      expect((result as UndoApplied).isPartial, isFalse);
      expect(await parent.store.watchIsReverted(parent.scope, a).first, isTrue);
    });

    test('a deadline changed again since is left alone and named; the '
        "action's other fields are still reverted", () async {
      final (parent, tutor) = _parentAndTutor();
      parent
        ..seedDoc('goals', _goalId, {
          'goal_type': 'deadline',
          'target_date': '2027-07-01',
          'curriculum_id': _cid,
        })
        ..seedDoc('study_day_configs', _cid, {
          'curriculum_id': _cid,
          'study_days': [0, 1, 2],
        });
      await tutor.commands.applyGovernedChange(
        GovernedAction([
          ..._deadline('2027-06-01').changes,
          ...oneEntity(_days, _cid, [
            patch(_days, _cid, {
              'study_days': [0, 1],
            }),
          ]).changes,
        ]),
      );
      final a = engineUlid(200);
      await tutor.commands.applyGovernedChange(_deadline('2027-06-15'));

      final result = UndoResult.of(await parent.commands.undoAction(a));

      expect(parent.doc('goals', _goalId)!['target_date'], '2027-06-15');
      expect(parent.doc('study_day_configs', _cid)!['study_days'], [0, 1, 2]);
      final undo = parent.batches.last.entry;
      expect(undo.entity, _days);
      expect(undo.revertsActionId, a);
      expect(
        parent.batches.where((b) => b.entry.revertsActionId == a),
        hasLength(1),
        reason: 'target_date is not written',
      );
      final applied = result as UndoApplied;
      expect(applied.isPartial, isTrue);
      expect(applied.changedSince, [
        ChangedSinceField(_k('goals', _goalId, 'target_date'), _rav),
      ]);
      expect(applied.changedSince.single.changedBy.displayName, 'Rav Cohen');
    });

    test('no eligible field: nothing is written, the action is not undone, '
        'and the result is "nothing to undo"', () async {
      final (parent, tutor) = _parentAndTutor();
      parent.seedDoc('goals', _goalId, {
        'goal_type': 'deadline',
        'target_date': '2027-07-01',
        'curriculum_id': _cid,
      });
      await tutor.commands.applyGovernedChange(_deadline('2027-06-01'));
      final a = engineUlid(200);
      await tutor.commands.applyGovernedChange(_deadline('2027-06-15'));
      final batches = parent.batches.length;

      final result = UndoResult.of(await parent.commands.undoAction(a));

      expect(parent.batches, hasLength(batches));
      expect(
        await parent.store.watchIsReverted(parent.scope, a).first,
        isFalse,
      );
      expect(result, isA<UndoNothingToUndo>());
      expect((result as UndoNothingToUndo).changedSince.single.changedBy, _rav);
      // Still undoable later: the guard is per field, not a one-shot.
      await tutor.commands.applyGovernedChange(_deadline('2027-06-01'));
      expect(
        UndoResult.of(await parent.commands.undoAction(a)),
        isA<UndoApplied>(),
      );
      expect(parent.doc('goals', _goalId)!['target_date'], '2027-07-01');
    });
  });

  group('DNI-514 AC-5: a create is undoable once every later change is '
      'undone', () {
    Future<(GovernedHarness, GovernedHarness)> createdThenEdited() async {
      final (parent, tutor) = _parentAndTutor();
      await tutor.commands.applyGovernedChange(
        oneEntity(_goal, _goalId, [
          patch(_goal, _goalId, {
            'goal_type': 'deadline',
            'target_date': '2027-06-01',
            'curriculum_id': _cid,
          }),
        ]),
      );
      await tutor.commands.applyGovernedChange(_deadline('2027-06-15'));
      return (parent, tutor);
    }

    test('the create reports "changed since by Rav Cohen" and writes '
        'nothing; after the edit is undone the create undo tombstones the '
        'doc', () async {
      final (parent, _) = await createdThenEdited();
      final create = engineUlid(200);
      final edit = engineUlid(201);
      final batches = parent.batches.length;

      final first = UndoResult.of(await parent.commands.undoAction(create));
      expect(first, isA<UndoNothingToUndo>());
      expect(
        (first as UndoNothingToUndo).changedSince.map((f) => f.changedBy),
        everyElement(_rav),
      );
      expect(parent.batches, hasLength(batches));

      expect(
        UndoResult.of(await parent.commands.undoAction(edit)),
        isA<UndoApplied>(),
      );
      expect(parent.doc('goals', _goalId)!['target_date'], '2027-06-01');

      final second = UndoResult.of(await parent.commands.undoAction(create));
      expect(second, isA<UndoApplied>());
      expect(parent.doc('goals', _goalId)!['ended_at'], governedNow);
      expect(parent.batches.last.entry.revertsActionId, create);
    });

    test(
      'an undo that leaves the doc unlike the create still blocks it',
      () async {
        final (parent, tutor) = await createdThenEdited();
        await tutor.commands.applyGovernedChange(_deadline('2027-08-01'));
        // Undo only the last edit: the doc is back at 15 Jun, not 1 Jun.
        await parent.commands.undoAction(engineUlid(202));
        expect(parent.doc('goals', _goalId)!['target_date'], '2027-06-15');
        final batches = parent.batches.length;

        final result = UndoResult.of(
          await parent.commands.undoAction(engineUlid(200)),
        );

        expect(result, isA<UndoNothingToUndo>());
        expect(parent.batches, hasLength(batches));
        expect(parent.doc('goals', _goalId)!['ended_at'], isNull);
      },
    );
  });

  group('DNI-514 AC-10: an undo racing a tutor write on the same field', () {
    Future<(GovernedHarness, GovernedHarness, String)> deadlineAction() async {
      final (parent, tutor) = _parentAndTutor();
      parent.seedDoc('goals', _goalId, {
        'goal_type': 'deadline',
        'target_date': '2027-07-01',
        'curriculum_id': _cid,
      });
      await tutor.commands.applyGovernedChange(_deadline('2027-06-01'));
      return (parent, tutor, engineUlid(200));
    }

    test('the tutor commits after the undo: the tutor value stands, both '
        'actions stay in history, and the tutor change is undoable', () async {
      final (parent, tutor, a) = await deadlineAction();
      await parent.commands.undoAction(a);
      await tutor.commands.applyGovernedChange(_deadline('2027-06-15'));

      expect(parent.doc('goals', _goalId)!['target_date'], '2027-06-15');
      final log = parent.store.entriesOf(parent.scope);
      expect(log.where((e) => e.revertsActionId == a), hasLength(1));
      expect(log.where((e) => e.actor == _rav), hasLength(2));
      // Re-reading the undone row: it is Undone, no second undo.
      expect(
        UndoResult.of(await parent.commands.undoAction(a)),
        isA<UndoRefused>(),
      );
    });

    test('the tutor commits between the undo read and its commit: the '
        'later (undo) commit wins, both actions stay, and re-reading the '
        "tutor's row shows the field changed since by the parent", () async {
      final (parent, tutor, a) = await deadlineAction();
      var next = 500;
      final reader = _RacingReader(parent.reader, () async {
        await tutor.commands.applyGovernedChange(_deadline('2027-06-15'));
      });
      final racing = DefaultGovernedLearningCommands(
        scope: parent.scope,
        actor: parentActor,
        changeLog: parent.changeLog,
        subTracks: parent.subTracks,
        reader: reader,
        oversized: parent.oversized,
        clock: () => governedNow,
        newUlid: (_) => engineUlid(next++),
        ackWait: const Duration(milliseconds: 20),
      );

      final result = UndoResult.of(await racing.undoAction(a));

      expect(result, isA<UndoApplied>());
      expect(parent.doc('goals', _goalId)!['target_date'], '2027-07-01');
      final log = parent.store.entriesOf(parent.scope);
      final tutorEdit = log.lastWhere((e) => e.actor == _rav);
      expect(tutorEdit.after.values.single, '2027-06-15');
      expect(log.where((e) => e.revertsActionId == a), hasLength(1));

      final reread = UndoResult.of(
        await parent.commands.undoAction(tutorEdit.actionId),
      );
      expect(reread, isA<UndoNothingToUndo>());
      expect(
        (reread as UndoNothingToUndo).changedSince.single,
        ChangedSinceField(_k('goals', _goalId, 'target_date'), parentActor),
      );
    });
  });

  group('DNI-514 AC-6/AC-7: undo of a learning capture', () {
    const b11 = 'Mishnah Berakhot 1:1';
    const b12 = 'Mishnah Berakhot 1:2';
    const b13 = 'Mishnah Berakhot 1:3';

    test('voids each still-counted event under the first event id, once; '
        'the counts recompute and those voids are final', () async {
      final h = _Events([
        // One capture: one command stamps one recorded_at.
        engineLearn(1, b11),
        engineLearn(2, b12),
        engineLearn(3, b13),
        engineVoid(4, 2, minutes: 3), // already voided before the undo
      ]);
      expect(h.distinctLearnt(), 2);

      final result = UndoResult.of(
        await h.commands.undoEvents([
          engineUlid(3),
          engineUlid(1),
          engineUlid(2),
        ]),
      );

      expect(result, isA<UndoApplied>());
      final voids = h.written;
      expect(voids.every((e) => e.isVoid), isTrue);
      expect(voids.map((e) => e.targetId).toSet(), {
        engineUlid(1),
        engineUlid(3),
      });
      expect(voids.map((e) => e.revertsActionId).toSet(), {engineUlid(1)});
      h.sync();
      expect(h.distinctLearnt(), 0);

      expect(
        await h.commands.undoEvents([
          engineUlid(1),
          engineUlid(2),
          engineUlid(3),
        ]),
        const CaptureResult.rejected(CaptureRejection.undoNotOffered),
      );
      expect(
        await h.commands.undoEvents([voids.first.id]),
        const CaptureResult.rejected(CaptureRejection.undoIsFinal),
      );
      expect(h.written, hasLength(2), reason: 'nothing more written');
    });

    test('a lock-ignored member is skipped, never voided or counted', () async {
      // One command (an un-learn re-issue keeps its node's instant): both
      // recorded together, one effective inside the Shabbos lock.
      final h = _Events([
        engineLearn(1, b11, minutes: 6000, originalMinutes: 0),
        engineLearn(3, b13, minutes: 6000), // inside the Shabbos lock
      ], now: DateTime.utc(2026, 9, 7, 10));
      expect(h.distinctLearnt(), 1);

      await h.commands.undoEvents([engineUlid(1), engineUlid(3)]);

      expect(h.written.single.targetId, engineUlid(1));
      expect(h.written.single.revertsActionId, engineUlid(1));
      h.sync();
      expect(h.distinctLearnt(), 0);
      expect(
        await h.commands.undoEvents([engineUlid(3)]),
        const CaptureResult.rejected(CaptureRejection.lockIgnoredTarget),
      );
    });

    test('undo of a void writes one learn copy at the target instant; a '
        'second undo writes nothing', () async {
      final target = engineLearn(1, b11, minutes: 30);
      final h = _Events([target, engineVoid(2, 1, minutes: 40)]);
      expect(h.distinctLearnt(), 0);

      await h.commands.undoEvents([engineUlid(2)]);

      final copy = h.written.single;
      expect(copy.isLearn, isTrue);
      expect(copy.ref, b11);
      expect(effectiveAt(copy), effectiveAt(target));
      expect(copy.revertsActionId, isNull);
      h.sync();
      expect(h.distinctLearnt(), 1);

      final again = UndoResult.of(await h.commands.undoEvents([engineUlid(2)]));
      expect(again, isA<UndoNothingToUndo>());
      expect(h.written, hasLength(1));
    });
  });

  group('DNI-514 AC-1/AC-6: only a parent undoes, one capture at a time', () {
    const b11 = 'Mishnah Berakhot 1:1';
    const b12 = 'Mishnah Berakhot 1:2';
    const b13 = 'Mishnah Berakhot 1:3';

    test('a child session cannot undo a governed action: rejected before '
        'any read or write, and the action stays undoable', () async {
      final (parent, child) = _twoDevices();
      parent.seedDoc('profile_programs', _cid, {'program_id': 'a'});
      await parent.commands.applyGovernedChange(
        _programChange({'program_id': 'b'}),
      );
      final reads = List.of(child.reader.reads);
      final batches = List.of(child.batches); // the parent's, shared store

      expect(
        await child.commands.undoAction(engineUlid(100)),
        const CaptureResult.rejected(CaptureRejection.undoNotOffered),
      );
      expect(child.reader.reads, reads, reason: 'rejected before any read');
      expect(child.changeLog.issued, isEmpty);
      expect(child.batches, batches);
      expect(child.oversized.requests, isEmpty);
      expect(
        await parent.store.watchIsReverted(parent.scope, engineUlid(100)).first,
        isFalse,
      );
    });

    test('a child session cannot undo an oversized action either: nothing '
        'reaches the online callable', () async {
      final child = GovernedHarness(actor: childActor, firstId: 300);
      for (var i = 0; i < 11; i++) {
        child.seedDoc('track_learning_order', 'o$i', {'user_sort_order': i});
      }
      child.store.seed(child.scope, [
        ChangeLogEntry(
          id: ulidA,
          entity: GovernedEntity.mainTrackOrder,
          entityId: _cid,
          actionId: ulidA,
          before: {
            for (var i = 0; i < 11; i++)
              'track_learning_order/o$i.user_sort_order': i + 100,
          },
          after: {
            for (var i = 0; i < 11; i++)
              'track_learning_order/o$i.user_sort_order': i,
          },
          at: t0,
          actor: parentActor,
        ),
      ]);
      child.oversized.online = true;

      expect(
        await child.commands.undoAction(ulidA),
        const CaptureResult.rejected(CaptureRejection.undoNotOffered),
      );
      expect(child.oversized.requests, isEmpty);
      expect(child.batches, isEmpty);
    });

    test('a child may take back its own capture (the snackbar Undo) but '
        'not a capture someone else recorded', () async {
      final h = _ChildEvents([
        engineLearn(1, b11), // the parent's capture
        _childLearn(2, b12),
        _childLearn(3, b13),
      ]);

      expect(
        await h.commands.undoEvents([engineUlid(1)]),
        const CaptureResult.rejected(CaptureRejection.undoNotOffered),
      );
      expect(h.port.chunks, isEmpty);

      expect(
        await h.commands.undoEvents([engineUlid(2), engineUlid(3)]),
        isA<CaptureSuccess>(),
      );
      final voids = [for (final c in h.port.chunks) ...c.events];
      expect(voids.map((e) => e.targetId).toSet(), {
        engineUlid(2),
        engineUlid(3),
      });
      expect(voids.every((e) => e.actor.role == ActorRole.child), isTrue);
    });

    test('a child session cannot undo a void or an un-learn', () async {
      final h = _ChildEvents([
        _childLearn(1, b11),
        LearningEvent.voidOf(
          id: engineUlid(2),
          targetId: engineUlid(1),
          recordedAt: engineAt(5),
          actor: childActor,
        ),
      ]);

      expect(
        await h.commands.undoEvents([engineUlid(2)]),
        const CaptureResult.rejected(CaptureRejection.undoNotOffered),
      );
      expect(h.port.chunks, isEmpty);
    });

    test('events of two captures are rejected as one undo: nothing is '
        'written and both captures stay undoable', () async {
      final h = _Events([
        engineLearn(1, b11),
        engineLearn(2, b12),
        engineLearn(3, b13, minutes: 5), // a second capture
      ]);

      expect(
        await h.commands.undoEvents([
          engineUlid(1),
          engineUlid(2),
          engineUlid(3),
        ]),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(h.port.chunks, isEmpty);
      expect(h.port.attempts, isEmpty);
      expect(h.distinctLearnt(), 3);

      expect(
        await h.commands.undoEvents([engineUlid(3)]),
        isA<CaptureSuccess>(),
      );
      expect(h.written.single.revertsActionId, engineUlid(3));
      h.sync();
      expect(
        await h.commands.undoEvents([engineUlid(1), engineUlid(2)]),
        isA<CaptureSuccess>(),
      );
      expect(h.written.skip(1).map((e) => e.revertsActionId).toSet(), {
        engineUlid(1),
      });
    });

    test('a parent capture and a child capture at the same instant are two '
        'captures', () async {
      final h = _Events([engineLearn(1, b11), _childLearn(2, b12)]);

      expect(
        await h.commands.undoEvents([engineUlid(1), engineUlid(2)]),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(h.port.chunks, isEmpty);
    });
  });

  group('DNI-514 AC-9: a rejected undo is a pending failure marked undo', () {
    test('a governed undo batch the server refuses', () async {
      final h = GovernedHarness()
        ..seedDoc('profile_programs', _cid, {'program_id': 'a'});
      await h.commands.applyGovernedChange(_programChange({'program_id': 'b'}));
      h.changeLog.fail[engineUlid(101)] = const PermanentWriteRejection(
        'permission-denied',
      );

      final result = UndoResult.of(
        await h.commands.undoAction(engineUlid(100)),
      );

      expect(result, isA<UndoNotSaved>());
      final failure = (await h.commands.watchPendingFailures().first).single;
      expect(failure.isUndo, isTrue);
      expect(failure.changeIds, [engineUlid(101)]);
      expect(
        await h.store.watchIsReverted(h.scope, engineUlid(100)).first,
        isFalse,
        reason: 'the rejected undo left nothing behind',
      );
    });

    test('a governed change that is not an undo is not marked', () async {
      final h = GovernedHarness()
        ..seedDoc('profile_programs', _cid, {'program_id': 'a'});
      h.changeLog.fail[engineUlid(100)] = const PermanentWriteRejection(
        'permission-denied',
      );
      await h.commands.applyGovernedChange(_programChange({'program_id': 'b'}));
      final failure = (await h.commands.watchPendingFailures().first).single;
      expect(failure.isUndo, isFalse);
    });

    test('an event undo chunk the server refuses stays marked across a '
        'failed retry', () async {
      final h = _Events([engineLearn(1, 'Mishnah Berakhot 1:1')]);
      h.port.failNextWith(const PermanentWriteRejection('permission-denied'));

      final result = UndoResult.of(
        await h.commands.undoEvents([engineUlid(1)]),
      );

      expect(result, isA<UndoNotSaved>());
      final failure = (await h.commands.watchPendingFailures().first).single;
      expect(failure.isUndo, isTrue);

      h.port.failNextWith(const PermanentWriteRejection('permission-denied'));
      await h.commands.retry(failure.id);
      final again = (await h.commands.watchPendingFailures().first).single;
      expect(again.id, failure.id);
      expect(again.isUndo, isTrue);
    });
  });
}
