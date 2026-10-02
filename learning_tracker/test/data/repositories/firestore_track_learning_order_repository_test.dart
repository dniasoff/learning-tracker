/// Unit tests for
/// `lib/data/repositories/firestore_track_learning_order_repository.dart`
/// (DNI-476 / Story 1.14 AC-2): the main-track order lives in
/// `track_learning_order/{c}_{level}_{ref}` (the retired `learning_order`
/// collection is merged into it), a reorder is ONE logged `mainTrackOrder`
/// change, "reset to default" sets `ended_at` on every order doc of the
/// curriculum, oversized writes go online, and the scheduler / bookmark
/// order is `orderedLeaves`.
///
/// Writes run through `FirestoreGovernedWriter` (the real governed commands
/// and change-log repository on the fake Firestore). `fake_cloud_firestore`
/// does not evaluate the owner rules; those are the emulator suite's job.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_track_learning_order_repository.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

import '../../helpers/firestore_fake.dart';
import '../../helpers/firestore_governed_writer.dart';

const _uid = 'uid-1';
const _profileId = governedTestProfileId;
const _c = CurriculumId.mishnayos;

ContentItem _item({
  required String ref,
  required int sortOrder,
  required List<String> path,
  bool isLeaf = false,
}) => ContentItem(
  curriculumId: _c.storageKey,
  level1: path[0],
  level2: path.length > 1 ? path[1] : null,
  level3: path.length > 2 ? path[2] : null,
  displayNameHe: '$ref he',
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: sortOrder,
  isLeaf: isLeaf,
);

/// Two sedarim, three masechtos, two leaves per masechta.
final _items = <ContentItem>[
  _item(ref: 'Zeraim', sortOrder: 0, path: ['Zeraim']),
  _item(ref: 'Berakhot', sortOrder: 1, path: ['Zeraim', 'Berakhot']),
  _item(
    ref: 'Berakhot 1',
    sortOrder: 2,
    path: ['Zeraim', 'Berakhot', '1'],
    isLeaf: true,
  ),
  _item(
    ref: 'Berakhot 2',
    sortOrder: 3,
    path: ['Zeraim', 'Berakhot', '2'],
    isLeaf: true,
  ),
  _item(ref: 'Peah', sortOrder: 4, path: ['Zeraim', 'Peah']),
  _item(
    ref: 'Peah 1',
    sortOrder: 5,
    path: ['Zeraim', 'Peah', '1'],
    isLeaf: true,
  ),
  _item(
    ref: 'Peah 2',
    sortOrder: 6,
    path: ['Zeraim', 'Peah', '2'],
    isLeaf: true,
  ),
  _item(ref: 'Moed', sortOrder: 7, path: ['Moed']),
  _item(ref: 'Shabbat', sortOrder: 8, path: ['Moed', 'Shabbat']),
  _item(
    ref: 'Shabbat 1',
    sortOrder: 9,
    path: ['Moed', 'Shabbat', '1'],
    isLeaf: true,
  ),
  _item(
    ref: 'Shabbat 2',
    sortOrder: 10,
    path: ['Moed', 'Shabbat', '2'],
    isLeaf: true,
  ),
];

