/// Unit tests for [SchedulerFirestoreLearningOrderRepositoryAdapter]
/// (`lib/features/scheduler/data/repositories/
/// scheduler_learning_order_repository_impl.dart`) — the scheduler-side
/// Firestore reader wired into `schedulerEngineProvider`
/// (`scheduler_providers.dart:140`) in place of the Drift-backed
/// [SchedulerLearningOrderRepositoryImpl].
///
/// Mirrors `study_day_config_repository_impl_test.dart`'s
/// `FirestoreStudyDayConfigRepositoryAdapter` group structure (the
/// reference pattern established by `bookmark_repository_impl_test.dart`):
/// a "not ready" group (no active account/profile) and a "ready" group
/// (active account/profile, backed by `fake_cloud_firestore`).
///
/// The regression this guards against: the custom-order WRITER
/// (`learningOrderRepositoryProvider` → [FirestoreLearningOrderRepositoryAdapter])
/// moved to `users/{uid}/learner_profiles/{ULID}/learning_order`, while
/// this scheduler-side reader used to still read the now-frozen Drift
/// `learning_order` table — a reorder saved through the reorder screen
/// would never reach daily-task generation. The "writer/reader agreement"
/// test below constructs BOTH adapters — the actual production writer
/// class and the actual production scheduler-reader class — on the SAME
/// simulated account/profile (built via
/// `test/helpers/writer_reader_agreement.dart`'s [activateAccountAndProfile],
/// this file's worked example for Phase 1 step B2), and proves a save
/// through one is visible to the other via [expectWriterReaderAgree].
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

import '../../../../helpers/writer_reader_agreement.dart';
import 'not_ready_expectations.dart';

void main() {
  group('SchedulerFirestoreLearningOrderRepositoryAdapter', () {
    // Constructing the adapter requires a Ref (Riverpod's Ref is sealed —
    // it can only come from inside a provider callback), so tests obtain
    // one the same way production does: read a throwaway Provider that
    // builds the adapter from the container's ref. Mirrors
    // FirestoreStudyDayConfigRepositoryAdapter's test helper.
    SchedulerFirestoreLearningOrderRepositoryAdapter buildReader(
      ProviderContainer container,
    ) {
      final readerProvider =
          Provider<SchedulerFirestoreLearningOrderRepositoryAdapter>(
            (ref) => SchedulerFirestoreLearningOrderRepositoryAdapter(ref: ref),
          );
      return container.read(readerProvider);
    }

    // The actual production WRITER class — what `learningOrderRepositoryProvider`
    // (`learning_order_providers.dart`) resolves to. Constructed the same
    // way so the "writer/reader agreement" test exercises both real
    // production classes, not a hand-rolled stand-in for either side.
    FirestoreLearningOrderRepositoryAdapter buildWriter(
      ProviderContainer container,
    ) {
      final writerProvider = Provider<FirestoreLearningOrderRepositoryAdapter>(
        (ref) => FirestoreLearningOrderRepositoryAdapter(ref: ref),
      );
      return container.read(writerProvider);
    }

    group('not ready (no active account/profile)', () {
      late SchedulerFirestoreLearningOrderRepositoryAdapter notReadyReader;

      setUp(() {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        notReadyReader = buildReader(container);
      });

      test('getOrder returns an empty list instead of throwing — daily-task '
          'generation falls back to natural content order rather than '
          'crashing while the account/profile race is in flight', () async {
        await expectEmptyListWhenNotReady(
          () => notReadyReader.getOrder(CurriculumId.mishnayos),
          describe: 'SchedulerLearningOrderRepository.getOrder',
        );
      });
    });

    group('ready (active account + profile)', () {
      // Built via activateAccountAndProfile — the ONE seam-touching call
      // per test (`test/helpers/writer_reader_agreement.dart`), so the
      // writer and reader below are guaranteed to resolve the same
      // (uid, profileId, firestore) triple through Riverpod's per-container
      // memoization rather than two hand-rolled rigs that merely share
      // literal id strings.
      late FakeFirebaseFirestore firestore;
      late ProviderContainer container;
      late SchedulerFirestoreLearningOrderRepositoryAdapter reader;

      setUp(() {
        final rig = activateAccountAndProfile();
        firestore = rig.firestore;
        container = rig.container;
        reader = buildReader(container);
      });

      tearDown(() => container.dispose());

      test('getOrder returns [] when no custom order has ever been saved — '
          'proving this reads getCustomOrderRefs (raw rows), not the '
          'synthesizing getOrder, which would report a custom order for '
          'every profile', () async {
        final order = await reader.getOrder(CurriculumId.mishnayos);
        expect(order, isEmpty);
      });

      // The regression this fix closes: a custom order saved through
      // `learningOrderRepositoryProvider` (here, the actual
      // FirestoreLearningOrderRepositoryAdapter writer class) must be
      // visible to the scheduler's read path (here, the actual
      // SchedulerFirestoreLearningOrderRepositoryAdapter wired into
      // schedulerEngineProvider) — writer and reader agreeing on ONE
      // Firestore document tree. Run through expectWriterReaderAgree
      // (`test/helpers/writer_reader_agreement.dart`) as the worked example
      // for an already-migrated collection (Phase 1 step B2).
      test('writer/reader agreement: an order saved via '
          'learningOrderRepositoryProvider\'s adapter is visible to the '
          'scheduler\'s adapter, in the saved order', () async {
        await expectWriterReaderAgree<List<SchedulerOrderItem>>(
          firestore: firestore,
          collection: 'learning_order',
          writerDescription:
              'learningOrderRepositoryProvider\'s '
              'FirestoreLearningOrderRepositoryAdapter.saveOrder',
          readerDescription:
              'SchedulerFirestoreLearningOrderRepositoryAdapter.getOrder '
              '(schedulerEngineProvider\'s reader)',
          write: () async {
            final writer = buildWriter(container);
            await writer.saveOrder(CurriculumId.mishnayos, const [
              LearningOrderItem(
                sefariaRef: 'Shabbat',
                displayNameHe: 'שבת',
                displayNameEn: 'Shabbat',
                userSortOrder: 0,
              ),
              LearningOrderItem(
                sefariaRef: 'Berakhot',
                displayNameHe: 'ברכות',
                displayNameEn: 'Berakhot',
                userSortOrder: 1,
              ),
            ]);
          },
          read: () => reader.getOrder(CurriculumId.mishnayos),
          matches: equals(const [
            SchedulerOrderItem(sefariaRef: 'Shabbat', userSortOrder: 0),
            SchedulerOrderItem(sefariaRef: 'Berakhot', userSortOrder: 1),
          ]),
        );
      });
    });
  });
}
