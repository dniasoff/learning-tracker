/// Unit tests for
/// `lib/data/repositories/firestore_learning_order_repository.dart` —
/// Epic B. Covers: doc-id correctness, content-enrichment round-trip (both
/// the custom-order branch and the natural-content-order fallback), the
/// composite-index-shaped `curriculum_id` + `user_sort_order` query,
/// reorder/save semantics, `resetToDefault`'s documented
/// [UnimplementedError], stream emission, decode leniency (a malformed
/// document, and the legacy `ref` field alias), and — the load-bearing
/// group — the `learning_order` doc-id collision finding described in the
/// class doc comment: two Drift tables (`LearningOrder`, curriculum-scoped,
/// and `TrackLearningOrder`, track-scoped) map onto this ONE Firestore
/// collection, and the "doc-id collision" group below proves concretely why
/// this repository only ports the curriculum-scoped side.
///
/// **What these tests cannot see** (same limitation as
/// `firestore_goal_repository_test.dart` /
/// `firestore_stage_definition_repository_test.dart`):
/// `fake_cloud_firestore`'s rules companion cannot evaluate
/// `resource.data`/`request.resource`, so `learning_order`'s rules
/// `.hasOnly()` field whitelist and its `allow delete: if false` are NOT
/// exercised as an enforcement mechanism here — a permissive fake is used
/// throughout (`createFakeFirestore()` default, `strictRules: false`). The
/// "rules whitelist has no discriminator field" test below reads
/// `firestore.rules` as TEXT instead (the only way to check a `.hasOnly()`
/// list `fake_cloud_firestore` cannot evaluate) — matching
/// `docs/firestore-rewrite-map.md`'s guidance that rules correctness for
/// `strictRules: true` cases "rests on reading the rules text". The
/// resubscribe-with-backoff behavior [FirestoreLearningOrderRepository
/// .watchOrder] delegates to is covered directly in
/// `resilient_doc_stream_test.dart` — not re-proven here. Firestore does
/// not enforce composite indexes in `fake_cloud_firestore` at all, so the
/// `curriculum_id` + `user_sort_order` query passing here is NOT proof the
/// required index exists in production — see the delivery report.
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
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

import '../../helpers/firestore_fake.dart';

const _uid = 'uid-1';
const _profileId = 'profile-ulid-1';

