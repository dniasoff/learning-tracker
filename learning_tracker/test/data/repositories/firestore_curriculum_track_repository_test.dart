/// Unit tests for
/// `lib/data/repositories/firestore_curriculum_track_repository.dart` —
/// the repository that absorbs BOTH `TrackDao` and `ActiveCurriculumDao`
/// (`docs/firestore-rewrite-map.md`). Covers: doc-id correctness, model
/// round-trip, the activate/retire/archive state machine (including
/// `retireTrack`'s "must currently be active" no-op guard and
/// `archiveTrack`'s unconditional transition), the absorbed
/// last-active-curriculum guard on both `retireTrack` and `archiveTrack`,
/// the active-tracks query and its client-side sort, stream emission, and
/// the "one bad document doesn't blank the list" decode leniency (both the
/// stream AND the one-shot reads).
///
/// **What these tests cannot see** (same limitation as
/// `firestore_stage_definition_repository_test.dart`/
/// `firestore_goal_repository_test.dart`): `fake_cloud_firestore`'s rules
/// companion cannot evaluate `resource.data`/`request.resource`, so the
/// `curriculum_tracks` rules' `.hasOnly()` field whitelist is NOT exercised
/// here — a permissive fake is used throughout (`createFakeFirestore()`
/// default, `strictRules: false`). The `curriculum_tracks` `allow delete:
/// if false` rule is likewise never exercised — this repository has no
/// delete method to test in the first place (see the class doc comment's
/// "Deletion is NOT this repository's job"). The resubscribe-with-backoff
/// behavior `watchTrack`/`watchAllTracks`/`watchActiveTracks` delegate to is
/// covered directly in `resilient_doc_stream_test.dart` — not re-proven
/// here.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';

import '../../helpers/firestore_fake.dart';
import '../../helpers/firestore_governed_writer.dart';
import '../../helpers/learner_state/c0_fixtures.dart';
import '../../helpers/learner_state/engine_fixtures.dart';

