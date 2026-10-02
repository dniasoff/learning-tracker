/// DNI-476 (Story 1.14) AC-4: "Remove track" and "Re-add" are reversible,
/// logged actions (AD-38 track lifecycle) through
/// `DefaultGovernedLearningCommands.removeTrack` / `reAddTrack`.
///
/// * Remove = ONE action: a `mainTrack` entry setting `ended_at` on
///   `curriculum_tracks/{c}` only, then one `subTrack` tombstone entry
///   (`end_reason: track_deleted`) per non-ended sub-track of that
///   curriculum, all sharing the first entry id as `action_id`, each in its
///   own self-contained batch, in action order.
/// * Re-add = one logged change clearing `ended_at`; the prior config is
///   kept and sub-tracks ended by the removal stay ended (ruling B13).
/// * Neither touches learning events or the points ledger.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/governed_harness.dart';
import '../../../../helpers/learner_state_fixtures.dart';

const _cid = 'mishnayos';

/// A live sub-track [n] of [curriculumId].
SubTrack _subTrack(int n, {String curriculumId = _cid}) => SubTrack(
  id: engineUlid(n),
  curriculumId: curriculumId,
  name: 'Shiur $n',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 7,
  weeksPerYear: 40,
  learnsOnShabbos: true,
  ground: c0SubTrack().ground,
  lastChangeId: engineUlid(900 + n),
);

/// [_subTrack] [n], already ended by its learner.
SubTrack _endedSubTrack(int n) => SubTrack(
  id: engineUlid(n),
  curriculumId: _cid,
  name: 'Shiur $n',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 7,
  weeksPerYear: 40,
  learnsOnShabbos: true,
  ground: c0SubTrack().ground,
  lastChangeId: engineUlid(900 + n),
  endedAt: DateTime.utc(2026, 9),
  endReason: SubTrackEndReason.ended,
);

/// Learning data the lifecycle must never touch.
const _learningEvent = <String, Object?>{
  'kind': 'learn',
  'curriculum_id': _cid,
  'ref': 'Mishnah Berakhot 1:1',
};
const _pointsRow = <String, Object?>{'amount': 10, 'curriculum_id': _cid};

/// A harness with a live mishnayos track (with config), [subTracks], and a
/// learning event and points row that must survive.
GovernedHarness _harness({List<SubTrack> subTracks = const []}) {
  final h = GovernedHarness()
    ..seedDoc('curriculum_tracks', _cid, {
      'curriculum_id': _cid,
      'state': 'active',
      'activated_at': '2026-01-01T00:00:00.000Z',
      'last_change_id': ulidC,
    })
    ..seedDoc('learning_events', engineUlid(500), _learningEvent)
    ..seedDoc('points_ledger', 'pts_${engineUlid(500)}', _pointsRow);
  h.subTracks.seed(h.scope, subTracks);
  return h;
}

