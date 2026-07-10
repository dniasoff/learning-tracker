/// Story acceptance tests for Epic 5 -- Stages & Order.
@Tags(['epic_5'])
library;

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart' show seedProfile, seedProfileZero;

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

/// Creates a default curriculum track and returns its ID.
Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          stateChangedAt: DateTime.now(),
          activatedAt: DateTime.now(),
        ),
      );
  return row.id;
}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  // ── Story 5.1: Custom stage definitions ───────────────────────

  group('Story 5.1 -- Custom stage definitions', tags: ['story_5_1'], () {
    late UserDatabase database;
    late int trackId;
    late StageDefinitionRepositoryImpl repository;
    const curriculum = CurriculumId.mishnayos;

    setUp(() async {
      database = UserDatabase(NativeDatabase.memory());
      await seedProfile(database);
      trackId = await _insertTrack(database);
      repository = StageDefinitionRepositoryImpl(
        stageDao: database.stageDao,
        completionDao: database.completionDao,
        pushStageDefinitions:
            ({
              required int trackId,
              required String curriculumId,
              required List<Map<String, dynamic>> stages,
              required DateTime updatedAt,
            }) async {},
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('user can add a custom chazara stage', () async {
      await repository.initializeDefaults(
        curriculum,
        profileId: 1,
        trackId: trackId,
      );

      final newStage = await repository.addStage(
        curriculum,
        'Chazara 3',
        profileId: 1,
        trackId: trackId,
        schedule: const DelaySchedule(30),
      );

      expect(newStage.stageName, 'Chazara 3');
      expect(newStage.delayDays, 30);
      expect(newStage.isDefault, false);
      expect(newStage.stageOrder, 4);

      final all = await repository.getStagesForCurriculum(curriculum);
      expect(all, hasLength(4));
    });

    test('user can reorder stages (Learn must stay at position 1)', () async {
      await repository.initializeDefaults(
        curriculum,
        profileId: 1,
        trackId: trackId,
      );
      final stages = await repository.getStagesForCurriculum(curriculum);
      // Learn must remain first; swap Chazara 1 and Chazara 2 only.
      final learnId = stages[0].id; // stageOrder == 1
      final chazara1Id = stages[1].id; // stageOrder == 2
      final chazara2Id = stages[2].id; // stageOrder == 3

      await repository.reorderStages(curriculum, [
        learnId,
        chazara2Id,
        chazara1Id,
      ]);

      final reordered = await repository.getStagesForCurriculum(curriculum);
      expect(reordered[0].stageOrder, 1);
      expect(reordered[0].stageName, 'לימוד'); // Learn stays at 1
      expect(reordered[1].stageName, 'חזרה ב׳'); // Chazara 2 moved to 2
      expect(reordered[2].stageName, 'חזרה א׳'); // Chazara 1 moved to 3
    });

    test('user can adjust delay days for a stage', () async {
      await repository.initializeDefaults(
        curriculum,
        profileId: 1,
        trackId: trackId,
      );
      final stages = await repository.getStagesForCurriculum(curriculum);
      final chazara1 = stages.firstWhere((s) => s.stageName == 'חזרה א׳');

      await repository.updateStage(chazara1.id, delayDays: 3);

      final updated = await repository.getStagesForCurriculum(curriculum);
      final updatedStage = updated.firstWhere((s) => s.id == chazara1.id);
      expect(updatedStage.delayDays, 3);
    });
  });

  // ── Story 5.2: Custom learning order ──────────────────────────

  group('Story 5.2 -- Custom learning order', () {
    late UserDatabase database;
    late _MockContentRepository mockContent;
    late LearningOrderRepositoryImpl repo;

    setUp(() async {
      database = UserDatabase(NativeDatabase.memory());
      await seedProfile(database);
      await seedProfileZero(database);
      await _insertTrack(database);
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
        when(
          () => mockContent.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer(
          (_) async => [
            _makeItem('Berakhot', sortOrder: 0),
            _makeItem('Shabbat', sortOrder: 1),
          ],
        );

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
