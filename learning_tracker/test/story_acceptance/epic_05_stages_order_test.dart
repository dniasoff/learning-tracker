/// Story acceptance tests for Epic 5 -- Stages & Order.
@Tags(['epic_5'])
library;

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart'
    show seedProfile, seedProfileZero, seedTrack;

ContentItem _makeItem(String ref, {int sortOrder = 0}) {
  return ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Zeraim',
    level2: ref,
    displayNameHe: '$ref-he',
    displayNameEn: '$ref-en',
    sefariaRef: ref,
    sortOrder: sortOrder,
    isLeaf: false,
  );
}

void main() {
  // ── Story 5.1: Custom stage definitions ───────────────────────
  //
  // AUD-tracks-12: the "Story 5.1 -- Custom stage definitions" group that
  // used to live here (add/reorder/adjust-delay against
  // StageDefinitionRepository directly) exercised StageEditorNotifier's
  // repository mutation path. That path has zero UI callers today — Epic
  // 15 AC5 ("StageEditorScreen removed") replaced the manual stage editor
  // with the chazara wizard's LearningProcessWizardService.applyWizardResult
  // (see curriculum_settings_screen.dart), and this acceptance group was
  // never updated to match, leaving it as the sole remaining caller of the
  // now-deleted addStage/updateStage/reorderStages repository methods. It
  // is removed rather than rewritten because there is no live UI flow left
  // for it to describe; the wizard flow it was superseded by is covered by
  // Epic 15's acceptance tests (test/story_acceptance/epic_15_multi_profile_test.dart).

  // ── Story 5.2: Custom learning order ──────────────────────────

  group('Story 5.2 -- Custom learning order', tags: ['story_5_2'], () {
    late UserDatabase database;
    late LearningOrderRepositoryImpl repo;

    setUp(() async {
      database = UserDatabase(NativeDatabase.memory());
      await seedProfile(database);
      await seedProfileZero(database);
      await seedTrack(database, profileId: 1);
      repo = LearningOrderRepositoryImpl(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'LearningOrderRepository.getOrder returns content sort_order when no rows (D7 fallback)',
      () async {
        final items = [
          _makeItem('Berakhot', sortOrder: 0),
          _makeItem('Shabbat', sortOrder: 1),
        ];

        final order = await repo.getOrder(CurriculumId.mishnayos, items);

        expect(order.map((i) => i.sefariaRef).toList(), [
          'Berakhot',
          'Shabbat',
        ]);
        expect(order.every((i) => !i.isCustomOrdered), isTrue);
      },
    );

    test(
      'LearningOrderRepository.saveOrder writes correct rows to learning_order table',
      () async {
        const items = [
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
        ];

        await repo.saveOrder(CurriculumId.mishnayos, items);

        final rows = await database.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos', profileId: 0);
        expect(rows, hasLength(2));
        expect(rows[0].sefariaRef, 'Shabbat');
        expect(rows[0].userSortOrder, 0);
        expect(rows[1].sefariaRef, 'Berakhot');
        expect(rows[1].userSortOrder, 1);
      },
    );

    test(
      'LearningOrderRepository.getOrder returns custom order when rows exist',
      () async {
        final items = [
          _makeItem('Berakhot', sortOrder: 0),
          _makeItem('Shabbat', sortOrder: 1),
        ];

        // `repo` defaults to profileId 0 — fixtures must be seeded under the
        // same profile the repository-under-test reads from
        // (AUD-core-database-02: these rows used to be seeded under
        // profileId 1 and only "worked" because the DAO ignored profileId).
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 0,
            curriculumId: 'mishnayos',
            sefariaRef: 'Shabbat',
            userSortOrder: 0,
          ),
        );
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 0,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot',
            userSortOrder: 1,
          ),
        );

        final order = await repo.getOrder(CurriculumId.mishnayos, items);

        expect(order.map((i) => i.sefariaRef).toList(), [
          'Shabbat',
          'Berakhot',
        ]);
        expect(order.every((i) => i.isCustomOrdered), isTrue);
      },
    );

    test(
      'LearningOrderRepository.resetToDefault deletes all rows; getOrder falls back to natural order',
      () async {
        final items = [
          _makeItem('Berakhot', sortOrder: 0),
          _makeItem('Shabbat', sortOrder: 1),
        ];

        // `repo` defaults to profileId 0 — see note above.
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 0,
            curriculumId: 'mishnayos',
            sefariaRef: 'Shabbat',
            userSortOrder: 0,
          ),
        );

        await repo.resetToDefault(CurriculumId.mishnayos);

        final rows = await database.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos', profileId: 0);
        expect(rows, isEmpty);

        final order = await repo.getOrder(CurriculumId.mishnayos, items);
        expect(order.map((i) => i.sefariaRef).toList(), [
          'Berakhot',
          'Shabbat',
        ]);
      },
    );

    test('user can reorder content items within a curriculum', () async {
      final items = [
        _makeItem('Berakhot', sortOrder: 0),
        _makeItem('Peah', sortOrder: 1),
        _makeItem('Shabbat', sortOrder: 2),
      ];

      // Move Shabbat to first
      const reordered = [
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
        LearningOrderItem(
          sefariaRef: 'Peah',
          displayNameHe: 'פאה',
          displayNameEn: 'Peah',
          userSortOrder: 2,
        ),
      ];

      await repo.saveOrder(CurriculumId.mishnayos, reordered);

      final order = await repo.getOrder(CurriculumId.mishnayos, items);
      expect(order.map((i) => i.sefariaRef).toList(), [
        'Shabbat',
        'Berakhot',
        'Peah',
      ]);
    });

    test(
      'custom order persists (DAO returns correct rows after write)',
      () async {
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Shabbat',
            userSortOrder: 0,
          ),
        );
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot',
            userSortOrder: 1,
          ),
        );

        final rows = await database.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos', profileId: 1);
        expect(rows, hasLength(2));
        expect(rows[0].sefariaRef, 'Shabbat');
        expect(rows[1].sefariaRef, 'Berakhot');
      },
    );
  });
}
