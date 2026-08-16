import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_track_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/firestore_fake.dart';
import '../../helpers/firestore_fixtures.dart';

const _uid = 'uid-l2';
const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';

ContentItem _seder(String ref, int sortOrder) => ContentItem(
  curriculumId: CurriculumId.mishnayos.storageKey,
  level1: ref,
  displayNameHe: ref,
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: sortOrder,
  isLeaf: false,
);

LearningOrderItem _orderItem(ContentItem item, int sortOrder) =>
    LearningOrderItem(
      sefariaRef: item.sefariaRef,
      displayNameHe: item.displayNameHe,
      displayNameEn: item.displayNameEn,
      userSortOrder: sortOrder,
    );

void main() {
  late FakeFirebaseFirestore firestore;
  final naturalItems = [_seder('Seder A', 0), _seder('Seder B', 1)];

  setUp(() async {
    expect(_profileId, hasLength(26));
    expect(_profileId, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]+$')));
    firestore = createFakeFirestore(authenticatedUid: _uid);
    installFakeClock(DateTime.utc(2026, 5, 27, 15));
    await seedProfile(firestore, uid: _uid, profileId: _profileId);
    await seedTrack(
      firestore,
      uid: _uid,
      profileId: _profileId,
      curriculumId: CurriculumId.mishnayos,
    );
  });

  FirestoreTrackLearningOrderRepository orderRepository() =>
      FirestoreTrackLearningOrderRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );

  FirestoreCurriculumTrackRepository trackRepository() =>
      FirestoreCurriculumTrackRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );

  test(
    'resetToDefault clears custom order with rules-legal tombstones',
    () async {
      final repository = orderRepository();
      await repository.saveSedarimOrder(CurriculumId.mishnayos, [
        _orderItem(naturalItems[1], 0),
        _orderItem(naturalItems[0], 1),
      ]);

      expect(
        (await repository.getSedarimOrder(
          CurriculumId.mishnayos,
          naturalItems,
        )).map((item) => item.sefariaRef),
        ['Seder B', 'Seder A'],
      );

      await repository.resetToDefault(CurriculumId.mishnayos);

      final reset = await repository.getSedarimOrder(
        CurriculumId.mishnayos,
        naturalItems,
      );
      expect(reset.map((item) => item.sefariaRef), ['Seder A', 'Seder B']);
      expect(reset.every((item) => !item.isCustomOrdered), isTrue);
      expect(
        (await trackRepository().getTrack(
          CurriculumId.mishnayos,
        ))!.lastReorderAt,
        DateTime.utc(2026, 5, 27, 15),
      );

      final rows = await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('track_learning_order')
          .get();
      expect(rows.docs, hasLength(2));
      expect(
        rows.docs.every((doc) => !doc.data().containsKey('user_sort_order')),
        isTrue,
      );
    },
  );

  test('resetToDefault is safe when no custom order exists', () async {
    final repository = orderRepository();

    await expectLater(
      repository.resetToDefault(CurriculumId.mishnayos),
      completes,
    );
    final rows = await firestore
        .collection('users')
        .doc(_uid)
        .collection('learner_profiles')
        .doc(_profileId)
        .collection('track_learning_order')
        .get();
    expect(rows.docs, isEmpty);
    expect(
      (await trackRepository().getTrack(CurriculumId.mishnayos))!.lastReorderAt,
      isNull,
    );
  });

  test(
    'reordering atomically stamps curriculum_tracks.last_reorder_at',
    () async {
      final repository = orderRepository();
      await repository.saveSedarimOrder(CurriculumId.mishnayos, [
        _orderItem(naturalItems[1], 0),
      ]);

      final track = await trackRepository().getTrack(CurriculumId.mishnayos);
      expect(track!.lastReorderAt, DateTime.utc(2026, 5, 27, 15));

      final rawTrack = await firestore
          .collection('users')
          .doc(_uid)
          .collection('learner_profiles')
          .doc(_profileId)
          .collection('curriculum_tracks')
          .doc(
            DocIds.curriculumTrackDocId({
              'curriculum_id': CurriculumId.mishnayos.storageKey,
            }),
          )
          .get();
      expect(rawTrack.data()!['last_reorder_at'], isNotNull);
    },
  );
}
