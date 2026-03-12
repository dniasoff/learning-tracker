/// Story acceptance tests for Epic 5 -- Stages & Order.
@Tags(['epic_5'])
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockContentRepository extends Mock implements ContentRepository {}

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
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  // ── Story 5.1: Custom stage definitions ───────────────────────

  group('Story 5.1 -- Custom stage definitions', tags: ['story_5_1'], () {
    late AppDatabase database;
    late StageDefinitionRepositoryImpl repository;
    const curriculum = CurriculumId.mishnayos;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = StageDefinitionRepositoryImpl(
        stageDao: database.stageDao,
        completionDao: database.completionDao,
        pushSettings: (_) async {},
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('user can add a custom chazara stage', () async {
      await repository.initializeDefaults(curriculum);

      final newStage = await repository.addStage(curriculum, 'Chazara 3', 30);

      expect(newStage.stageName, 'Chazara 3');
      expect(newStage.delayDays, 30);
      expect(newStage.isDefault, false);
      expect(newStage.stageOrder, 4);

      final all = await repository.getStagesForCurriculum(curriculum);
      expect(all, hasLength(4));
    });

    test('user can reorder stages', () async {
      await repository.initializeDefaults(curriculum);
      final stages = await repository.getStagesForCurriculum(curriculum);
      // Reverse order: [3, 2, 1]
      final reversed = stages.reversed.map((s) => s.id).toList();

      await repository.reorderStages(curriculum, reversed);

      final reordered = await repository.getStagesForCurriculum(curriculum);
      expect(reordered[0].stageOrder, 1);
      expect(reordered[0].stageName, 'Chazara 2');
      expect(reordered[2].stageName, 'Learn');
    });

    test('user can adjust delay days for a stage', () async {
      await repository.initializeDefaults(curriculum);
      final stages = await repository.getStagesForCurriculum(curriculum);
      final chazara1 = stages.firstWhere((s) => s.stageName == 'Chazara 1');

      await repository.updateStage(chazara1.id, delayDays: 3);

      final updated = await repository.getStagesForCurriculum(curriculum);
      final updatedStage = updated.firstWhere((s) => s.id == chazara1.id);
      expect(updatedStage.delayDays, 3);
    });
  });

  // ── Story 5.2: Custom learning order ──────────────────────────

  group('Story 5.2 -- Custom learning order', () {
    late AppDatabase database;
    late _MockContentRepository mockContent;
    late LearningOrderRepositoryImpl repo;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      mockContent = _MockContentRepository();
      repo = LearningOrderRepositoryImpl(
        database: database,
        contentRepository: mockContent,
      );
      when(() => mockContent.getHierarchyConfig(any())).thenAnswer(
        (_) async => const CurriculumHierarchyConfig(
          curriculumId: 'mishnayos',
          levelLabels: ['Seder', 'Masechta', 'Perek', 'Mishna'],
          totalItems: 10,
        ),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'LearningOrderRepository.getOrder returns content sort_order when no rows (D7 fallback)',
      () async {
        when(
          () => mockContent.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer(
          (_) async => [
            _makeItem('Berakhot', sortOrder: 0),
            _makeItem('Shabbat', sortOrder: 1),
          ],
        );

        final order = await repo.getOrder(CurriculumId.mishnayos);

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
        when(
          () => mockContent.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer((_) async => []);

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
            .getLearningOrderByCurriculum('mishnayos');
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
        when(
          () => mockContent.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer(
          (_) async => [
            _makeItem('Berakhot', sortOrder: 0),
            _makeItem('Shabbat', sortOrder: 1),
          ],
        );

        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'Shabbat',
            userSortOrder: 0,
          ),
        );
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot',
            userSortOrder: 1,
          ),
        );

        final order = await repo.getOrder(CurriculumId.mishnayos);

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
        when(
          () => mockContent.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer(
          (_) async => [
            _makeItem('Berakhot', sortOrder: 0),
            _makeItem('Shabbat', sortOrder: 1),
          ],
        );

        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'Shabbat',
            userSortOrder: 0,
          ),
        );

        await repo.resetToDefault(CurriculumId.mishnayos);

        final rows = await database.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos');
        expect(rows, isEmpty);

        final order = await repo.getOrder(CurriculumId.mishnayos);
        expect(order.map((i) => i.sefariaRef).toList(), [
          'Berakhot',
          'Shabbat',
        ]);
      },
    );

    test('user can reorder content items within a curriculum', () async {
      when(
        () => mockContent.getContentForCurriculum(CurriculumId.mishnayos),
      ).thenAnswer(
        (_) async => [
          _makeItem('Berakhot', sortOrder: 0),
          _makeItem('Peah', sortOrder: 1),
          _makeItem('Shabbat', sortOrder: 2),
        ],
      );

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

      final order = await repo.getOrder(CurriculumId.mishnayos);
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
            curriculumId: 'mishnayos',
            sefariaRef: 'Shabbat',
            userSortOrder: 0,
          ),
        );
        await database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'Berakhot',
            userSortOrder: 1,
          ),
        );

        final rows = await database.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos');
        expect(rows, hasLength(2));
        expect(rows[0].sefariaRef, 'Shabbat');
        expect(rows[1].sefariaRef, 'Berakhot');
      },
    );
  });
}