const _uid = 'uid-1';
const _profileId = governedTestProfileId;

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreGovernedWriter writer;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    writer = FirestoreGovernedWriter(firestore, uid: _uid);
  });

  DocumentReference<Map<String, dynamic>> rawDoc(CurriculumId curriculumId) =>
      firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('curriculum_tracks')
          .doc(
            DocIds.curriculumTrackDocId({
              'curriculum_id': curriculumId.storageKey,
            }),
          );

  FirestoreCurriculumTrackRepository buildRepo() {
    return FirestoreCurriculumTrackRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
      writer: writer,
    );
  }

  group('doc-id correctness', () {
    test('activateTrack writes to DocIds.curriculumTrackDocId — the '
        'curriculum id alone, no trackType component (W3.22)', () async {
      final repo = buildRepo();

      await repo.activateTrack(CurriculumId.mishnayos);

      final expectedId = DocIds.curriculumTrackDocId({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
      });
      expect(expectedId, CurriculumId.mishnayos.storageKey);
      final snapshot = await rawDoc(CurriculumId.mishnayos).get();
      expect(snapshot.exists, isTrue);
    });

    test('never writes a profile_id or track_id field', () async {
      final repo = buildRepo();

      await repo.activateTrack(CurriculumId.mishnayos);

      final data = (await rawDoc(CurriculumId.mishnayos).get()).data();
      expect(data, isNot(contains('profile_id')));
      expect(data, isNot(contains('track_id')));
    });
  });

  group('activateTrack', () {
    test('creates a new active track when none exists', () async {
      final repo = buildRepo();

      final track = await repo.activateTrack(CurriculumId.bavli);

      expect(track.state, CurriculumTrackState.active.storageKey);
      expect(track.isActive, isTrue);
      expect(track.activatedAt, track.stateChangedAt);
    });

    test('is idempotent: re-activating an already-active track returns the '
        'same track without rewriting activatedAt', () async {
      final repo = buildRepo();
      final first = await repo.activateTrack(CurriculumId.bavli);

      final second = await repo.activateTrack(CurriculumId.bavli);

      expect(second.activatedAt, first.activatedAt);
      expect(second.stateChangedAt, first.stateChangedAt);
    });

    test(
      'reactivates a retired track, bumping activatedAt/stateChangedAt',
      () async {
        final repo = buildRepo();
        await repo.activateTrack(CurriculumId.mishnayos);
        await repo.activateTrack(CurriculumId.bavli); // keep >=1 active
        await repo.retireTrack(CurriculumId.mishnayos);
        final retired = await repo.getTrack(CurriculumId.mishnayos);
        expect(retired!.isActive, isFalse);

        final reactivated = await repo.activateTrack(CurriculumId.mishnayos);

        expect(reactivated.isActive, isTrue);
        expect(reactivated.state, CurriculumTrackState.active.storageKey);
      },
    );

    test('reactivating a retired track does not clear a previously-set '
        'paceResetDate (matches TrackDao.activateTrack: paceResetDate is '
        'never touched by the reactivation branch)', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);
      await repo.activateTrack(CurriculumId.bavli);
      // A legacy pace-reset stamp (Reset pace is retired; the stamp stays).
      await rawDoc(CurriculumId.mishnayos).set({
        'pace_reset_date': '2026-01-01T00:00:00.000Z',
      }, SetOptions(merge: true));
      final beforeRetire = await repo.getTrack(CurriculumId.mishnayos);
      expect(beforeRetire!.paceResetDate, isNotNull);
      await repo.retireTrack(CurriculumId.mishnayos);

      final reactivated = await repo.activateTrack(CurriculumId.mishnayos);

      expect(reactivated.paceResetDate, beforeRetire.paceResetDate);
    });
  });

  group('retireTrack', () {
    test('sets state to retired when the track is active', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);
      await repo.activateTrack(CurriculumId.bavli);

      await repo.retireTrack(CurriculumId.mishnayos);

      final track = await repo.getTrack(CurriculumId.mishnayos);
      expect(track!.state, CurriculumTrackState.retired.storageKey);
    });

    test('is a no-op when the track does not exist', () async {
      final repo = buildRepo();

      await repo.retireTrack(CurriculumId.mishnayos);

      expect(await repo.getTrack(CurriculumId.mishnayos), isNull);
    });

    test('is a no-op when the track is already retired (matches '
        'TrackDao.retireTrack\'s "only from active" guard)', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);
      await repo.activateTrack(CurriculumId.bavli);
      await repo.retireTrack(CurriculumId.mishnayos);
      final retired = await repo.getTrack(CurriculumId.mishnayos);

      // Second retire must not throw and must not touch stateChangedAt again.
      await repo.retireTrack(CurriculumId.mishnayos);

      final stillRetired = await repo.getTrack(CurriculumId.mishnayos);
      expect(stillRetired!.stateChangedAt, retired!.stateChangedAt);
    });

    test('throws StateError when this is the profile\'s only active '
        'curriculum — the absorbed ActiveCurriculumDao guard', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);

      expect(
        () => repo.retireTrack(CurriculumId.mishnayos),
        throwsA(isA<StateError>()),
      );
      final track = await repo.getTrack(CurriculumId.mishnayos);
      expect(
        track!.isActive,
        isTrue,
        reason: 'the guard must block the write, not just throw after it',
      );
    });
  });

  group('archiveTrack', () {
    test('sets state to archived unconditionally, even from active', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);
      await repo.activateTrack(CurriculumId.bavli);

      await repo.archiveTrack(CurriculumId.mishnayos);

      final track = await repo.getTrack(CurriculumId.mishnayos);
      expect(track!.state, CurriculumTrackState.archived.storageKey);
    });

    test('throws StateError when this is the profile\'s only active '
        'curriculum', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);

      expect(
        () => repo.archiveTrack(CurriculumId.mishnayos),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('isActive', () {
    test('true for an active track, false for retired/absent', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);
      await repo.activateTrack(CurriculumId.bavli);

      expect(await repo.isActive(CurriculumId.mishnayos), isTrue);

      await repo.retireTrack(CurriculumId.mishnayos);
      expect(await repo.isActive(CurriculumId.mishnayos), isFalse);
      expect(await repo.isActive(CurriculumId.nach), isFalse);
    });
  });

  group('getActiveTracks / getActiveCurriculumIds — client-side sort, '
      'single-field filter', () {
    test(
      'returns only active tracks, sorted by curriculumId storageKey',
      () async {
        final repo = buildRepo();
        await repo.activateTrack(CurriculumId.mishnayos);
        await repo.activateTrack(CurriculumId.bavli);
        await repo.activateTrack(CurriculumId.chumash);
        await repo.retireTrack(CurriculumId.chumash);

        final active = await repo.getActiveTracks();

        expect(active.map((t) => t.curriculumId.storageKey), [
          'bavli',
          'mishnayos',
        ], reason: 'alphabetical by storageKey, excluding the retired one');
      },
    );

    test(
      'getActiveCurriculumIds projects the same set to storageKeys',
      () async {
        final repo = buildRepo();
        await repo.activateTrack(CurriculumId.mishnayos);
        await repo.activateTrack(CurriculumId.bavli);

        final ids = await repo.getActiveCurriculumIds();

        expect(ids, ['bavli', 'mishnayos']);
      },
    );

    test('countActiveTracks matches getActiveTracks length', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);
      await repo.activateTrack(CurriculumId.bavli);

      expect(await repo.countActiveTracks(), 2);
    });
  });

  group('getAllTracks — every state, unfiltered', () {
    test('includes active, retired, and archived tracks', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);
      await repo.activateTrack(CurriculumId.bavli);
      await repo.activateTrack(CurriculumId.chumash);
      await repo.retireTrack(CurriculumId.bavli);
      await repo.archiveTrack(CurriculumId.chumash);

      final all = await repo.getAllTracks();

      expect(all, hasLength(3));
    });
  });

  group('one-shot reads skip a malformed document instead of failing '
      'the whole read', () {
    test('getAllTracks omits a document missing state but still returns '
        'the valid ones', () async {
      final repo = buildRepo();
      final good = await repo.activateTrack(CurriculumId.mishnayos);
      await rawDoc(CurriculumId.bavli).set({
        'curriculum_id': CurriculumId.bavli.storageKey,
        // state / state_changed_at / activated_at deliberately missing.
      });

      final all = await repo.getAllTracks();

      expect(all, hasLength(1));
      expect(all.single.curriculumId, good.curriculumId);
    });

    test('getActiveTracks has the same leniency for a malformed active-state '
        'document', () async {
      final repo = buildRepo();
      final good = await repo.activateTrack(CurriculumId.mishnayos);
      await rawDoc(CurriculumId.bavli).set({
        'curriculum_id': CurriculumId.bavli.storageKey,
        'state': CurriculumTrackState.active.storageKey,
        // state_changed_at / activated_at deliberately missing.
      });

      final active = await repo.getActiveTracks();

      expect(active, hasLength(1));
      expect(active.single.curriculumId, good.curriculumId);
    });
  });

  group('watchTrack / watchAllTracks / watchActiveTracks — stream emits on '
      'change', () {
    test('watchTrack eventually reflects an activated track', () async {
      final repo = buildRepo();

      final stream = repo
          .watchTrack(CurriculumId.nach)
          .map((t) => t?.isActive ?? false);
      final done = expectLater(stream, emitsThrough(true));

      await repo.activateTrack(CurriculumId.nach);

      await done;
    });

    test('watchActiveTracks eventually reflects the active set', () async {
      final repo = buildRepo();

      final stream = repo.watchActiveTracks().map((tracks) => tracks.length);
      final done = expectLater(stream, emitsThrough(1));

      await repo.activateTrack(CurriculumId.nach);

      await done;
    });
  });

  group('curriculumTrackFromFirestore integration — getTrack returns null '
      'for a track that has never been activated (or was purged server-side '
      'by deleteCurriculumTrack — see the class doc comment)', () {
    test('getTrack returns null when no document exists', () async {
      final repo = buildRepo();

      expect(await repo.getTrack(CurriculumId.mishnehTorah), isNull);
    });
  });

  group('DNI-476: governed writes, tombstone reads', () {
    test(
      'activateTrack is one logged mainTrack change with last_change_id',
      () async {
        await buildRepo().activateTrack(CurriculumId.mishnayos);
        final entry = (await writer.lastEntries()).single;
        expect(entry.entity.storage, 'mainTrack');
        expect(entry.entityId, 'mishnayos');
        final doc = (await rawDoc(CurriculumId.mishnayos).get()).data()!;
        expect(doc['last_change_id'], entry.id);
        expect(doc['curriculum_id'], 'mishnayos');
        expect(doc.keys, isNot(contains('updated_at')));
        expect(doc.keys, isNot(contains('synced_at')));
      },
    );

    test('an ended (removed) track reads as absent everywhere', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);
      await repo.activateTrack(CurriculumId.bavli);
      await rawDoc(CurriculumId.mishnayos).set({
        'ended_at': Timestamp.fromDate(governedTestNow),
      }, SetOptions(merge: true));

      expect(await repo.getTrack(CurriculumId.mishnayos), isNull);
      expect(await repo.isActive(CurriculumId.mishnayos), isFalse);
      expect(await repo.getActiveCurriculumIds(), ['bavli']);
      expect((await repo.getAllTracks()).map((t) => t.curriculumId), [
        CurriculumId.bavli,
      ]);
      expect((await repo.watchAllTracks().first).map((t) => t.curriculumId), [
        CurriculumId.bavli,
      ]);
      expect(await repo.watchActiveCurriculumIds().first, ['bavli']);
    });

    test('activating a removed track re-adds it: ended_at is cleared through '
        'a logged change and the doc keeps its other fields', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);
      await rawDoc(CurriculumId.mishnayos).set({
        'ended_at': Timestamp.fromDate(governedTestNow),
        'progress_model': 'kept',
      }, SetOptions(merge: true));

      final track = await repo.activateTrack(CurriculumId.mishnayos);

      expect(track.isActive, isTrue);
      final doc = (await rawDoc(CurriculumId.mishnayos).get()).data()!;
      expect(doc['ended_at'], isNull);
      expect(doc['progress_model'], 'kept');
      final entry = (await writer.lastEntries()).single;
      expect(entry.after['curriculum_tracks/mishnayos.ended_at'], isNull);
      expect(
        entry.after.keys,
        contains('curriculum_tracks/mishnayos.ended_at'),
      );
    });
  });

  group('DNI-476 AC-4: remove / re-add through the governed commands', () {
    DocumentReference<Map<String, dynamic>> profileDoc() => firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId);

    test('remove: one action (mainTrack ended_at + a track_deleted '
        'tombstone per live sub-track) sharing action_id; learning events and '
        'points untouched; re-add restores the track', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);
      await repo.activateTrack(CurriculumId.bavli);
      final sub = c0SubTrack(id: engineUlid(7));
      await profileDoc()
          .collection('sub_tracks')
          .doc(sub.id)
          .set(toFirestoreMap(sub.toStorage()));
      const event = {'kind': 'learn', 'curriculum_id': 'mishnayos'};
      const points = {'amount': 10, 'curriculum_id': 'mishnayos'};
      await profileDoc().collection('learning_events').doc('e1').set(event);
      await profileDoc().collection('points_ledger').doc('p1').set(points);

      await repo.removeTrack(CurriculumId.mishnayos);

      expect(await repo.getTrack(CurriculumId.mishnayos), isNull);
      final raw = (await rawDoc(CurriculumId.mishnayos).get()).data()!;
      expect(raw['ended_at'], isA<Timestamp>());
      final subRaw =
          (await profileDoc().collection('sub_tracks').doc(sub.id).get())
              .data()!;
      expect(subRaw['end_reason'], 'track_deleted');
      expect(subRaw['ended_at'], isA<Timestamp>());
      final entries = await writer.lastEntries();
      expect(entries.map((e) => e.entity.storage), ['mainTrack', 'subTrack']);
      expect(entries.map((e) => e.actionId).toSet(), {entries.first.id});
      expect(
        (await profileDoc().collection('learning_events').doc('e1').get())
            .data(),
        event,
      );
      expect(
        (await profileDoc().collection('points_ledger').doc('p1').get()).data(),
        points,
      );

      await repo.reAddTrack(CurriculumId.mishnayos);
      final back = await repo.getTrack(CurriculumId.mishnayos);
      expect(back, isNotNull);
      expect(back!.isActive, isTrue);
      expect(
        (await profileDoc().collection('sub_tracks').doc(sub.id).get())
            .data()!['end_reason'],
        'track_deleted',
        reason: 'ruling B13: re-add does not reactivate the sub-tracks',
      );
    });

    test('removing the only active track throws StateError and writes '
        'nothing', () async {
      final repo = buildRepo();
      await repo.activateTrack(CurriculumId.mishnayos);
      final before = writer.results.length;
      await expectLater(
        repo.removeTrack(CurriculumId.mishnayos),
        throwsStateError,
      );
      expect(writer.results, hasLength(before));
      expect(await repo.getTrack(CurriculumId.mishnayos), isNotNull);
    });
  });
}