/// A level-2, non-leaf "masechta" content item — the shape both
/// [FirestoreLearningOrderRepository] (whole-curriculum) and the Drift
/// `TrackLearningOrderRepositoryImpl.saveMasechtosOrder` (track-scoped)
/// draw their orderable universe from. Used throughout to build
/// `allItems` for enrichment.
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
      .collection('learning_order');

  DocumentReference<Map<String, dynamic>> rawDoc(String docId) =>
      ordersCollection().doc(docId);

  FirestoreLearningOrderRepository buildRepo() {
    return FirestoreLearningOrderRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

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
  final demai = _masechta(
    curriculumId: CurriculumId.mishnayos.storageKey,
    level1: 'Seder Zeraim',
    sefariaRef: 'Mishnah Demai',
    he: 'דמאי',
    en: 'Demai',
    sortOrder: 2,
  );
  final allItems = [berakhot, peah, demai];

  group('doc-id correctness', () {
    test(
      'saveOrder writes to DocIds.learningOrderDocId({curriculum_id, sefaria_ref})',
      () async {
        final repo = buildRepo();

        await repo.saveOrder(CurriculumId.mishnayos, [
          LearningOrderItem(
            sefariaRef: berakhot.sefariaRef,
            displayNameHe: berakhot.displayNameHe,
            displayNameEn: berakhot.displayNameEn,
            userSortOrder: 0,
          ),
        ]);

        final expectedId = DocIds.learningOrderDocId({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'sefaria_ref': berakhot.sefariaRef,
        });
        final snapshot = await rawDoc(expectedId).get();
        expect(snapshot.exists, isTrue);
        expect(snapshot.data()!['user_sort_order'], 0);
      },
    );

    test(
      'two curricula with the same sefariaRef land on different documents',
      () async {
        final repo = buildRepo();

        await repo.saveOrder(CurriculumId.mishnayos, [
          const LearningOrderItem(
            sefariaRef: 'Shared Ref',
            displayNameHe: 'x',
            displayNameEn: 'x',
            userSortOrder: 0,
          ),
        ]);
        await repo.saveOrder(CurriculumId.bavli, [
          const LearningOrderItem(
            sefariaRef: 'Shared Ref',
            displayNameHe: 'x',
            displayNameEn: 'x',
            userSortOrder: 0,
          ),
        ]);

        final all = await ordersCollection().get();
        expect(all.docs, hasLength(2));
      },
    );

    test('never writes a track_id field (no per-device track key)', () async {
      final repo = buildRepo();

      await repo.saveOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: berakhot.sefariaRef,
          displayNameHe: berakhot.displayNameHe,
          displayNameEn: berakhot.displayNameEn,
          userSortOrder: 0,
        ),
      ]);

      final all = await ordersCollection().get();
      expect(all.docs.single.data(), isNot(contains('track_id')));
    });
  });

  group('getOrder — content-item enrichment round-trip', () {
    test(
      'falls back to natural content order when no custom order is saved',
      () async {
        final repo = buildRepo();

        final result = await repo.getOrder(CurriculumId.mishnayos, allItems);

        expect(result.map((i) => i.sefariaRef), [
          berakhot.sefariaRef,
          peah.sefariaRef,
          demai.sefariaRef,
        ]);
        expect(result.every((i) => !i.isCustomOrdered), isTrue);
        expect(result[0].displayNameHe, berakhot.displayNameHe);
      },
    );

    test(
      'returns the saved custom order, enriched with display names',
      () async {
        final repo = buildRepo();
        await repo.saveOrder(CurriculumId.mishnayos, [
          LearningOrderItem(
            sefariaRef: demai.sefariaRef,
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
            sefariaRef: peah.sefariaRef,
            displayNameHe: '?',
            displayNameEn: '?',
            userSortOrder: 0,
          ),
        ]);

        final result = await repo.getOrder(CurriculumId.mishnayos, allItems);

        expect(result.map((i) => i.sefariaRef), [
          demai.sefariaRef,
          berakhot.sefariaRef,
          peah.sefariaRef,
        ]);
        expect(result.every((i) => i.isCustomOrdered), isTrue);
        expect(result[0].displayNameHe, demai.displayNameHe);
        expect(result[0].displayNameEn, demai.displayNameEn);
      },
    );

    test(
      'the composite curriculum_id + user_sort_order query orders server-side',
      () async {
        final repo = buildRepo();
        // Write out of order to prove the query — not insertion order —
        // determines the result.
        await repo.saveOrder(CurriculumId.mishnayos, [
          LearningOrderItem(
            sefariaRef: peah.sefariaRef,
            displayNameHe: '?',
            displayNameEn: '?',
            userSortOrder: 0,
          ),
          LearningOrderItem(
            sefariaRef: demai.sefariaRef,
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

        final result = await repo.getOrder(CurriculumId.mishnayos, allItems);

        expect(
          result.map((i) => i.userSortOrder).toList(),
          [0, 1, 2],
          reason:
              'user_sort_order must be strictly ascending per the '
              'orderBy query',
        );
        expect(result.map((i) => i.sefariaRef), [
          peah.sefariaRef,
          demai.sefariaRef,
          berakhot.sefariaRef,
        ]);
      },
    );
  });

  group('getCustomOrderRefs', () {
    test('returns [] when no learning_order documents exist, even though '
        'getOrder synthesizes a non-empty natural-order list from the same '
        'content', () async {
      final repo = buildRepo();

      final customRefs = await repo.getCustomOrderRefs(CurriculumId.mishnayos);
      final synthesized = await repo.getOrder(CurriculumId.mishnayos, allItems);

      expect(
        customRefs,
        isEmpty,
        reason:
            'no learning_order rows were ever saved for this curriculum — '
            'this must be the raw-row truth, not a synthesized fallback',
      );
      expect(
        synthesized,
        isNotEmpty,
        reason:
            'getOrder falls back to a synthesized natural-order list even '
            'with zero stored rows — pinning the exact contrast '
            'getCustomOrderRefs exists to resolve',
      );
    });

    test('returns the saved refs in user_sort_order order, in an order that '
        'differs from the items\' natural sortOrder', () async {
      final repo = buildRepo();
      // Natural sortOrder is berakhot(0), peah(1), demai(2). Save a
      // custom order that is neither that order nor its reverse, so a
      // regression to natural order cannot accidentally pass.
      await repo.saveOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: peah.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
        LearningOrderItem(
          sefariaRef: demai.sefariaRef,
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

      final customRefs = await repo.getCustomOrderRefs(CurriculumId.mishnayos);

      expect(customRefs, [
        peah.sefariaRef,
        demai.sefariaRef,
        berakhot.sefariaRef,
      ]);
    });

    test('is curriculum-scoped — rows saved for another curriculum are not '
        'returned', () async {
      final repo = buildRepo();
      await repo.saveOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: berakhot.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);
      await repo.saveOrder(CurriculumId.bavli, [
        const LearningOrderItem(
          sefariaRef: 'Berakhot 2a',
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);

      final customRefs = await repo.getCustomOrderRefs(CurriculumId.mishnayos);

      expect(customRefs, [berakhot.sefariaRef]);
    });

    test('skips a malformed document (missing sefaria_ref) and still returns '
        'the well-formed ones', () async {
      final repo = buildRepo();
      await repo.saveOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: berakhot.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);
      await rawDoc('malformed_doc').set({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'user_sort_order': 1,
        // sefaria_ref (and legacy ref) deliberately missing.
      });

      final customRefs = await repo.getCustomOrderRefs(CurriculumId.mishnayos);

      expect(customRefs, [berakhot.sefariaRef]);
    });
  });

  group('saveOrder — reorder semantics', () {
    test('re-saving a new order overwrites the same documents rather than '
        'accumulating duplicates', () async {
      final repo = buildRepo();
      await repo.saveOrder(CurriculumId.mishnayos, [
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

      // Reorder: swap the two, plus add a third item.
      await repo.saveOrder(CurriculumId.mishnayos, [
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
          sefariaRef: demai.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);

      final all = await ordersCollection().get();
      expect(
        all.docs,
        hasLength(3),
        reason:
            'same (curriculumId, sefariaRef) pairs must overwrite, '
            'not duplicate',
      );
      final result = await repo.getOrder(CurriculumId.mishnayos, allItems);
      expect(result.map((i) => i.sefariaRef), [
        peah.sefariaRef,
        berakhot.sefariaRef,
        demai.sefariaRef,
      ]);
    });

    test('writes the LIST POSITION as user_sort_order, ignoring the item\'s '
        'own userSortOrder field', () async {
      final repo = buildRepo();

      await repo.saveOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: berakhot.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 999, // deliberately wrong — must be ignored
        ),
      ]);

      final docId = DocIds.learningOrderDocId({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'sefaria_ref': berakhot.sefariaRef,
      });
      final snapshot = await rawDoc(docId).get();
      expect(snapshot.data()!['user_sort_order'], 0);
    });
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

  group('watchOrder — stream emits on change', () {
    test('emits the custom order once saved', () async {
      final repo = buildRepo();

      final stream = repo
          .watchOrder(CurriculumId.mishnayos, allItems)
          .map((items) => items.map((i) => i.sefariaRef).toList());
      final done = expectLater(
        stream,
        emitsThrough([berakhot.sefariaRef, peah.sefariaRef]),
      );

      await repo.saveOrder(CurriculumId.mishnayos, [
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

      await done;
    });
  });

  group('decode leniency', () {
    test('getOrder skips a document missing user_sort_order but still returns '
        'the valid ones', () async {
      final repo = buildRepo();
      await repo.saveOrder(CurriculumId.mishnayos, [
        LearningOrderItem(
          sefariaRef: berakhot.sefariaRef,
          displayNameHe: '?',
          displayNameEn: '?',
          userSortOrder: 0,
        ),
      ]);
      await rawDoc('malformed_doc').set({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'sefaria_ref': 'Mishnah Something',
        // user_sort_order deliberately missing — orderBy would drop this
        // doc from the query entirely (trap #1), but for belt-and-braces
        // we also exercise the decode-skip path directly.
      });

      final result = await repo.getOrder(CurriculumId.mishnayos, allItems);

      expect(result, hasLength(1));
      expect(result.single.sefariaRef, berakhot.sefariaRef);
    });

    test(
      'accepts the legacy "ref" field alias for sefaria_ref on read',
      () async {
        final repo = buildRepo();
        final docId = DocIds.learningOrderDocId({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'sefaria_ref': berakhot.sefariaRef,
        });
        await rawDoc(docId).set({
          'curriculum_id': CurriculumId.mishnayos.storageKey,
          'ref': berakhot.sefariaRef, // legacy key, no sefaria_ref present
          'user_sort_order': 0,
        });

        final result = await repo.getOrder(CurriculumId.mishnayos, allItems);

        expect(result, hasLength(1));
        expect(result.single.sefariaRef, berakhot.sefariaRef);
      },
    );
  });

  group('doc-id collision — why this repository does NOT also serve '
      'TrackLearningOrder (see class doc comment "The collision finding")', () {
    test('DocIds.learningOrderDocId depends ONLY on curriculum_id + '
        'sefaria_ref — no track/scope component exists in the formula', () {
      final withoutTrack = DocIds.learningOrderDocId({
        'curriculum_id': 'mishnayos',
        'sefaria_ref': 'Mishnah Berakhot',
      });
      final withUnrelatedTrackField = DocIds.learningOrderDocId({
        'curriculum_id': 'mishnayos',
        'sefaria_ref': 'Mishnah Berakhot',
        // AD-25: track_id is a Drift-local autoincrement int with no
        // Firestore meaning; even if a caller supplied one, the
        // formula has no parameter position to consume it.
        'track_id': 42,
      });

      expect(
        withUnrelatedTrackField,
        withoutTrack,
        reason:
            'the formula reads only curriculum_id/sefaria_ref (or the '
            'legacy ref alias) — an extra track_id key in the input '
            'map is silently ignored, proving there is no key '
            'component available to disambiguate a track-scoped row '
            'from a curriculum-scoped one',
      );
    });

    test('RED-DEMO: a second logical writer for the same (curriculumId, '
        'sefariaRef) silently overwrites the first — no error, no merge, '
        'no signal', () async {
      final repo = buildRepo();

      // Write #1 simulates the curriculum-scoped whole-curriculum
      // order this repository actually implements: Berakhot placed
      // first (position 0) among the curriculum's masechtos.
      await repo.saveOrder(CurriculumId.mishnayos, [
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
      final afterFirstWrite = await repo.getOrder(
        CurriculumId.mishnayos,
        allItems,
      );
      expect(afterFirstWrite.first.sefariaRef, berakhot.sefariaRef);

      // Write #2 simulates what a hypothetical Firestore-backed
      // TrackLearningOrder writer would have to do: since curriculum_id
      // is the sole canonical track key (AD-25) and the doc-id formula
      // has no spare component, a track-scoped "put Berakhot last"
      // masechtos-reorder would resolve to the IDENTICAL doc-id as
      // write #1's Berakhot row and land through the same
      // save-path shape.
      final docId = DocIds.learningOrderDocId({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'sefaria_ref': berakhot.sefariaRef,
      });
      await rawDoc(docId).set({
        'curriculum_id': CurriculumId.mishnayos.storageKey,
        'sefaria_ref': berakhot.sefariaRef,
        'user_sort_order': 99, // "track-scoped" value clobbers write #1
      }, SetOptions(merge: true));

      final afterSecondWrite = await repo.getOrder(
        CurriculumId.mishnayos,
        allItems,
      );
      final berakhotRow = afterSecondWrite.firstWhere(
        (i) => i.sefariaRef == berakhot.sefariaRef,
      );

      expect(
        berakhotRow.userSortOrder,
        99,
        reason:
            'the second write silently replaced the first — the '
            'curriculum-scoped order\'s Berakhot position (0) is gone, '
            'with no exception, no merge conflict, and no field '
            'anywhere recording that two different intents targeted '
            'this document. This is exactly why '
            'FirestoreLearningOrderRepository does not expose a '
            'second, track-scoped write path onto this collection.',
      );
    });

    test('firestore.rules\' learning_order .hasOnly() whitelist has no '
        'field to distinguish a curriculum-scoped write from a '
        'track-scoped one', () {
      final rulesText = _loadFirestoreRulesText();
      final learningOrderBlock = _extractMatchBlock(
        rulesText,
        'match /learning_order/{orderId}',
      );

      expect(
        learningOrderBlock,
        contains('hasOnly'),
        reason: 'sanity check — the block must exist and be whitelisted',
      );
      for (final forbidden in ['track_id', 'trackId', 'scope']) {
        expect(
          learningOrderBlock,
          isNot(contains(forbidden)),
          reason:
              'a client write carrying "$forbidden" would be rejected '
              'by hasOnly() today — confirming no rules-legal '
              'discriminator field exists for a second writer without '
              'a rules change',
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
/// from [rulesText] — just enough parsing to isolate one collection's rule
/// block for a text-based whitelist assertion (`fake_cloud_firestore`
/// cannot evaluate `request.resource` at all, so this is the only way to
/// check a `.hasOnly()` list from a test).
String _extractMatchBlock(String rulesText, String header) {
  final headerIndex = rulesText.indexOf(header);
  if (headerIndex == -1) {
    throw StateError('Could not find "$header" in firestore.rules');
  }
  // Start the search AFTER the header text itself — the header
  // (`match /learning_order/{orderId}`) already contains one balanced
  // `{orderId}` pair, which would otherwise be mistaken for the block's
  // opening brace and close the scan immediately.
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
