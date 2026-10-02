/// Unit tests for [SchedulerTrackOrderRepositoryAdapter]
/// (`lib/features/scheduler/data/repositories/
/// scheduler_learning_order_repository_impl.dart`) — the scheduler's
/// main-track order reader wired into `schedulerEngineProvider` (DNI-476
/// AC-2): the AD-33 `orderedLeaves` of the curriculum's corpus and its
/// live `track_learning_order` docs; the retired `learning_order`
/// collection is no longer read.
///
/// The "writer/reader agreement" test saves a reorder through the actual
/// production writer (the track order screen's
/// `FirestoreTrackLearningOrderRepositoryAdapter`, a governed write) and
/// proves the scheduler's reader sees it, both resolved off ONE
/// [activateAccountAndProfile] rig.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/data/repositories/track_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

import '../../../../helpers/writer_reader_agreement.dart';
import 'not_ready_expectations.dart';

ContentItem _item(
  String ref,
  int sortOrder,
  List<String> path, {
  bool isLeaf = false,
}) => ContentItem(
  curriculumId: CurriculumId.mishnayos.storageKey,
  level1: path[0],
  level2: path.length > 1 ? path[1] : null,
  level3: path.length > 2 ? path[2] : null,
  displayNameHe: ref,
  displayNameEn: ref,
  sefariaRef: ref,
  sortOrder: sortOrder,
  isLeaf: isLeaf,
);

final _items = [
  _item('Zeraim', 0, ['Zeraim']),
  _item('Berakhot', 1, ['Zeraim', 'Berakhot']),
  _item('Berakhot 1', 2, ['Zeraim', 'Berakhot', '1'], isLeaf: true),
  _item('Moed', 3, ['Moed']),
  _item('Shabbat', 4, ['Moed', 'Shabbat']),
  _item('Shabbat 1', 5, ['Moed', 'Shabbat', '1'], isLeaf: true),
];

void main() {
  group('SchedulerTrackOrderRepositoryAdapter', () {
    SchedulerTrackOrderRepositoryAdapter buildReader(
      ProviderContainer container,
    ) {
      final readerProvider = Provider<SchedulerTrackOrderRepositoryAdapter>(
        (ref) => SchedulerTrackOrderRepositoryAdapter(
          ref: ref,
          content: (_) async => _items,
        ),
      );
      return container.read(readerProvider);
    }

    FirestoreTrackLearningOrderRepositoryAdapter buildWriter(
      ProviderContainer container,
    ) {
      final writerProvider =
          Provider<FirestoreTrackLearningOrderRepositoryAdapter>(
            (ref) => FirestoreTrackLearningOrderRepositoryAdapter(ref: ref),
          );
      return container.read(writerProvider);
    }

    group('not ready (no active account/profile)', () {
      late SchedulerTrackOrderRepositoryAdapter notReadyReader;

      setUp(() {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        notReadyReader = buildReader(container);
      });

      test('getOrder returns an empty list instead of throwing — daily-task '
          'generation falls back to natural content order', () async {
        await expectEmptyListWhenNotReady(
          () => notReadyReader.getOrder(CurriculumId.mishnayos),
          describe: 'SchedulerLearningOrderRepository.getOrder',
        );
      });
    });

    group('ready (active account + profile)', () {
      late FakeFirebaseFirestore firestore;
      late ProviderContainer container;
      late SchedulerTrackOrderRepositoryAdapter reader;

      setUp(() {
        final rig = activateAccountAndProfile();
        firestore = rig.firestore;
        container = rig.container;
        reader = buildReader(container);
      });

      tearDown(() => container.dispose());

      test('getOrder returns [] when no live order doc exists', () async {
        expect(await reader.getOrder(CurriculumId.mishnayos), isEmpty);
      });

      test('writer/reader agreement: a sedarim reorder saved by the order '
          "screen's adapter is the scheduler's orderedLeaves order", () async {
        await expectWriterReaderAgree<List<SchedulerOrderItem>>(
          firestore: firestore,
          collection: 'track_learning_order',
          writerDescription:
              'FirestoreTrackLearningOrderRepositoryAdapter.saveSedarimOrder '
              '(a governed mainTrackOrder change)',
          readerDescription:
              'SchedulerTrackOrderRepositoryAdapter.getOrder '
              "(schedulerEngineProvider's reader)",
          write: () => buildWriter(container)
              .saveSedarimOrder(CurriculumId.mishnayos, const [
                LearningOrderItem(
                  sefariaRef: 'Moed',
                  displayNameHe: 'Moed',
                  displayNameEn: 'Moed',
                  userSortOrder: 0,
                ),
                LearningOrderItem(
                  sefariaRef: 'Zeraim',
                  displayNameHe: 'Zeraim',
                  displayNameEn: 'Zeraim',
                  userSortOrder: 1,
                ),
              ]),
          read: () => reader.getOrder(CurriculumId.mishnayos),
          matches: equals(const [
            SchedulerOrderItem(sefariaRef: 'Shabbat 1', userSortOrder: 0),
            SchedulerOrderItem(sefariaRef: 'Berakhot 1', userSortOrder: 1),
          ]),
        );
      });

      test('after reset to default the order is natural again', () async {
        final writer = buildWriter(container);
        await writer.saveSedarimOrder(CurriculumId.mishnayos, const [
          LearningOrderItem(
            sefariaRef: 'Moed',
            displayNameHe: 'Moed',
            displayNameEn: 'Moed',
            userSortOrder: 0,
          ),
        ]);
        await writer.resetToDefault(CurriculumId.mishnayos);
        expect(await reader.getOrder(CurriculumId.mishnayos), isEmpty);
      });
    });
  });
}
