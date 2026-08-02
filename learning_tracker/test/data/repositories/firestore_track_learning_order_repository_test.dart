/// Unit tests for
/// `lib/data/repositories/firestore_track_learning_order_repository.dart`.
/// Mirrors `firestore_learning_order_repository_test.dart`'s structure
/// (same doc-id family, same content-enrichment pattern) — see that file's
/// doc comment for the shared "what these tests cannot see" limitations
/// (`fake_cloud_firestore` cannot evaluate `request.resource`/`resource`,
/// so `track_learning_order`'s rules `.hasOnly()` whitelist and its `allow
/// delete: if false` are read as TEXT below, not exercised as enforcement;
/// composite indexes are not enforced by the fake either).
///
/// Extra coverage this file adds that the sibling does not need:
///   - [getMasechtosOrder]/[watchMasechtosOrder]'s seder-priority-dependent
///     ordering via `MasechtaOrderingPolicy`.
///   - the "doc-id collision" group PROVES, rather than merely asserts, the
///     class doc comment's central claim: `DocIds.trackLearningOrderDocId`
///     and `DocIds.learningOrderDocId` compute the IDENTICAL doc-id string
///     for the same `(curriculumId, sefariaRef)` pair, yet a write through
///     each repository lands in its own collection and neither clobbers the
///     other — the reason this repository/collection exists at all
///     (`docs/firestore-rewrite-map.md`'s "OPEN" section,
///     `firestore_learning_order_repository_test.dart`'s RED-DEMO group).
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_order_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

import '../../helpers/firestore_fake.dart';

const _uid = 'uid-1';
const _profileId = 'profile-ulid-1';

/// A level-1, non-leaf "seder" content item (`level2 == null`).
ContentItem _seder({
  required String curriculumId,
  required String level1,
  required String sefariaRef,
  required String he,
  required String en,
  required int sortOrder,
}) => ContentItem(
  curriculumId: curriculumId,
  level1: level1,
  displayNameHe: he,
  displayNameEn: en,
  sefariaRef: sefariaRef,
  sortOrder: sortOrder,
  isLeaf: false,
);