void main() {
  group('remove track', () {
    test('one mainTrack entry, then one subTrack tombstone per non-ended '
        'sub-track, all sharing the action id; ended ones are not '
        'tombstoned again', () async {
      final h = _harness(
        subTracks: [
          _subTrack(2),
          _endedSubTrack(3),
          _subTrack(4),
          _subTrack(5, curriculumId: 'bavli'),
        ],
      );

      final result = await h.commands.removeTrack(_cid);

      final success = result as CaptureSuccess;
      final main = h.batches.single.entry;
      final subEntries = [for (final (_, e) in h.subTracks.entries) e];
      expect(main.entity, GovernedEntity.mainTrack);
      expect(main.entityId, _cid);
      expect(main.after, {'curriculum_tracks/mishnayos.ended_at': governedNow});
      expect(subEntries.map((e) => e.entityId), [engineUlid(2), engineUlid(4)]);
      for (final e in subEntries) {
        expect(e.entity, GovernedEntity.subTrack);
        expect(e.after, {
          'sub_tracks/${e.entityId}.ended_at': governedNow,
          'sub_tracks/${e.entityId}.end_reason': 'track_deleted',
        });
      }
      expect({main.actionId, ...subEntries.map((e) => e.actionId)}, {main.id});
      expect(success.actionId, main.id);
      expect(success.changeIds, [main.id, ...subEntries.map((e) => e.id)]);
      // Action order: the main track batch is issued first.
      expect(h.changeLog.issued, [main.id]);
      expect(main.id.compareTo(subEntries.first.id), lessThan(0));
    });

    test('doc metadata: the track keeps its config, gains ended_at and the '
        'entry id; sub-tracks are tombstoned with track_deleted', () async {
      final h = _harness(subTracks: [_subTrack(2)]);
      await h.commands.removeTrack(_cid);

      final main = h.batches.single.entry;
      expect(h.doc('curriculum_tracks', _cid), {
        'curriculum_id': _cid,
        'state': 'active',
        'activated_at': '2026-01-01T00:00:00.000Z',
        'ended_at': governedNow,
        'last_change_id': main.id,
      });
      final sub = h.subTracks.tracksOf(h.scope).single;
      expect(sub.endedAt, governedNow);
      expect(sub.endReason, SubTrackEndReason.trackDeleted);
      expect(sub.lastChangeId, h.subTracks.entries.single.$2.id);
    });

    test('learning events and the points ledger are untouched', () async {
      final h = _harness(subTracks: [_subTrack(2)]);
      await h.commands.removeTrack(_cid);
      expect(h.doc('learning_events', engineUlid(500)), _learningEvent);
      expect(h.doc('points_ledger', 'pts_${engineUlid(500)}'), _pointsRow);
      for (final batch in h.batches) {
        for (final merge in batch.merges) {
          expect(merge.collection, 'curriculum_tracks');
        }
      }
    });

    test('a track with no sub-track is the mainTrack entry alone', () async {
      final h = _harness();
      final result = await h.commands.removeTrack(_cid);
      expect((result as CaptureSuccess).changeIds, hasLength(1));
      expect(h.subTracks.entries, isEmpty);
    });

    test('an unknown track is targetNotFound and nothing is written', () async {
      final h = GovernedHarness();
      expect(
        await h.commands.removeTrack(_cid),
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );
      expect(h.batches, isEmpty);
    });

    test('removing a removed track writes nothing', () async {
      final h = _harness(subTracks: [_subTrack(2)]);
      await h.commands.removeTrack(_cid);
      final before = h.batches.length;
      expect(await h.commands.removeTrack(_cid), const CaptureResult.success());
      expect(h.batches, hasLength(before));
      expect(h.subTracks.entries, hasLength(1));
    });

    test('a sub-track read that never completes writes nothing', () async {
      final h = _harness(subTracks: [_subTrack(2)]);
      h.reader.failWith = Exception('offline');
      expect(
        await h.commands.removeTrack(_cid),
        const CaptureResult.rejected(CaptureRejection.notSaved),
      );
      expect(h.batches, isEmpty);
    });

    test('an invalid curriculum id is refused', () async {
      final h = _harness();
      expect(await h.commands.removeTrack('a/b'), isA<CaptureRejected>());
      expect(h.batches, isEmpty);
    });
  });

  group('re-add track', () {
    test('clears ended_at through a logged change and keeps the prior '
        'config; sub-tracks ended by the removal stay ended', () async {
      final h = _harness(subTracks: [_subTrack(2)]);
      await h.commands.removeTrack(_cid);

      final result = await h.commands.reAddTrack(_cid);

      final entry = h.batches.last.entry;
      expect(entry.entity, GovernedEntity.mainTrack);
      expect(entry.before, {
        'curriculum_tracks/mishnayos.ended_at': governedNow,
      });
      expect(entry.after, {'curriculum_tracks/mishnayos.ended_at': null});
      expect(result, isA<CaptureSuccess>());
      expect(h.doc('curriculum_tracks', _cid), {
        'curriculum_id': _cid,
        'state': 'active',
        'activated_at': '2026-01-01T00:00:00.000Z',
        'ended_at': null,
        'last_change_id': entry.id,
      });
      expect(
        h.subTracks.tracksOf(h.scope).single.endReason,
        SubTrackEndReason.trackDeleted,
      );
      expect(h.doc('learning_events', engineUlid(500)), _learningEvent);
    });

    test(
      're-add after later edits writes only ended_at (no clobber)',
      () async {
        final h = _harness();
        await h.commands.removeTrack(_cid);
        // Another device archives the removed track meanwhile.
        h.seedDoc('curriculum_tracks', _cid, {
          ...?h.doc('curriculum_tracks', _cid),
          'state': 'archived',
        });

        await h.commands.reAddTrack(_cid);

        expect(h.batches.last.merges.single.fields.keys, ['ended_at']);
        expect(h.doc('curriculum_tracks', _cid)?['state'], 'archived');
      },
    );

    test(
      'a live track writes nothing; an unknown one is targetNotFound',
      () async {
        final h = _harness();
        expect(
          await h.commands.reAddTrack(_cid),
          const CaptureResult.success(),
        );
        expect(h.batches, isEmpty);
        expect(
          await GovernedHarness().commands.reAddTrack(_cid),
          const CaptureResult.rejected(CaptureRejection.targetNotFound),
        );
      },
    );

    test(
      'the removal action can also be undone as one logged action',
      () async {
        final h = _harness(subTracks: [_subTrack(2)]);
        final removed = await h.commands.removeTrack(_cid) as CaptureSuccess;
        // In Firestore every entry lives in the one change_log collection;
        // the in-memory sub-track port keeps its own, so share them here.
        h.store.seed(h.scope, [for (final (_, e) in h.subTracks.entries) e]);
        final undo = await h.commands.undoAction(removed.actionId!);
        expect(undo, isA<CaptureSuccess>());
        expect(h.doc('curriculum_tracks', _cid)?['ended_at'], isNull);
        expect(h.subTracks.tracksOf(h.scope).single.endedAt, isNull);
      },
    );
  });

  test('parentActor is the actor of every entry', () async {
    final h = _harness(subTracks: [_subTrack(2)]);
    await h.commands.removeTrack(_cid);
    expect(h.batches.single.entry.actor, parentActor);
    expect(h.subTracks.entries.single.$2.actor, parentActor);
  });
}