LearningOrderItem _order(String ref) => LearningOrderItem(
  sefariaRef: ref,
  displayNameHe: ref,
  displayNameEn: ref,
  userSortOrder: 0,
);

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreGovernedWriter writer;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    writer = FirestoreGovernedWriter(firestore, uid: _uid);
  });

  DocumentReference<Map<String, dynamic>> profile() => firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId);

  CollectionReference<Map<String, dynamic>> orders() =>
      profile().collection('track_learning_order');

  FirestoreTrackLearningOrderRepository buildRepo() =>
      FirestoreTrackLearningOrderRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
        writer: writer,
        clock: () => governedTestNow,
      );

  final seder = FirestoreTrackLearningOrderRepository.levelName(_c, 1);
  final masechta = FirestoreTrackLearningOrderRepository.levelName(_c, 2);

  String docId(String level, String ref) => DocIds.trackLearningOrderDocId({
    'curriculum_id': _c.storageKey,
    'level': level,
    'ref': ref,
  });

  group('a reorder is one logged mainTrackOrder change', () {
    test('saveSedarimOrder writes {c}_{level}_{ref} docs with level, ref, '
        'user_sort_order, curriculum_id and the entry id', () async {
      await buildRepo().saveSedarimOrder(_c, [
        _order('Moed'),
        _order('Zeraim'),
      ]);

      final entry = (await writer.lastEntries()).single;
      expect(entry.entity, GovernedEntity.mainTrackOrder);
      expect(entry.entityId, 'mishnayos');
      final moed = (await orders().doc(docId(seder, 'Moed')).get()).data();
      expect(moed, {
        'level': seder,
        'ref': 'Moed',
        'user_sort_order': 0,
        'curriculum_id': 'mishnayos',
        'last_change_id': entry.id,
      });
      expect(
        (await orders().doc(docId(seder, 'Zeraim')).get())
            .data()?['user_sort_order'],
        1,
      );
      // R13: nothing reaches the retired collection, and the retired
      // reorder-amnesty stamp is not written.
      expect(
        (await profile().collection('learning_order').get()).docs,
        isEmpty,
      );
      expect(
        (await profile().collection('curriculum_tracks').get()).docs,
        isEmpty,
      );
    });

    test('saving the same order again writes nothing', () async {
      final repo = buildRepo();
      await repo.saveSedarimOrder(_c, [_order('Moed'), _order('Zeraim')]);
      await repo.saveSedarimOrder(_c, [_order('Moed'), _order('Zeraim')]);
      expect(writer.actions, hasLength(1));
    });

    test(
      'only the docs whose position changes are part of the entity',
      () async {
        final repo = buildRepo();
        await repo.saveMasechtosOrder(_c, [
          _order('Berakhot'),
          _order('Peah'),
          _order('Shabbat'),
        ]);
        await repo.saveMasechtosOrder(_c, [
          _order('Peah'),
          _order('Berakhot'),
          _order('Shabbat'),
        ]);
        expect(writer.actions.last.changes.single.docs.map((d) => d.docId), {
          docId(masechta, 'Peah'),
          docId(masechta, 'Berakhot'),
        });
      },
    );

    test('a reorder over 10 docs goes whole through the online path; '
        'offline it is refused and nothing is written', () async {
      final many = [for (var i = 0; i < 11; i++) _order('M$i')];
      writer.oversized.online = false;
      await expectLater(
        buildRepo().saveMasechtosOrder(_c, many),
        throwsA(
          isA<GovernedWriteRejectedException>().having(
            (e) => e.result,
            'result',
            const CaptureResult.onlineRequired(),
          ),
        ),
      );
      expect((await orders().get()).docs, isEmpty);

      writer.oversized.online = true;
      await buildRepo().saveMasechtosOrder(_c, many);
      final request = writer.oversized.requests.single;
      expect(
        request.entries.single.change.entity,
        GovernedEntity.mainTrackOrder,
      );
      expect(request.entries.single.change.docs, hasLength(11));
      expect((await orders().get()).docs, hasLength(11));
    });

    test('with no writer a reorder throws and writes nothing', () async {
      final repo = FirestoreTrackLearningOrderRepository(
        firestore: firestore,
        uid: _uid,
        profileId: _profileId,
      );
      await expectLater(
        repo.saveSedarimOrder(_c, [_order('Moed')]),
        throwsA(isA<GovernedWriterNotReadyException>()),
      );
      expect((await orders().get()).docs, isEmpty);
    });
  });

  group('reads for the order screen', () {
    test('natural order when nothing is saved', () async {
      final sedarim = await buildRepo().getSedarimOrder(_c, _items);
      expect(sedarim.map((s) => s.sefariaRef), ['Zeraim', 'Moed']);
      expect(sedarim.every((s) => !s.isCustomOrdered), isTrue);
    });

    test('the saved sedarim order, enriched from the content tree', () async {
      final repo = buildRepo();
      await repo.saveSedarimOrder(_c, [_order('Moed'), _order('Zeraim')]);
      final sedarim = await repo.getSedarimOrder(_c, _items);
      expect(sedarim.map((s) => s.sefariaRef), ['Moed', 'Zeraim']);
      expect(sedarim.first.displayNameHe, 'Moed he');
      expect(sedarim.every((s) => s.isCustomOrdered), isTrue);
    });

    test('a saved seder order re-prioritises the masechtos', () async {
      final repo = buildRepo();
      await repo.saveSedarimOrder(_c, [_order('Moed'), _order('Zeraim')]);
      final masechtos = await repo.getMasechtosOrder(_c, _items);
      expect(masechtos.map((m) => m.sefariaRef), [
        'Shabbat',
        'Berakhot',
        'Peah',
      ]);
    });

    test('a saved masechtos order is returned as saved', () async {
      final repo = buildRepo();
      await repo.saveMasechtosOrder(_c, [
        _order('Peah'),
        _order('Shabbat'),
        _order('Berakhot'),
      ]);
      final masechtos = await repo.getMasechtosOrder(_c, _items);
      expect(masechtos.map((m) => m.sefariaRef), [
        'Peah',
        'Shabbat',
        'Berakhot',
      ]);
    });

    test('watchSedarimOrder emits the saved order', () async {
      final repo = buildRepo();
      final done = expectLater(
        repo
            .watchSedarimOrder(_c, _items)
            .map((items) => items.map((i) => i.sefariaRef).toList()),
        emitsThrough(['Moed', 'Zeraim']),
      );
      await repo.saveSedarimOrder(_c, [_order('Moed'), _order('Zeraim')]);
      await done;
    });

    test('a malformed doc is skipped, not the whole list', () async {
      await orders().doc('bad').set({'curriculum_id': 'mishnayos'});
      await buildRepo().saveSedarimOrder(_c, [
        _order('Moed'),
        _order('Zeraim'),
      ]);
      final sedarim = await buildRepo().getSedarimOrder(_c, _items);
      expect(sedarim.map((s) => s.sefariaRef), ['Moed', 'Zeraim']);
    });
  });

  group('reset to default sets ended_at on every order doc', () {
    test(
      'one logged change tombstones every live doc of the curriculum; '
      'reads fall back to natural order; other curricula untouched',
      () async {
        final repo = buildRepo();
        await repo.saveSedarimOrder(_c, [_order('Moed'), _order('Zeraim')]);
        await repo.saveMasechtosOrder(_c, [_order('Peah'), _order('Berakhot')]);
        await orders().doc('bavli_masechet_Shabbat').set({
          'curriculum_id': 'bavli',
          'level': 'masechet',
          'ref': 'Shabbat',
          'user_sort_order': 0,
        });

        await repo.resetToDefault(_c);

        final entry = (await writer.lastEntries()).single;
        expect(entry.entity, GovernedEntity.mainTrackOrder);
        expect(entry.after.keys, hasLength(4));
        expect(entry.after.keys, everyElement(endsWith('.ended_at')));
        final mine = await orders()
            .where('curriculum_id', isEqualTo: 'mishnayos')
            .get();
        expect(mine.docs, hasLength(4));
        expect(
          mine.docs.map((d) => d.data()['ended_at']),
          everyElement(isA<Timestamp>()),
        );
        expect(
          (await orders().doc('bavli_masechet_Shabbat').get())
              .data()?['ended_at'],
          isNull,
        );
        final sedarim = await repo.getSedarimOrder(_c, _items);
        expect(sedarim.map((s) => s.sefariaRef), ['Zeraim', 'Moed']);
        expect(sedarim.every((s) => !s.isCustomOrdered), isTrue);
      },
    );

    test('is a no-op when no live order exists', () async {
      await buildRepo().resetToDefault(_c);
      expect(writer.actions, isEmpty);
    });

    test('a later reorder revives the ended docs', () async {
      final repo = buildRepo();
      await repo.saveSedarimOrder(_c, [_order('Moed'), _order('Zeraim')]);
      await repo.resetToDefault(_c);
      await repo.saveSedarimOrder(_c, [_order('Moed'), _order('Zeraim')]);
      final sedarim = await repo.getSedarimOrder(_c, _items);
      expect(sedarim.map((s) => s.sefariaRef), ['Moed', 'Zeraim']);
      expect(
        (await orders().doc(docId(seder, 'Moed')).get()).data()?['ended_at'],
        isNull,
      );
    });
  });

  group(
    'orderedLeafRefs — the AD-33 order the scheduler and bookmark read',
    () {
      Future<List<ContentItem>> content() async => _items;

      test('empty (natural order) with no live order doc', () async {
        var fetched = false;
        final refs = await buildRepo().orderedLeafRefs(
          _c,
          content: () async {
            fetched = true;
            return _items;
          },
        );
        expect(refs, isEmpty);
        expect(fetched, isFalse, reason: 'no content fetch without an order');
      });

      test('a seder order moves the whole seder subtree', () async {
        final repo = buildRepo();
        await repo.saveSedarimOrder(_c, [_order('Moed'), _order('Zeraim')]);
        expect(await repo.orderedLeafRefs(_c, content: content), [
          'Shabbat 1',
          'Shabbat 2',
          'Berakhot 1',
          'Berakhot 2',
          'Peah 1',
          'Peah 2',
        ]);
      });

      test('a masechta order sorts siblings within their seder', () async {
        final repo = buildRepo();
        await repo.saveMasechtosOrder(_c, [
          _order('Peah'),
          _order('Shabbat'),
          _order('Berakhot'),
        ]);
        expect(await repo.orderedLeafRefs(_c, content: content), [
          'Peah 1',
          'Peah 2',
          'Berakhot 1',
          'Berakhot 2',
          'Shabbat 1',
          'Shabbat 2',
        ]);
      });

      test('after reset it is empty again', () async {
        final repo = buildRepo();
        await repo.saveSedarimOrder(_c, [_order('Moed'), _order('Zeraim')]);
        await repo.resetToDefault(_c);
        expect(await repo.orderedLeafRefs(_c, content: content), isEmpty);
      });

      test('getOrderEntries skips ended and undecodable docs', () async {
        final repo = buildRepo();
        await repo.saveSedarimOrder(_c, [_order('Moed')]);
        await orders().doc('no_change_id').set({
          'curriculum_id': 'mishnayos',
          'level': seder,
          'ref': 'Zeraim',
          'user_sort_order': 1,
        });
        final entries = await repo.getOrderEntries(_c);
        expect(entries.map((e) => e.ref), ['Moed']);
      });
    },
  );
}