/// A level-2, non-leaf "masechta" content item, belonging to seder
/// [level1] — the shape both this repository's masechtos ordering and the
/// whole-curriculum sibling draw their orderable universe from.
ContentItem _masechta({
  required String curriculumId,
  required String level1,
  required String sefariaRef,
  required String he,
  required String en,
  required int sortOrder,
}) => ContentItem(
  curriculumId: curriculumId,
  level1: level1,
  level2: sefariaRef,
  displayNameHe: he,
  displayNameEn: en,
  sefariaRef: sefariaRef,
  sortOrder: sortOrder,
  isLeaf: false,
);

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  CollectionReference<Map<String, dynamic>> ordersCollection() => firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('track_learning_order');

  DocumentReference<Map<String, dynamic>> rawDoc(String docId) =>
      ordersCollection().doc(docId);

  FirestoreTrackLearningOrderRepository buildRepo() {
    return FirestoreTrackLearningOrderRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

  final zeraim = _seder(
    curriculumId: CurriculumId.mishnayos.storageKey,
    level1: 'Seder Zeraim',
    sefariaRef: 'Seder Zeraim',
    he: 'זרעים',
    en: 'Zeraim',
    sortOrder: 0,
  );
  final moed = _seder(
    curriculumId: CurriculumId.mishnayos.storageKey,
    level1: 'Seder Moed',
    sefariaRef: 'Seder Moed',
    he: 'מועד',
    en: 'Moed',
    sortOrder: 1,
  );
  final berakhot = _masechta(
    curriculumId: CurriculumId.mishnayos.storageKey,
    level1: 'Seder Zeraim',
    sefariaRef: 'Mishnah Berakhot',
    he: 'ברכות',
    en: 'Berakhot',
    sortOrder: 0,
  );
  final peah = _masechta(
    curriculumId: CurriculumId.mishnayos.storageKey,
    level1: 'Seder Zeraim',
    sefariaRef: 'Mishnah Peah',
    he: 'פאה',
    en: 'Peah',
    sortOrder: 1,
  );
  final shabbat = _masechta(
    curriculumId: CurriculumId.mishnayos.storageKey,
    level1: 'Seder Moed',
    sefariaRef: 'Mishnah Shabbat',
    he: 'שבת',
    en: 'Shabbat',
    sortOrder: 0,
  );
  final allItems = [zeraim, moed, berakhot, peah, shabbat];

  group('doc-id correctness', () {
    test(
      'saveSedarimOrder writes to '
      'DocIds.trackLearningOrderDocId({curriculum_id, sefaria_ref})',
      () async {
        final repo = buildRepo();

        await repo.saveSedarimOrder(CurriculumId.mishnayos, [
          LearningOrderItem(
            sefariaRef: zeraim.sefariaRef,
            displayNameHe: zeraim.displayNameHe,
            displayNameEn: zeraim.displayNameEn,
            userSortOrder: 0,
          ),
        ]);

        final expectedId = DocIds.trackLearningOrderDocId({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'sefaria_ref': zeraim.sefariaRef,
        });
        final snapshot = await rawDoc(expectedId).get();
        expect(snapshot.exists, isTrue);
        expect(snapshot.data()!['user_sort_order'], 0);
      },
    );

    test('never writes a track_id field (no per-device track key)', () async {
      final repo = buildRepo();

      await repo.saveSedarimOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: zeraim.sefariaRef,
          displayNameHe: zeraim.displayNameHe,
          displayNameEn: zeraim.displayNameEn,
          userSortOrder: 0,
        ),
      ]);

      final all = await ordersCollection().get();
      expect(all.docs.single.data(), isNot(contains('track_id')));
    });

    test(
      'sedarim rows and masechtos rows for the same curriculum coexist as '
      'distinct documents (no discriminator field, disambiguated by ref)',
      () async {
        final repo = buildRepo();

        await repo.saveSedarimOrder(CurriculumId.mishnayos, [
          LearningOrderItem(
            sefariaRef: zeraim.sefariaRef,
            displayNameHe: '?',
            displayNameEn: '?',
            userSortOrder: 0,
          ),
        ]);
        await repo.saveMasechtosOrder(CurriculumId.mishnayos, [
          LearningOrderItem(
            sefariaRef: berakhot.sefariaRef,
            displayNameHe: '?',
            displayNameEn: '?',
            userSortOrder: 0,
          ),
        ]);

        final all = await ordersCollection().get();
        expect(all.docs, hasLength(2));
      },
    );
  });

  group('getSedarimOrder — content-item enrichment round-trip', () {
    test(
      'falls back to natural content order when no custom order is saved',
      () async {
        final repo = buildRepo();

        final result = await repo.getSedarimOrder(
          CurriculumId.mishnayos,
          allItems,
        );

        expect(result.map((i) => i.sefariaRef), [
          zeraim.sefariaRef,
          moed.sefariaRef,
        ]);
        expect(result.every((i) => !i.isCustomOrdered), isTrue);
        expect(result[0].displayNameHe, zeraim.displayNameHe);
      },
    );

    test(
      'returns the saved custom order, enriched with display names',
      () async {
        final repo = buildRepo();
        await repo.saveSedarimOrder(CurriculumId.mishnayos, [
          LearningOrderItem(
            sefariaRef: moed.sefariaRef,
            displayNameHe: '?',
            displayNameEn: '?',
            userSortOrder: 0,
          ),
          LearningOrderItem(
            sefariaRef: zeraim.sefariaRef,
            displayNameHe: '?',
            displayNameEn: '?',
            userSortOrder: 0,
          ),
        ]);

        final result = await repo.getSedarimOrder(
          CurriculumId.mishnayos,
          allItems,
        );

        expect(result.map((i) => i.sefariaRef), [
          moed.sefariaRef,
          zeraim.sefariaRef,
        ]);
        expect(result.every((i) => i.isCustomOrdered), isTrue);
        expect(result[0].displayNameHe, moed.displayNameHe);
      },
    );

    test(
      'the composite curriculum_id + user_sort_order query orders server-side',
      () async {
        final repo = buildRepo();
        await repo.saveSedarimOrder(CurriculumId.mishnayos, [
          LearningOrderItem(
            sefariaRef: moed.sefariaRef,
            displayNameHe: '?',
            displayNameEn: '?',
            userSortOrder: 0,
          ),
          LearningOrderItem(
            sefariaRef: zeraim.sefariaRef,
            displayNameHe: '?',
            displayNameEn: '?',
            userSortOrder: 0,
          ),
        ]);

        final result = await repo.getSedarimOrder(
          CurriculumId.mishnayos,
          allItems,
        );

        expect(result.map((i) => i.userSortOrder).toList(), [0, 1]);
        expect(result.map((i) => i.sefariaRef), [
          moed.sefariaRef,
          zeraim.sefariaRef,
        ]);
      },
    );
  });

  group('getMasechtosOrder — seder-priority-dependent ordering', () {
    test('falls back to canonical seder/sortOrder when no custom order is '
        'saved for either sedarim or masechtos', () async {
      final repo = buildRepo();

      final result = await repo.getMasechtosOrder(
        CurriculumId.mishnayos,
        allItems,
      );

      // Canonical: Zeraim (sortOrder 0) before Moed (sortOrder 1); within
      // Zeraim, Berakhot (0) before Peah (1).
      expect(result.map((i) => i.sefariaRef), [
        berakhot.sefariaRef,
        peah.sefariaRef,
        shabbat.sefariaRef,
      ]);
      expect(result.every((i) => !i.isCustomOrdered), isTrue);
    });

    test('a saved custom SEDER order re-priorities masechtos across sedarim, '
        'even though no masechtos row itself was ever saved', () async {
      final repo = buildRepo();
      // Reverse the seder order: Moed first.
      await repo.saveSedarimOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: moed.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
        LearningOrderItem(
          sefariaRef: zeraim.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);

      final result = await repo.getMasechtosOrder(
        CurriculumId.mishnayos,
        allItems,
      );

      expect(
        result.map((i) => i.sefariaRef),
        [shabbat.sefariaRef, berakhot.sefariaRef, peah.sefariaRef],
        reason:
            'Moed’s masechta (Shabbat) must sort before Zeraim’s '
            '(Berakhot, Peah) once Moed is the user-prioritised seder — '
            'matching MasechtaOrderingPolicy exactly',
      );
      expect(
        result.every((i) => !i.isCustomOrdered),
        isTrue,
        reason:
            'no masechtos row was itself saved, so each item is still '
            'natural/fallback-derived even though its POSITION was '
            're-primed by the seder order',
      );
    });

    test('a saved custom MASECHTOS order is returned enriched', () async {
      final repo = buildRepo();
      await repo.saveMasechtosOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: peah.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
        LearningOrderItem(
          sefariaRef: berakhot.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
        LearningOrderItem(
          sefariaRef: shabbat.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);

      final result = await repo.getMasechtosOrder(
        CurriculumId.mishnayos,
        allItems,
      );

      expect(result.map((i) => i.sefariaRef), [
        peah.sefariaRef,
        berakhot.sefariaRef,
        shabbat.sefariaRef,
      ]);
      expect(result.every((i) => i.isCustomOrdered), isTrue);
      expect(result[0].displayNameHe, peah.displayNameHe);
    });
  });

  group('saveSedarimOrder / saveMasechtosOrder — reorder semantics', () {
    test('re-saving a new order overwrites the same documents rather than '
        'accumulating duplicates', () async {
      final repo = buildRepo();
      await repo.saveSedarimOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: zeraim.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
        LearningOrderItem(
          sefariaRef: moed.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);

      await repo.saveSedarimOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: moed.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
        LearningOrderItem(
          sefariaRef: zeraim.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);

      final all = await ordersCollection().get();
      expect(
        all.docs,
        hasLength(2),
        reason:
            'same (curriculumId, sefariaRef) pairs must overwrite, '
            'not duplicate',
      );
      final result = await repo.getSedarimOrder(
        CurriculumId.mishnayos,
        allItems,
      );
      expect(result.map((i) => i.sefariaRef), [
        moed.sefariaRef,
        zeraim.sefariaRef,
      ]);
    });

    test('writes the LIST POSITION as user_sort_order, ignoring the item\'s '
        'own userSortOrder field', () async {
      final repo = buildRepo();

      await repo.saveMasechtosOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: berakhot.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 999, // deliberately wrong — must be ignored
        ),
      ]);

      final docId = DocIds.trackLearningOrderDocId({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'sefaria_ref': berakhot.sefariaRef,
      });
      final snapshot = await rawDoc(docId).get();
      expect(snapshot.data()!['user_sort_order'], 0);
    });

    test(
      'saveSedarimOrder and saveMasechtosOrder route through the identical '
      'save path — both write to the same collection, no separate storage',
      () async {
        final repo = buildRepo();

        await repo.saveSedarimOrder(CurriculumId.mishnayos, [
          LearningOrderItem(
            sefariaRef: zeraim.sefariaRef,
            displayNameHe: '?',
            displayNameEn: '?',
            userSortOrder: 0,
          ),
        ]);
        await repo.saveMasechtosOrder(CurriculumId.mishnayos, [
          LearningOrderItem(
            sefariaRef: berakhot.sefariaRef,
            displayNameHe: '?',
            displayNameEn: '?',
            userSortOrder: 0,
          ),
        ]);

        final all = await ordersCollection().get();
        expect(
          all.docs.map((d) => d.id),
          unorderedEquals([
            DocIds.trackLearningOrderDocId({
              'curriculum_id': CurriculumId.mishnayos.storageKey,
              'sefaria_ref': zeraim.sefariaRef,
            }),
            DocIds.trackLearningOrderDocId({
              'curriculum_id': CurriculumId.mishnayos.storageKey,
              'sefaria_ref': berakhot.sefariaRef,
            }),
          ]),
        );
      },
    );
  });

  group('resetToDefault — flagged, not silently guessed at', () {
    test('throws UnimplementedError (no rules-legal delete path exists)', () {
      final repo = buildRepo();

      expect(
        () => repo.resetToDefault(CurriculumId.mishnayos),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  group('watchSedarimOrder / watchMasechtosOrder — stream emits on change', () {
    test('watchSedarimOrder emits the custom order once saved', () async {
      final repo = buildRepo();

      final stream = repo
          .watchSedarimOrder(CurriculumId.mishnayos, allItems)
          .map((items) => items.map((i) => i.sefariaRef).toList());
      final done = expectLater(
        stream,
        emitsThrough([moed.sefariaRef, zeraim.sefariaRef]),
      );

      await repo.saveSedarimOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: moed.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
        LearningOrderItem(
          sefariaRef: zeraim.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);

      await done;
    });

    test(
      'watchMasechtosOrder re-derives the seder-priority index on every '
      'emission — a later seder-order save alone reorders the stream',
      () async {
        final repo = buildRepo();

        final stream = repo
            .watchMasechtosOrder(CurriculumId.mishnayos, allItems)
            .map((items) => items.map((i) => i.sefariaRef).toList());
        final done = expectLater(
          stream,
          emitsThrough([
            shabbat.sefariaRef,
            berakhot.sefariaRef,
            peah.sefariaRef,
          ]),
        );

        // Saving only the SEDER order (never a masechtos row) must still
        // reorder the masechtos stream — proves the masechtos merge is
        // recomputed from the live snapshot, not cached from subscribe time.
        await repo.saveSedarimOrder(CurriculumId.mishnayos, [
          LearningOrderItem(
            sefariaRef: moed.sefariaRef,
            displayNameHe: '?',
            displayNameEn: '?',
            userSortOrder: 0,
          ),
          LearningOrderItem(
            sefariaRef: zeraim.sefariaRef,
            displayNameHe: '?',
            displayNameEn: '?',
            userSortOrder: 0,
          ),
        ]);

        await done;
      },
    );
  });

  group('decode leniency', () {
    test('getSedarimOrder skips a document missing user_sort_order but '
        'still returns the valid ones', () async {
      final repo = buildRepo();
      await repo.saveSedarimOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: zeraim.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);
      await rawDoc('malformed_doc').set({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'sefaria_ref': 'Seder Something',
        // user_sort_order deliberately missing.
      });

      final result = await repo.getSedarimOrder(
        CurriculumId.mishnayos,
        allItems,
      );

      expect(result, hasLength(1));
      expect(result.single.sefariaRef, zeraim.sefariaRef);
    });

    test('does NOT accept a "ref" field alias — track_learning_order has no '
        'legacy payload shape to stay compatible with', () async {
      final repo = buildRepo();
      final docId = DocIds.trackLearningOrderDocId({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'sefaria_ref': zeraim.sefariaRef,
      });
      await rawDoc(docId).set({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'ref': zeraim.sefariaRef, // NOT sefaria_ref — must be rejected
        'user_sort_order': 0,
      });

      final result = await repo.getSedarimOrder(
        CurriculumId.mishnayos,
        allItems,
      );

      expect(
        result.every((i) => !i.isCustomOrdered),
        isTrue,
        reason:
            'the malformed doc has no sefaria_ref, so it is skipped and '
            'the query falls back to natural content order',
      );
    });
  });

  group('doc-id collision — proving track_learning_order and learning_order '
      'coexist for the SAME (curriculumId, sefariaRef) despite computing '
      'the identical doc-id string (see class doc comment)', () {
    test('DocIds.trackLearningOrderDocId and DocIds.learningOrderDocId '
        'compute the SAME string for the same natural key', () {
      final input = {
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'sefaria_ref': berakhot.sefariaRef,
      };

      expect(
        DocIds.trackLearningOrderDocId(input),
        DocIds.learningOrderDocId(input),
        reason:
            'both formulas are [encodeKeyComponent(curriculumId), '
            'encodeKeyComponent(ref)].join("_") — byte-for-byte '
            'identical. Disambiguation is the COLLECTION PATH, not '
            'this string.',
      );
    });

    test('a track-scoped write and a curriculum-scoped write for the same '
        '(curriculumId, sefariaRef) land in DIFFERENT collections and '
        'neither clobbers the other', () async {
      final trackRepo = buildRepo();
      final curriculumRepo = FirestoreLearningOrderRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );

      // Curriculum-scoped: Berakhot placed first among the curriculum's
      // masechtos (whole-curriculum order).
      await curriculumRepo.saveOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: berakhot.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
        LearningOrderItem(
          sefariaRef: peah.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);

      // Track-scoped: the SAME curriculumId + sefariaRef pair, but a
      // DIFFERENT position (99) — this is exactly the write the RED-DEMO
      // in firestore_learning_order_repository_test.dart shows silently
      // clobbering the curriculum-scoped row when routed through a
      // shared collection. Here it must NOT.
      await trackRepo.saveMasechtosOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: shabbat.sefariaRef, // pad so berakhot lands at index 1
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
        LearningOrderItem(
          sefariaRef: berakhot.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);

      final curriculumResult = await curriculumRepo.getOrder(
        CurriculumId.mishnayos,
        allItems,
      );
      final berakhotInCurriculumOrder = curriculumResult.firstWhere(
        (i) => i.sefariaRef == berakhot.sefariaRef,
      );
      expect(
        berakhotInCurriculumOrder.userSortOrder,
        0,
        reason:
            'the curriculum-scoped write must survive untouched — a '
            'track-scoped write for the identical (curriculumId, '
            'sefariaRef) pair must not be able to clobber it now that '
            'they live in separate collections',
      );

      final trackResult = await trackRepo.getMasechtosOrder(
        CurriculumId.mishnayos,
        allItems,
      );
      final berakhotInTrackOrder = trackResult.firstWhere(
        (i) => i.sefariaRef == berakhot.sefariaRef,
      );
      expect(berakhotInTrackOrder.userSortOrder, 1);

      // And structurally: both collections hold their own document for
      // the identical doc-id string, independently.
      final sharedDocId = DocIds.trackLearningOrderDocId({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'sefaria_ref': berakhot.sefariaRef,
      });
      final trackDoc = await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('track_learning_order')
          .doc(sharedDocId)
          .get();
      final learningOrderDoc = await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('learning_order')
          .doc(sharedDocId)
          .get();
      expect(trackDoc.exists, isTrue);
      expect(learningOrderDoc.exists, isTrue);
      expect(
        trackDoc.data()!['user_sort_order'],
        isNot(equals(learningOrderDoc.data()!['user_sort_order'])),
      );
    });

    test('firestore.rules\' track_learning_order .hasOnly() whitelist has '
        'no field to distinguish sedarim from masechtos rows', () {
      final rulesText = _loadFirestoreRulesText();
      final block = _extractMatchBlock(
        rulesText,
        'match /track_learning_order/{orderId}',
      );

      expect(block, contains('hasOnly'));
      for (final forbidden in ['track_id', 'trackId', 'scope', 'order_type']) {
        expect(
          block,
          isNot(contains(forbidden)),
          reason:
              'a client write carrying "$forbidden" would be rejected by '
              'hasOnly() today — sedarim/masechtos rows are disambiguated '
              'purely by which sefariaRef the caller\'s index recognises, '
              'never by a stored field',
        );
      }
    });
  });
}

/// Reads `firestore.rules` as text — mirrors `firestore_fake.dart`'s own
/// path-resolution (tests may run with cwd at the repo root or at
/// `learning_tracker/`).
String _loadFirestoreRulesText() {
  const candidates = ['../firestore.rules', 'firestore.rules'];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError(
    'firestore.rules not found. Tried: ${candidates.join(", ")}.',
  );
}

/// Extracts the brace-balanced `match { … }` block starting at [header]
/// from [rulesText] — mirrors
/// `firestore_learning_order_repository_test.dart`'s helper of the same
/// name exactly.
String _extractMatchBlock(String rulesText, String header) {
  final headerIndex = rulesText.indexOf(header);
  if (headerIndex == -1) {
    throw StateError('Could not find "$header" in firestore.rules');
  }
  final openBraceIndex = rulesText.indexOf('{', headerIndex + header.length);
  var depth = 0;
  for (var i = openBraceIndex; i < rulesText.length; i++) {
    if (rulesText[i] == '{') depth++;
    if (rulesText[i] == '}') {
      depth--;
      if (depth == 0) {
        return rulesText.substring(headerIndex, i + 1);
      }
    }
  }
  throw StateError('Unbalanced braces reading "$header" from firestore.rules');
}
