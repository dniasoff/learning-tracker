/// Tests for [TrackLearningOrderRepositoryImpl].
///
/// Covers:
///  - getSedarimOrder: default sort (no user order), custom sort via dao
///  - getMasechtosOrder: default sort, custom sort respecting seder grouping
///  - saveSedarimOrder / saveMasechtosOrder: persists refs via dao
///  - resetToDefault: clears stored order
///
/// AUD-tracks-15 (SM-8): TrackLearningOrderRepositoryImpl no longer takes a
/// ContentRepository dependency — getSedarimOrder/getMasechtosOrder accept
/// the already-resolved `List<ContentItem>` directly, so every test below
/// constructs the repo with only a fake/in-memory database and passes the
/// fixture items straight into the get* calls (no ContentRepository fake
/// required).
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/repositories/firestore_track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

import '../../../../helpers/firestore_fake.dart';

// ---------------------------------------------------------------------------
// Helpers for building content items
// ---------------------------------------------------------------------------

ContentItem _seder(String ref, {int sortOrder = 0}) => ContentItem(
  sefariaRef: ref,
  displayNameEn: ref,
  displayNameHe: ref,
  curriculumId: CurriculumId.mishnayos.storageKey,
  sortOrder: sortOrder,
  isLeaf: false,
  level1: ref,
  level2: null,
  level3: null,
  level4: null,
);

ContentItem _masechta(String seder, String ref, {int sortOrder = 0}) =>
    ContentItem(
      sefariaRef: ref,
      displayNameEn: ref,
      displayNameHe: ref,
      curriculumId: CurriculumId.mishnayos.storageKey,
      sortOrder: sortOrder,
      isLeaf: false,
      level1: seder,
      level2: ref,
      level3: null,
      level4: null,
    );

/// Builds a leaf item — should be excluded from seder/masechta index building.
ContentItem _leaf(String ref, {required String seder, String? masechta}) =>
    ContentItem(
      sefariaRef: ref,
      displayNameEn: ref,
      displayNameHe: ref,
      curriculumId: CurriculumId.mishnayos.storageKey,
      sortOrder: 0,
      isLeaf: true,
      level1: seder,
      level2: masechta,
      level3: ref,
      level4: null,
    );

LearningOrderItem _item(String ref, [int order = 0]) => LearningOrderItem(
  sefariaRef: ref,
  displayNameHe: ref,
  displayNameEn: ref,
  userSortOrder: order,
);

