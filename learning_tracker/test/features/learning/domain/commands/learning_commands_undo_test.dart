/// DNI-470 AC-4 and AC-5: `undoAction` restores only the fields that still
/// hold the undone values, tombstones a create only while it is the doc's
/// last change, never undoes a settings seed, and an undo is final.
///
/// DNI-514 (Story 4.6) AC-1, AC-3, AC-5 and AC-10: a parent undoes a
/// tutor's action field by field, a later change is left alone and named,
/// a create is undoable again once every later change was undone, and a
/// same-field race is decided by commit order with both actions kept.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_doc_reader.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/governed_action_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/undo_result.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/governed_harness.dart';
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
}
