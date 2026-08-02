/// Unit tests for
/// `lib/data/repositories/firestore_completion_repository.dart`. Covers:
/// natural-key doc-id correctness (including the documented `trackType`
/// collision — see the repository's class doc comment's "`trackType` is NOT
/// part of the doc-id's natural key" section), the `source` field replacing
/// the Drift-era prior-import tier apparatus (rejecting `lifetimeOnly`,
/// `getCompletionsByTier` filtering), append-only idempotent-replay writes,
/// the raw-`Timestamp` `completed_at` encoding (pinned so a regression to an
/// ISO String fails loudly), `recordCompletionsBatch`, `hasCompletionsForStage`
/// / `completionExists` / date-range reads, the client-side aggregates, the
/// 500-item pagination past the page-size cap, and one-shot + streamed
/// decode leniency.
///
/// **What these tests cannot see** (same limitation documented in
/// `firestore_learning_ledger_repository_test.dart`/
/// `firestore_stage_definition_repository_test.dart`, restated here because
/// it is especially load-bearing for this collection):
/// `fake_cloud_firestore`'s rules companion cannot evaluate
/// `resource.data`/`request.resource` at all (see
/// `test/helpers/firestore_fake.dart`'s doc comment) — clauses using them
/// evaluate to deny under `strictRules: true`, which is STRICTER than
/// production, not equivalent to it, so `strictRules: true` proves nothing
/// either way here. That means:
/// - `firestore.rules`' SR-4 500-item `list()` cap
///   (`request.query.limit <= 500`) is never enforced by the fake — the
///   pagination test below proves [FirestoreCompletionRepository] NEVER
///   issues a query above that limit and correctly reassembles multi-page
///   results, but cannot prove a request missing `.limit()` entirely would
///   be rejected in production (it would be, by construction: every query
///   in the repository always chains `.limit()` — reviewed, not
///   test-proven).
/// - The `completed_at <= request.time` and `points` 0-100 create guards are
///   never evaluated. The `completed_at`-is-a-real-`Timestamp` tests below
///   prove the WRITTEN VALUE has the correct Firestore-level TYPE (confirmed
///   against `fake_cloud_firestore`'s own `DateTime`→`Timestamp` write-time
///   transform, which mirrors real `cloud_firestore` SDK behavior) — they
///   cannot prove the rules engine accepts it, only that the type this
///   engine writes is the type the rule asks for.
/// - SR-1's "update permitted only as a byte-identical replay" guard is
///   never evaluated either — `fake_cloud_firestore` accepts ANY update
///   unconditionally. The idempotent-replay tests below prove
///   [FirestoreCompletionRepository.recordCompletion] does not create a
///   SECOND document on a repeated call and that the stored data matches,
///   never that a rules-illegal non-identical "replay" would be rejected in
///   production.
/// - `allow delete: if false` is not exercised — there is no delete method
///   on this class to call in the first place.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';

import '../../helpers/firestore_fake.dart';