/// Creates a hierarchy:
///   Seder Zeraim (L1 container, no L2)
///     └── Berakhot (L2 container, no L3)
///           └── Berakhot 1:1 (leaf)
List<ContentItem> _mishnaItems() => [
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Zeraim',
    displayNameHe: 'סדר זרעים',
    displayNameEn: 'Seder Zeraim',
    sefariaRef: 'Seder Zeraim',
    sortOrder: 0,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Zeraim',
    level2: 'Berakhot',
    displayNameHe: 'ברכות',
    displayNameEn: 'Berakhot',
    sefariaRef: 'Berakhot',
    sortOrder: 1,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Zeraim',
    level2: 'Berakhot',
    level3: '1',
    level4: '1',
    displayNameHe: 'ברכות א׃א',
    displayNameEn: 'Berakhot 1:1',
    sefariaRef: 'Mishnah Berakhot 1:1',
    sortOrder: 2,
    isLeaf: true,
  ),
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const uid = 'track-order-uid';
  const profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY1';
  const curriculum = CurriculumId.mishnayos;
  late FakeFirebaseFirestore firestore;
  late FirestoreTrackLearningOrderRepository repo;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: uid);
    repo = FirestoreTrackLearningOrderRepository(
      firestore: firestore,
      uid: uid,
      profileId: profileId,
    );
  });

  group('getSedarimOrder', () {
    test('returns sedarim sorted by natural order', () async {
      final result = await repo.getSedarimOrder(curriculum, [
        _seder('Nashim', sortOrder: 2),
        _seder('Zeraim', sortOrder: 0),
        _seder('Moed', sortOrder: 1),
      ]);
      expect(result.map((item) => item.sefariaRef), [
        'Zeraim',
        'Moed',
        'Nashim',
      ]);
      expect(result.every((item) => !item.isCustomOrdered), isTrue);
    });

    test('returns empty when no seder containers exist', () async {
      expect(await repo.getSedarimOrder(curriculum, const []), isEmpty);
    });

    test('excludes masechtos and leaves', () async {
      final result = await repo.getSedarimOrder(curriculum, [
        _seder('Zeraim'),
        _masechta('Zeraim', 'Berakhot'),
        _leaf('Berakhot 1:1', seder: 'Zeraim', masechta: 'Berakhot'),
      ]);
      expect(result, hasLength(1));
      expect(result.first.sefariaRef, 'Zeraim');
    });

    test('respects a saved custom order', () async {
      await repo.saveSedarimOrder(curriculum, [
        _item('Nashim', 0),
        _item('Moed', 1),
        _item('Zeraim', 2),
      ]);
      final result = await repo.getSedarimOrder(curriculum, [
        _seder('Zeraim'),
        _seder('Moed'),
        _seder('Nashim'),
      ]);
      expect(result.map((item) => item.sefariaRef), [
        'Nashim',
        'Moed',
        'Zeraim',
      ]);
      expect(result.every((item) => item.isCustomOrdered), isTrue);
    });
  });

  group('getMasechtosOrder', () {
    test('returns masechtos sorted by natural order', () async {
      final result = await repo.getMasechtosOrder(curriculum, [
        _seder('Zeraim'),
        _masechta('Zeraim', 'Berakhot'),
        _masechta('Zeraim', 'Peah', sortOrder: 1),
      ]);
      expect(result.map((item) => item.sefariaRef), ['Berakhot', 'Peah']);
      expect(result.every((item) => !item.isCustomOrdered), isTrue);
    });

    test('returns empty when no masechtos exist', () async {
      expect(
        await repo.getMasechtosOrder(curriculum, [_seder('Zeraim')]),
        isEmpty,
      );
    });

    test('excludes leaves', () async {
      final result = await repo.getMasechtosOrder(curriculum, [
        _seder('Zeraim'),
        _masechta('Zeraim', 'Berakhot'),
        _leaf('Berakhot 1:1', seder: 'Zeraim', masechta: 'Berakhot'),
      ]);
      expect(result, hasLength(1));
      expect(result.first.sefariaRef, 'Berakhot');
    });

    test('respects a saved custom order', () async {
      await repo.saveMasechtosOrder(curriculum, [
        _item('Peah', 0),
        _item('Berakhot', 1),
      ]);
      final result = await repo.getMasechtosOrder(curriculum, [
        _seder('Zeraim'),
        _masechta('Zeraim', 'Berakhot'),
        _masechta('Zeraim', 'Peah', sortOrder: 1),
      ]);
      expect(result.map((item) => item.sefariaRef), ['Peah', 'Berakhot']);
      expect(result.every((item) => item.isCustomOrdered), isTrue);
    });
  });

  group('writes and reset', () {
    test('saveSedarimOrder round-trips through Firestore', () async {
      await repo.saveSedarimOrder(curriculum, [
        _item('Moed', 0),
        _item('Zeraim', 1),
      ]);
      final result = await repo.getSedarimOrder(curriculum, [
        _seder('Zeraim'),
        _seder('Moed', sortOrder: 1),
      ]);
      expect(result.map((item) => item.sefariaRef), ['Moed', 'Zeraim']);

      final docs = await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(profileId)
          .collection('track_learning_order')
          .get();
      expect(docs.docs, hasLength(2));
    });

    test('a second save replaces rather than duplicates rows', () async {
      await repo.saveSedarimOrder(curriculum, [_item('Zeraim')]);
      await repo.saveSedarimOrder(curriculum, [_item('Zeraim')]);
      final docs = await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(profileId)
          .collection('track_learning_order')
          .get();
      expect(docs.docs, hasLength(1));
    });

    test('save empty list is a no-op', () async {
      await repo.saveSedarimOrder(curriculum, const []);
      final snapshot = await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(profileId)
          .collection('track_learning_order')
          .get();
      expect(snapshot.docs, isEmpty);
    });

    test(
      'resetToDefault is not portable through the Firestore client seam',
      skip:
          'Firestore rules deny client deletes; the production repository '
          'deliberately exposes resetToDefault as UnimplementedError.',
      () async {},
    );
  });

  group('hierarchy and curriculum isolation', () {
    test('walks nested mishna hierarchy', () async {
      final result = await repo.getMasechtosOrder(curriculum, _mishnaItems());
      expect(result, hasLength(1));
      expect(result.first.sefariaRef, 'Berakhot');
      expect(result.first.isCustomOrdered, isFalse);
    });

    test('custom hierarchy order round-trips', () async {
      await repo.saveMasechtosOrder(curriculum, [_item('Berakhot')]);
      final result = await repo.getMasechtosOrder(curriculum, _mishnaItems());
      expect(result.first.isCustomOrdered, isTrue);
    });

    test('different curriculum has isolated order documents', () async {
      await repo.saveSedarimOrder(curriculum, [_item('Zeraim')]);
      final bavli = await repo.getSedarimOrder(CurriculumId.bavli, [
        _seder('Zeraim'),
      ]);
      expect(bavli.first.isCustomOrdered, isFalse);
    });
  });
}
