/// DNI-470 AC-2 and AC-3: `applyGovernedChange` writes field-level
/// patches with one change-log entry per entity, in self-contained batches
/// in action order, and routes an entity over the AD-54 budget online.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/governed_harness.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _cid = 'mishnayos';
const _program = GovernedEntity.mainTrackProgram;
const _order = GovernedEntity.mainTrackOrder;

String _key(String collection, String docId, String field) =>
    ChangedFieldKey(collection, docId, field).key;

/// [n] order docs `order_0` ... of curriculum [_cid].
List<GovernedDocPatch> _orderDocs(int n) => [
  for (var i = 0; i < n; i++)
    patch(_order, 'order_$i', {
      'curriculum_id': _cid,
      'ref': 'Berakhot $i',
      'level': 'mishna',
      'user_sort_order': i,
    }),
];

void main() {
  group('AC-2: field-level writes and one entry per entity', () {
    test('only changed fields plus last_change_id; before holds the cached '
        'value, or null when absent; exact keys', () async {
      final h = GovernedHarness()
        ..seedDoc('profile_programs', _cid, {
          'curriculum_id': _cid,
          'program_id': 'mishna_yomi',
          'tracking_start_date': '2026-01-01',
          'last_change_id': ulidC,
        });

      final result = await h.commands.applyGovernedChange(
        oneEntity(_program, _cid, [
          patch(_program, _cid, {
            'program_id': 'daf',
            'tracking_start_date': '2026-01-01', // unchanged: dropped
            'tracking_start_ref': 'Mishnah Berakhot 1:1', // absent before
          }),
        ]),
      );

      final batch = h.batches.single;
      expect(batch.merges.single.fields, {
        'program_id': 'daf',
        'tracking_start_ref': 'Mishnah Berakhot 1:1',
      });
      expect(batch.entry.before, {
        _key('profile_programs', _cid, 'program_id'): 'mishna_yomi',
        _key('profile_programs', _cid, 'tracking_start_ref'): null,
      });
      expect(batch.entry.after, {
        _key('profile_programs', _cid, 'program_id'): 'daf',
        _key('profile_programs', _cid, 'tracking_start_ref'):
            'Mishnah Berakhot 1:1',
      });
      expect(batch.entry.id, engineUlid(100));
      expect(batch.entry.actionId, engineUlid(100));
      expect(batch.entry.entity, _program);
      expect(batch.entry.entityId, _cid);
      expect(batch.entry.at, governedNow);
      expect(batch.entry.actor, parentActor);
      expect(batch.entry.revertsActionId, isNull);
      expect(h.doc('profile_programs', _cid), {
        'curriculum_id': _cid,
        'program_id': 'daf',
        'tracking_start_date': '2026-01-01',
        'tracking_start_ref': 'Mishnah Berakhot 1:1',
        'last_change_id': engineUlid(100),
      });
      expect(
        result,
        CaptureResult.success(
          changeIds: [engineUlid(100)],
          actionId: engineUlid(100),
        ),
      );
    });

    test(
      'an uncached doc: every before field is null, never a default',
      () async {
        final h = GovernedHarness();
        await h.commands.applyGovernedChange(
          oneEntity(GovernedEntity.goal, '${_cid}_deadline', [
            patch(GovernedEntity.goal, '${_cid}_deadline', {
              'goal_type': 'deadline',
              'target_date': '2027-06-01',
              'curriculum_id': _cid,
            }),
          ]),
        );
        expect(h.batches.single.entry.before.values, everyElement(isNull));
        expect(h.batches.single.entry.before, hasLength(3));
      },
    );

    test(
      'a multi-entity action: one entry per entity, batches in action '
      'order, each self-contained, all carrying the first entry id',
      () async {
        final h = GovernedHarness()
          ..seedDoc('learner_profiles', profileUlid, {
            'display_name': 'Avi',
            'time_zone': 'UTC',
          });

        final result = await h.commands.applyGovernedChange(
          GovernedAction([
            GovernedEntityChange(
              entity: _order,
              entityId: _cid,
              docs: _orderDocs(2),
            ),
            GovernedEntityChange(
              entity: GovernedEntity.learnerSettings,
              entityId: profileUlid,
              docs: [
                patch(GovernedEntity.learnerSettings, profileUlid, {
                  'time_zone': 'Asia/Jerusalem',
                  'in_israel': true,
                }),
              ],
            ),
            GovernedEntityChange(
              entity: GovernedEntity.goal,
              entityId: '${_cid}_pace',
              docs: [
                patch(GovernedEntity.goal, '${_cid}_pace', {
                  'goal_type': 'pace',
                  'pace_value': 2,
                }),
              ],
            ),
          ]),
        );

        final ids = [engineUlid(100), engineUlid(101), engineUlid(102)];
        expect(h.changeLog.issued, ids, reason: 'action order');
        expect(h.batches.map((b) => b.entry.entity), [
          _order,
          GovernedEntity.learnerSettings,
          GovernedEntity.goal,
        ]);
        for (final b in h.batches) {
          expect(b.entry.actionId, ids.first);
          // Self-contained: the entry describes exactly its batch's docs.
          expect(b.entry.after.keys.toSet(), {
            for (final m in b.merges)
              for (final f in m.fields.keys) _key(m.collection, m.docId, f),
          });
        }
        expect(h.batches.first.merges, hasLength(2));
        expect(h.doc('learner_profiles', profileUlid), {
          'display_name': 'Avi',
          'time_zone': 'Asia/Jerusalem',
          'in_israel': true,
          'last_change_id': ids[1],
        });
        expect(result, CaptureResult.success(changeIds: ids, actionId: ids[0]));
      },
    );

    test('an entity with nothing changed writes nothing and does not take '
        'the action id', () async {
      final h = GovernedHarness()
        ..seedDoc('profile_programs', _cid, {'program_id': 'daf'});
      final result = await h.commands.applyGovernedChange(
        GovernedAction([
          GovernedEntityChange(
            entity: _program,
            entityId: _cid,
            docs: [
              patch(_program, _cid, {'program_id': 'daf'}),
            ],
          ),
          GovernedEntityChange(
            entity: _order,
            entityId: _cid,
            docs: _orderDocs(1),
          ),
        ]),
      );
      expect(h.batches.single.entry.entity, _order);
      expect(h.batches.single.entry.actionId, h.batches.single.entry.id);
      expect((result as CaptureSuccess).actionId, h.batches.single.entry.id);

      final noop = await h.commands.applyGovernedChange(
        oneEntity(_program, _cid, [
          patch(_program, _cid, {'program_id': 'daf'}),
        ]),
      );
      expect(noop, const CaptureResult.success());
      expect(h.batches, hasLength(1));
    });

    test('a malformed action is invalid before any read or write', () async {
      final bad = <String, GovernedAction>{
        'doc outside the entity collection': oneEntity(_program, _cid, [
          patch(_order, _cid, {'x': 1}),
        ]),
        'last_change_id set by the caller': oneEntity(_program, _cid, [
          patch(_program, _cid, {'last_change_id': ulidA}),
        ]),
        'settings on another profile doc': oneEntity(
          GovernedEntity.learnerSettings,
          profileUlid,
          [
            patch(GovernedEntity.learnerSettings, ulidA, {'time_zone': 'UTC'}),
          ],
        ),
        'no fields': oneEntity(_program, _cid, [patch(_program, _cid, {})]),
        'a doc twice': oneEntity(_order, _cid, [
          patch(_order, 'o', {'ref': 'a'}),
          patch(_order, 'o', {'ref': 'b'}),
        ]),
        'two sub-track docs': oneEntity(GovernedEntity.subTrack, ulidB, [
          patch(GovernedEntity.subTrack, ulidB, {'name': 'a'}),
          patch(GovernedEntity.subTrack, ulidC, {'name': 'b'}),
        ]),
      };
      for (final MapEntry(key: why, value: action) in bad.entries) {
        final h = GovernedHarness();
        expect(
          await h.commands.applyGovernedChange(action),
          const CaptureResult.rejected(CaptureRejection.invalid),
          reason: why,
        );
        expect(h.reader.reads, isEmpty, reason: why);
        expect(h.changeLog.issued, isEmpty, reason: why);
      }
    });

    test(
      'a value that is not a storage value is invalid before any write',
      () async {
        final h = GovernedHarness();
        final result = await h.commands.applyGovernedChange(
          oneEntity(_order, _cid, [
            ..._orderDocs(1),
            patch(_order, 'bad', {'ref': Object()}),
          ]),
        );
        expect(result, const CaptureResult.rejected(CaptureRejection.invalid));
        expect(h.changeLog.issued, isEmpty);
      },
    );

    test('create on a doc the writer sees is invalid; update on a doc it '
        'cannot see is targetNotFound; neither writes', () async {
      final h = GovernedHarness()
        ..seedDoc('goals', 'g1', {'goal_type': 'pace'});
      expect(
        await h.commands.applyGovernedChange(
          oneEntity(GovernedEntity.goal, 'g1', [
            patch(GovernedEntity.goal, 'g1', {
              'pace_value': 1,
            }, mode: DocMode.create),
          ]),
        ),
        const CaptureResult.rejected(CaptureRejection.invalid),
      );
      expect(
        await h.commands.applyGovernedChange(
          oneEntity(GovernedEntity.goal, 'g2', [
            patch(GovernedEntity.goal, 'g2', {
              'pace_value': 1,
            }, mode: DocMode.update),
          ]),
        ),
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
      expect(h.changeLog.issued, isEmpty);
    });

    test('a doc read failure writes nothing', () async {
      final h = GovernedHarness()
        ..reader.failWith = const FormatException('io');
      expect(
        await h.commands.applyGovernedChange(
          oneEntity(_order, _cid, _orderDocs(1)),
        ),
        const CaptureResult.rejected(CaptureRejection.notSaved),
      );
      expect(h.changeLog.issued, isEmpty);
    });

    test('a sub-track entity goes through SubTrackRepository with its '
        'truthful baseline', () async {
      final h = GovernedHarness();
      h.subTracks.seed(h.scope, [c0SubTrack()]);
      final result = await h.commands.applyGovernedChange(
        oneEntity(GovernedEntity.subTrack, ulidB, [
          patch(GovernedEntity.subTrack, ulidB, {'rate_per_week': 5}),
        ]),
      );
      expect(result, isA<CaptureSuccess>());
      final (_, entry) = h.subTracks.entries.single;
      expect(entry.before, {_key('sub_tracks', ulidB, 'rate_per_week'): 7});
      expect(entry.after, {_key('sub_tracks', ulidB, 'rate_per_week'): 5});
      expect(h.subTracks.tracksOf(h.scope).single.ratePerWeek, 5);
      expect(h.changeLog.issued, isEmpty);
    });

    test('an unknown sub-track is targetNotFound', () async {
      final h = GovernedHarness();
      final result = await h.commands.applyGovernedChange(
        oneEntity(GovernedEntity.subTrack, ulidB, [
          patch(GovernedEntity.subTrack, ulidB, {'rate_per_week': 5}),
        ]),
      );
      expect(
        result,
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
    });
  });

  group('AC-2: batch sequencing, queueing and rejection', () {
    test('a batch the server has not acknowledged is queued, and the next '
        'batch is still issued after it, in order', () async {
      final h = GovernedHarness();
      h.changeLog.hold.add(engineUlid(100));
      final result = await h.commands.applyGovernedChange(
        GovernedAction([
          GovernedEntityChange(
            entity: _order,
            entityId: _cid,
            docs: _orderDocs(1),
          ),
          GovernedEntityChange(
            entity: _program,
            entityId: _cid,
            docs: [
              patch(_program, _cid, {'program_id': 'daf'}),
            ],
          ),
        ]),
      );
      expect(h.changeLog.issued, [engineUlid(100), engineUlid(101)]);
      expect(
        result,
        CaptureResult.success(
          changeIds: [engineUlid(100), engineUlid(101)],
          actionId: engineUlid(100),
          queued: true,
        ),
      );
      h.changeLog.release(engineUlid(100));
    });

    test('a permanently rejected batch is not saved; the other batches of '
        'the action still land with the same action id', () async {
      final h = GovernedHarness();
      h.changeLog.fail[engineUlid(100)] = const PermanentWriteRejection(
        'permission-denied',
      );
      final result = await h.commands.applyGovernedChange(
        GovernedAction([
          GovernedEntityChange(
            entity: _order,
            entityId: _cid,
            docs: _orderDocs(1),
          ),
          GovernedEntityChange(
            entity: _program,
            entityId: _cid,
            docs: [
              patch(_program, _cid, {'program_id': 'daf'}),
            ],
          ),
        ]),
      );
      expect(
        result,
        CaptureResult.success(
          changeIds: [engineUlid(101)],
          actionId: engineUlid(100),
        ),
      );
      expect(h.batches.single.entry.actionId, engineUlid(100));
    });

    test('every batch rejected is notSaved', () async {
      final h = GovernedHarness();
      h.changeLog.fail[engineUlid(100)] = const ChangeLogConflictException('x');
      expect(
        await h.commands.applyGovernedChange(
          oneEntity(_order, _cid, _orderDocs(1)),
        ),
        const CaptureResult.rejected(CaptureRejection.notSaved),
      );
    });
  });

  group('AC-3: an entity over 10 governed docs goes online', () {
    test('exactly 10 docs are one bounded owner batch', () async {
      final h = GovernedHarness();
      await h.commands.applyGovernedChange(
        oneEntity(_order, _cid, _orderDocs(10)),
      );
      expect(h.batches.single.merges, hasLength(10));
      expect(h.oversized.requests, isEmpty);
    });

    test('11 docs offline: onlineRequired, nothing read, written or '
        'applied', () async {
      final h = GovernedHarness();
      h.oversized.online = false;
      final result = await h.commands.applyGovernedChange(
        oneEntity(_order, _cid, _orderDocs(11)),
      );
      expect(result, const CaptureResult.onlineRequired());
      expect(h.changeLog.issued, isEmpty);
      expect(h.reader.reads, isEmpty);
      expect(h.doc('track_learning_order', 'order_0'), isNull);
      expect(h.oversized.requests, isEmpty);
    });

    test('11 docs online: the complete action, in order, with the first '
        'entry id as the action id', () async {
      final h = GovernedHarness();
      final goal = GovernedEntityChange(
        entity: GovernedEntity.goal,
        entityId: '${_cid}_pace',
        docs: [
          patch(GovernedEntity.goal, '${_cid}_pace', {'pace_value': 3}),
        ],
      );
      final order = GovernedEntityChange(
        entity: _order,
        entityId: _cid,
        docs: _orderDocs(11),
      );
      final result = await h.commands.applyGovernedChange(
        GovernedAction([order, goal]),
      );

      final (scope, request) = h.oversized.requests.single;
      expect(scope, c0Scope());
      expect(request.actionId, engineUlid(100));
      expect(request.actorRole, parentActor.role);
      expect(request.revertsActionId, isNull);
      expect(request.entries.map((e) => e.entryId), [
        engineUlid(100),
        engineUlid(101),
      ]);
      expect(request.entries.map((e) => e.change), [order, goal]);
      expect(h.changeLog.issued, isEmpty, reason: 'no owner batch at all');
      expect(
        result,
        CaptureResult.success(
          changeIds: [engineUlid(100), engineUlid(101)],
          actionId: engineUlid(100),
        ),
      );
    });

    test('a callable rejection is notSaved', () async {
      final h = GovernedHarness(oversizedPort: _RejectingPort());
      expect(
        await h.commands.applyGovernedChange(
          oneEntity(_order, _cid, _orderDocs(11)),
        ),
        const CaptureResult.rejected(CaptureRejection.notSaved),
      );
    });
  });

  group('T6 edge cases', () {
    test('AC-8: two devices edit different fields of one doc; both patches '
        'survive and both entries are logged', () async {
      final a = GovernedHarness();
      final b = GovernedHarness(
        actor: childActor,
        firstId: 200,
        store: a.store,
        subTracks: a.subTracks,
      );
      a.seedDoc('profile_programs', _cid, {
        'curriculum_id': _cid,
        'program_id': 'mishna_yomi',
        'tracking_start_date': '2026-01-01',
      });
      await a.commands.applyGovernedChange(
        oneEntity(_program, _cid, [
          patch(_program, _cid, {'program_id': 'daf'}),
        ]),
      );
      await b.commands.applyGovernedChange(
        oneEntity(_program, _cid, [
          patch(_program, _cid, {'tracking_start_date': '2026-02-01'}),
        ]),
      );
      expect(a.doc('profile_programs', _cid), {
        'curriculum_id': _cid,
        'program_id': 'daf',
        'tracking_start_date': '2026-02-01',
        'last_change_id': engineUlid(200),
      });
      expect(a.store.entriesOf(a.scope).map((e) => (e.id, e.actor)), [
        (engineUlid(100), parentActor),
        (engineUlid(200), childActor),
      ]);
    });

    test('an oversized action refused offline is sent whole once online '
        'again', () async {
      final h = GovernedHarness();
      final action = oneEntity(_order, _cid, _orderDocs(12));
      h.oversized.online = false;
      expect(
        await h.commands.applyGovernedChange(action),
        const CaptureResult.onlineRequired(),
      );
      h.oversized.online = true;
      final result = await h.commands.applyGovernedChange(action);
      final (_, request) = h.oversized.requests.single;
      expect(request.entries.single.change.docs, hasLength(12));
      expect(result, isA<CaptureSuccess>());
      expect(h.changeLog.issued, isEmpty);
    });
  });
}

/// A callable that rejects every request for good.
final class _RejectingPort implements OversizedGovernedWritePort {
  @override
  Future<GovernedWriteReceipt> write(
    LearnerScope scope,
    OversizedGovernedWrite request,
  ) async => throw const PermanentWriteRejection('failed-precondition');
}