const _uid = 'uid-1';
const _profileId = 'profile-ulid-1';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  DocumentReference<Map<String, dynamic>> rawDoc(String docId) => firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('completions')
      .doc(docId);

  String expectedDocId({
    required String sefariaRef,
    required int stageId,
    required CurriculumId curriculumId,
  }) => DocIds.completionDocIdForProfile(_profileId, {
    'sefaria_ref': sefariaRef,
    'stage_id': stageId,
    'curriculum_id': curriculumId.storageKey,
  });

  FirestoreCompletionRepository buildRepo() {
    return FirestoreCompletionRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

  CompletionEntity entity({
    CurriculumId curriculumId = CurriculumId.mishnayos,
    String sefariaRef = 'Berakhot 1:1',
    int stageId = 1,
    String trackType = 'personal',
    CompletionSource source = CompletionSource.live,
    DateTime? completedAt,
    int points = 10,
  }) => CompletionEntity(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
    stageId: stageId,
    trackType: trackType,
    source: source,
    completedAt: completedAt ?? DateTime.utc(2026, 1, 1),
    points: points,
  );

  group('doc-id correctness', () {
    test('recordCompletion writes at the natural-key doc-id', () async {
      final repo = buildRepo();
      final written = entity();

      await repo.recordCompletion(written);

      final docId = expectedDocId(
        sefariaRef: 'Berakhot 1:1',
        stageId: 1,
        curriculumId: CurriculumId.mishnayos,
      );
      expect((await rawDoc(docId).get()).exists, isTrue);
    });

    test('a different sefariaRef produces a different doc-id', () async {
      final repo = buildRepo();
      await repo.recordCompletion(entity(sefariaRef: 'Berakhot 1:1'));
      await repo.recordCompletion(entity(sefariaRef: 'Berakhot 1:2'));

      final all = await repo.getCompletionsForCurriculum(
        CurriculumId.mishnayos,
      );
      expect(all, hasLength(2));
    });

    test('a different stageId produces a different doc-id', () async {
      final repo = buildRepo();
      await repo.recordCompletion(entity(stageId: 1));
      await repo.recordCompletion(entity(stageId: 2));

      final all = await repo.getCompletionsForCurriculum(
        CurriculumId.mishnayos,
      );
      expect(all, hasLength(2));
    });

    test('a different curriculumId produces a different doc-id', () async {
      final repo = buildRepo();
      await repo.recordCompletion(entity(curriculumId: CurriculumId.mishnayos));
      await repo.recordCompletion(entity(curriculumId: CurriculumId.bavli));

      expect(
        await repo.getCompletionsForCurriculum(CurriculumId.mishnayos),
        hasLength(1),
      );
      expect(
        await repo.getCompletionsForCurriculum(CurriculumId.bavli),
        hasLength(1),
      );
    });

    test('DOCUMENTED COLLISION: the SAME sefariaRef/stageId/curriculumId but a '
        'DIFFERENT trackType collides onto the SAME doc-id — trackType is '
        'NOT part of the natural key (doc_ids.dart is authoritative over the '
        'stale firestore.rules comment; see the class doc comment)', () async {
      final repo = buildRepo();
      await repo.recordCompletion(entity(trackType: 'personal'));
      await repo.recordCompletion(
        entity(
          trackType: 'chavrusa',
          points: 10,
          completedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final all = await repo.getCompletionsForCurriculum(
        CurriculumId.mishnayos,
      );
      expect(
        all,
        hasLength(1),
        reason: 'both writes target the same doc-id — the second overwrites',
      );
      expect(all.single.trackType, 'chavrusa', reason: 'last write wins');
    });

    test('never writes track_id or profile_id (MCF-11 / path-scoped, not '
        'payload-scoped)', () async {
      final repo = buildRepo();
      await repo.recordCompletion(entity());

      final docId = expectedDocId(
        sefariaRef: 'Berakhot 1:1',
        stageId: 1,
        curriculumId: CurriculumId.mishnayos,
      );
      final data = (await rawDoc(docId).get()).data()!;
      expect(data, isNot(contains('track_id')));
      expect(data, isNot(contains('profile_id')));
    });
  });

  group('source — replaces the Drift-era prior-import tier apparatus', () {
    test('recordCompletion rejects CompletionSource.lifetimeOnly', () async {
      final repo = buildRepo();
      expect(
        () => repo.recordCompletion(
          entity(source: CompletionSource.lifetimeOnly),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('recordCompletionsBatch rejects a batch containing lifetimeOnly, '
        'writing nothing at all', () async {
      final repo = buildRepo();
      await expectLater(
        repo.recordCompletionsBatch([
          entity(sefariaRef: 'ref-1'),
          entity(sefariaRef: 'ref-2', source: CompletionSource.lifetimeOnly),
        ]),
        throwsA(isA<ArgumentError>()),
      );

      final all = await repo.getCompletionsForCurriculum(
        CurriculumId.mishnayos,
      );
      expect(all, isEmpty, reason: 'validated before any chunk commits');
    });

    test('recordCompletion accepts live and bulkInTrack', () async {
      final repo = buildRepo();
      await repo.recordCompletion(
        entity(sefariaRef: 'ref-live', source: CompletionSource.live),
      );
      await repo.recordCompletion(
        entity(sefariaRef: 'ref-bulk', source: CompletionSource.bulkInTrack),
      );

      final all = await repo.getCompletionsForCurriculum(
        CurriculumId.mishnayos,
      );
      expect(all.map((c) => c.source).toSet(), {
        CompletionSource.live,
        CompletionSource.bulkInTrack,
      });
    });
  });

  group('idempotent replay', () {
    test(
      'writing the same entity twice does not create a second document',
      () async {
        final repo = buildRepo();
        final written = entity();

        await repo.recordCompletion(written);
        await repo.recordCompletion(written);

        final all = await repo.getCompletionsForCurriculum(
          CurriculumId.mishnayos,
        );
        expect(all, hasLength(1));
      },
    );
  });

  group('model round-trip', () {
    test('every field survives write then read', () async {
      final repo = buildRepo();
      await repo.recordCompletion(
        entity(
          curriculumId: CurriculumId.bavli,
          sefariaRef: 'Bava Kama 2a',
          stageId: 3,
          trackType: 'chavrusa',
          source: CompletionSource.bulkInTrack,
          completedAt: DateTime.utc(2026, 5, 10, 9, 15),
          points: 0,
        ),
      );

      final all = await repo.getCompletionsForCurriculum(CurriculumId.bavli);
      final loaded = all.single;

      expect(loaded.curriculumId, CurriculumId.bavli);
      expect(loaded.sefariaRef, 'Bava Kama 2a');
      expect(loaded.stageId, 3);
      expect(loaded.trackType, 'chavrusa');
      expect(loaded.source, CompletionSource.bulkInTrack);
      expect(loaded.completedAt, DateTime.utc(2026, 5, 10, 9, 15));
      expect(loaded.points, 0);
    });

    group('completed_at is a real Firestore Timestamp, not a String', () {
      test('the written field has Timestamp type', () async {
        final repo = buildRepo();
        await repo.recordCompletion(entity());

        final docId = expectedDocId(
          sefariaRef: 'Berakhot 1:1',
          stageId: 1,
          curriculumId: CurriculumId.mishnayos,
        );
        final data = (await rawDoc(docId).get()).data()!;
        expect(
          data['completed_at'],
          isA<Timestamp>(),
          reason:
              'firestore.rules compares completed_at <= request.time — a '
              'String value would fail that comparison (deny) in production',
        );
      });

      test('decodes back to the exact same UTC instant', () async {
        final repo = buildRepo();
        final completedAt = DateTime.utc(2026, 3, 15, 10, 30, 45, 123);
        await repo.recordCompletion(entity(completedAt: completedAt));

        final reloaded = await repo.getCompletionsForCurriculum(
          CurriculumId.mishnayos,
        );
        expect(reloaded.single.completedAt, completedAt);
        expect(reloaded.single.completedAt.isUtc, isTrue);
      });
    });
  });

  group('recordCompletionsBatch', () {
    test('writes every entry and each keeps its own doc-id', () async {
      final repo = buildRepo();
      final results = await repo.recordCompletionsBatch([
        entity(sefariaRef: 'ref-1'),
        entity(sefariaRef: 'ref-2'),
        entity(sefariaRef: 'ref-3'),
      ]);

      expect(results, hasLength(3));
      final all = await repo.getCompletionsForCurriculum(
        CurriculumId.mishnayos,
      );
      expect(all, hasLength(3));
    });

    test('empty list is a no-op', () async {
      final repo = buildRepo();
      final results = await repo.recordCompletionsBatch(const []);
      expect(results, isEmpty);
    });
  });

  group('completionExists', () {
    test('true for an existing natural key', () async {
      final repo = buildRepo();
      await repo.recordCompletion(
        entity(sefariaRef: 'Berakhot 1:1', stageId: 1),
      );

      expect(
        await repo.completionExists(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: 'Berakhot 1:1',
          stageId: 1,
        ),
        isTrue,
      );
    });

    test('false for a natural key that was never written', () async {
      final repo = buildRepo();
      expect(
        await repo.completionExists(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: 'never-written',
          stageId: 1,
        ),
        isFalse,
      );
    });
  });

  group('hasCompletionsForStage', () {
    test(
      'true when a completion references (curriculumId, stageOrder)',
      () async {
        final repo = buildRepo();
        await repo.recordCompletion(
          entity(curriculumId: CurriculumId.mishnayos, stageId: 2),
        );

        expect(
          await repo.hasCompletionsForStage(
            curriculumId: CurriculumId.mishnayos,
            stageOrder: 2,
          ),
          isTrue,
        );
      },
    );

    test('false for a stageOrder with no completions', () async {
      final repo = buildRepo();
      await repo.recordCompletion(
        entity(curriculumId: CurriculumId.mishnayos, stageId: 1),
      );

      expect(
        await repo.hasCompletionsForStage(
          curriculumId: CurriculumId.mishnayos,
          stageOrder: 99,
        ),
        isFalse,
      );
    });
  });

  group('getCompletionsForContent', () {
    test('returns completions across stages for one sefariaRef', () async {
      final repo = buildRepo();
      await repo.recordCompletion(
        entity(sefariaRef: 'Berakhot 1:1', stageId: 1),
      );
      await repo.recordCompletion(
        entity(sefariaRef: 'Berakhot 1:1', stageId: 2),
      );
      await repo.recordCompletion(
        entity(sefariaRef: 'Berakhot 1:2', stageId: 1),
      );

      final results = await repo.getCompletionsForContent('Berakhot 1:1');
      expect(results, hasLength(2));
    });
  });

  group('date-range reads', () {
    test(
      'getCompletionsByDateRange returns only completions within range',
      () async {
        final repo = buildRepo();
        await repo.recordCompletion(
          entity(
            sefariaRef: 'in-range',
            completedAt: DateTime.utc(2026, 6, 15),
          ),
        );
        await repo.recordCompletion(
          entity(sefariaRef: 'before', completedAt: DateTime.utc(2026, 1, 1)),
        );
        await repo.recordCompletion(
          entity(sefariaRef: 'after', completedAt: DateTime.utc(2026, 12, 31)),
        );

        final results = await repo.getCompletionsByDateRange(
          start: DateTime.utc(2026, 6, 1),
          end: DateTime.utc(2026, 6, 30),
        );

        expect(results, hasLength(1));
        expect(results.single.sefariaRef, 'in-range');
      },
    );

    test('hasCompletionsInDateRange reflects presence/absence', () async {
      final repo = buildRepo();
      await repo.recordCompletion(
        entity(sefariaRef: 'only-one', completedAt: DateTime.utc(2026, 6, 15)),
      );

      expect(
        await repo.hasCompletionsInDateRange(
          start: DateTime.utc(2026, 6, 1),
          end: DateTime.utc(2026, 6, 30),
        ),
        isTrue,
      );
      expect(
        await repo.hasCompletionsInDateRange(
          start: DateTime.utc(2027, 1, 1),
          end: DateTime.utc(2027, 1, 31),
        ),
        isFalse,
      );
    });
  });

  group('getCompletionsByTier', () {
    test('liveOnly returns only source == live', () async {
      final repo = buildRepo();
      await repo.recordCompletion(
        entity(sefariaRef: 'live-1', source: CompletionSource.live),
      );
      await repo.recordCompletion(
        entity(sefariaRef: 'bulk-1', source: CompletionSource.bulkInTrack),
      );

      final results = await repo.getCompletionsByTier(
        tier: CompletionTierFilter.liveOnly,
      );
      expect(results, hasLength(1));
      expect(results.single.sefariaRef, 'live-1');
    });

    test('trackAchievement and lifetime both return EVERYTHING in this '
        'collection — documented consequence of lifetimeOnly never landing '
        'here (see the class doc comment)', () async {
      final repo = buildRepo();
      await repo.recordCompletion(
        entity(sefariaRef: 'live-1', source: CompletionSource.live),
      );
      await repo.recordCompletion(
        entity(sefariaRef: 'bulk-1', source: CompletionSource.bulkInTrack),
      );

      final trackAchievement = await repo.getCompletionsByTier(
        tier: CompletionTierFilter.trackAchievement,
      );
      final lifetime = await repo.getCompletionsByTier(
        tier: CompletionTierFilter.lifetime,
      );

      expect(trackAchievement, hasLength(2));
      expect(lifetime, hasLength(2));
      expect(
        trackAchievement.map((c) => c.sefariaRef).toSet(),
        lifetime.map((c) => c.sefariaRef).toSet(),
      );
    });

    test('narrows to curriculumId when supplied', () async {
      final repo = buildRepo();
      await repo.recordCompletion(
        entity(curriculumId: CurriculumId.mishnayos, sefariaRef: 'm-1'),
      );
      await repo.recordCompletion(
        entity(curriculumId: CurriculumId.bavli, sefariaRef: 'b-1'),
      );

      final results = await repo.getCompletionsByTier(
        tier: CompletionTierFilter.lifetime,
        curriculumId: CurriculumId.mishnayos,
      );
      expect(results, hasLength(1));
      expect(results.single.sefariaRef, 'm-1');
    });
  });

  group('client-side aggregates', () {
    test('getAggregateCountForCurriculum counts DISTINCT sefariaRef', () async {
      final repo = buildRepo();
      await repo.recordCompletion(entity(sefariaRef: 'ref-1', stageId: 1));
      await repo.recordCompletion(entity(sefariaRef: 'ref-1', stageId: 2));
      await repo.recordCompletion(entity(sefariaRef: 'ref-2', stageId: 1));

      expect(
        await repo.getAggregateCountForCurriculum(CurriculumId.mishnayos),
        2,
        reason: 'ref-1 completed at two stages counts once',
      );
    });

    test('getTrackTypeBreakdownForCurriculum groups by trackType', () async {
      final repo = buildRepo();
      await repo.recordCompletion(
        entity(sefariaRef: 'ref-1', trackType: 'personal'),
      );
      await repo.recordCompletion(
        entity(sefariaRef: 'ref-2', trackType: 'personal'),
      );
      await repo.recordCompletion(
        entity(sefariaRef: 'ref-3', trackType: 'chavrusa'),
      );

      expect(
        await repo.getTrackTypeBreakdownForCurriculum(CurriculumId.mishnayos),
        {'personal': 2, 'chavrusa': 1},
      );
    });

    test('getReviewCountsByItem counts completions per sefariaRef', () async {
      final repo = buildRepo();
      await repo.recordCompletion(entity(sefariaRef: 'ref-1', stageId: 1));
      await repo.recordCompletion(entity(sefariaRef: 'ref-1', stageId: 2));
      await repo.recordCompletion(entity(sefariaRef: 'ref-2', stageId: 1));

      expect(await repo.getReviewCountsByItem(CurriculumId.mishnayos), {
        'ref-1': 2,
        'ref-2': 1,
      });
    });

    test(
      'getStageBreakdownByItem counts completions per stageId for one item',
      () async {
        final repo = buildRepo();
        await repo.recordCompletion(entity(sefariaRef: 'ref-1', stageId: 1));
        await repo.recordCompletion(entity(sefariaRef: 'ref-1', stageId: 2));
        await repo.recordCompletion(
          entity(sefariaRef: 'ref-other', stageId: 1),
        );

        expect(
          await repo.getStageBreakdownByItem(
            curriculumId: CurriculumId.mishnayos,
            sefariaRef: 'ref-1',
          ),
          {1: 1, 2: 1},
        );
      },
    );
  });

  group(
    'one-shot reads skip a malformed document instead of failing the whole read',
    () {
      test('getCompletionsForCurriculum omits a document with an unrecognised '
          'curriculum_id', () async {
        final repo = buildRepo();
        await repo.recordCompletion(entity(sefariaRef: 'bad-ref'));
        await repo.recordCompletion(entity(sefariaRef: 'good-ref'));

        final badDocId = expectedDocId(
          sefariaRef: 'bad-ref',
          stageId: 1,
          curriculumId: CurriculumId.mishnayos,
        );
        await rawDoc(
          badDocId,
        ).update({'curriculum_id': 'not-a-real-curriculum'});

        final all = await repo.getCompletionsForCurriculum(
          CurriculumId.mishnayos,
        );
        expect(all, hasLength(1));
        expect(all.single.sefariaRef, 'good-ref');
      });

      test('a document with an unrecognised source is also skipped', () async {
        final repo = buildRepo();
        await repo.recordCompletion(entity(sefariaRef: 'bad-ref'));
        await repo.recordCompletion(entity(sefariaRef: 'good-ref'));

        final badDocId = expectedDocId(
          sefariaRef: 'bad-ref',
          stageId: 1,
          curriculumId: CurriculumId.mishnayos,
        );
        await rawDoc(badDocId).update({'source': 'not-a-real-source'});

        final all = await repo.getCompletionsForCurriculum(
          CurriculumId.mishnayos,
        );
        expect(all, hasLength(1));
        expect(all.single.sefariaRef, 'good-ref');
      });
    },
  );

  group('watchCompletionsForCurriculum — stream', () {
    test('eventually reflects newly-written completions', () async {
      final repo = buildRepo();

      final stream = repo
          .watchCompletionsForCurriculum(CurriculumId.mishnayos)
          .map((completions) => completions.length);
      final done = expectLater(stream, emitsThrough(2));

      await repo.recordCompletion(entity(sefariaRef: 'ref-a'));
      await repo.recordCompletion(entity(sefariaRef: 'ref-b'));

      await done;
    });

    test('skips a malformed document without breaking the stream', () async {
      final repo = buildRepo();
      await repo.recordCompletion(entity(sefariaRef: 'good-ref'));

      final badDocId = expectedDocId(
        sefariaRef: 'bad-ref',
        stageId: 1,
        curriculumId: CurriculumId.mishnayos,
      );
      await rawDoc(badDocId).set({
        ...entity(sefariaRef: 'bad-ref').toFirestore(),
        'curriculum_id': 'not-a-real-curriculum',
      });

      final results = await repo
          .watchCompletionsForCurriculum(CurriculumId.mishnayos)
          .first;
      expect(results, hasLength(1));
      expect(results.single.sefariaRef, 'good-ref');
    });
  });

  group('pagination past the 500-item page size', () {
    test('getCompletionsForCurriculum reassembles a 501-document collection '
        'across pages', () async {
      final repo = buildRepo();
      final refs = List.generate(501, (i) => 'ref-$i');

      final batch1 = firestore.batch();
      for (final ref in refs.take(500)) {
        final docId = expectedDocId(
          sefariaRef: ref,
          stageId: 1,
          curriculumId: CurriculumId.mishnayos,
        );
        batch1.set(rawDoc(docId), entity(sefariaRef: ref).toFirestore());
      }
      await batch1.commit();

      final lastDocId = expectedDocId(
        sefariaRef: refs.last,
        stageId: 1,
        curriculumId: CurriculumId.mishnayos,
      );
      await rawDoc(lastDocId).set(entity(sefariaRef: refs.last).toFirestore());

      final all = await repo.getCompletionsForCurriculum(
        CurriculumId.mishnayos,
      );

      expect(all, hasLength(501));
      expect(all.map((c) => c.sefariaRef).toSet(), refs.toSet());
    });
  });
}
