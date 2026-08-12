/// Firestore contract tests for the per-track learning-order repository.
///
/// AD-25 makes CurriculumId the sole track identity. These tests deliberately
/// use the real Firestore repository with a fake Firestore instance; there is
/// no Drift track-id bridge left to exercise.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/repositories/firestore_track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

import '../../../../../helpers/firestore_fake.dart';

ContentItem _seder(String ref, {int sortOrder = 0}) => ContentItem(
  sefariaRef: ref,
  displayNameEn: ref,
  displayNameHe: ref,
  curriculumId: CurriculumId.mishnayos.storageKey,
  sortOrder: sortOrder,
  isLeaf: false,
  level1: ref,
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
    );

LearningOrderItem _item(String ref, [int order = 0]) => LearningOrderItem(
  sefariaRef: ref,
  displayNameHe: ref,
  displayNameEn: ref,
  userSortOrder: order,
);

void main() {
  const uid = 'track-order-uid';
  const profileId = '01J6Q2H4A8M7K3P9R5T6V8WXY1';
  const curriculum = CurriculumId.mishnayos;
  late FirestoreTrackLearningOrderRepository repo;

  setUp(() {
    repo = FirestoreTrackLearningOrderRepository(
      firestore: createFakeFirestore(authenticatedUid: uid),
      uid: uid,
      profileId: profileId,
    );
  });

  test(
    'returns containers in natural order when no custom order exists',
    () async {
      final result = await repo.getSedarimOrder(curriculum, [
        _seder('Nashim', sortOrder: 2),
        _seder('Zeraim'),
        _seder('Moed', sortOrder: 1),
        _masechta('Zeraim', 'Berakhot'),
      ]);

      expect(result.map((item) => item.sefariaRef), [
        'Zeraim',
        'Moed',
        'Nashim',
      ]);
      expect(result.every((item) => !item.isCustomOrdered), isTrue);
    },
  );

  test('saves and reads a custom seder order from Firestore', () async {
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

    expect(result.map((item) => item.sefariaRef), ['Nashim', 'Moed', 'Zeraim']);
    expect(result.every((item) => item.isCustomOrdered), isTrue);
  });

  test('keeps custom orders isolated by curriculum', () async {
    await repo.saveSedarimOrder(curriculum, [_item('Zeraim')]);

    final bavli = await repo.getSedarimOrder(CurriculumId.bavli, [
      _seder('Zeraim'),
    ]);
    expect(bavli.single.isCustomOrdered, isFalse);
  });

  test('saves masechtos in the supplied order', () async {
    await repo.saveMasechtosOrder(curriculum, [
      _item('Peah', 0),
      _item('Berakhot', 1),
    ]);

    final result = await repo.getMasechtosOrder(curriculum, [
      _masechta('Zeraim', 'Berakhot'),
      _masechta('Zeraim', 'Peah', sortOrder: 1),
    ]);
    expect(result.map((item) => item.sefariaRef), ['Peah', 'Berakhot']);
  });

  test(
    'resetToDefault is not portable through the Firestore client seam',
    skip:
        'Firestore rules deny client deletes; production deliberately exposes resetToDefault as UnimplementedError.',
    () async {},
  );
}
