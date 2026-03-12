import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';
import 'package:mocktail/mocktail.dart';

class MockContentRepository extends Mock implements ContentRepository {}

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

  late AppDatabase database;
  late MockContentRepository mockContent;
  late LearningOrderRepositoryImpl repo;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    mockContent = MockContentRepository();
    repo = LearningOrderRepositoryImpl(
      database: database,
      contentRepository: mockContent,
    );

    // Default stub for getHierarchyConfig
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

  group('LearningOrderRepositoryImpl', () {
    test(
      'getOrder returns items in sortOrder when no custom rows exist (D7 fallback)',
      () async {
        when(
          () => mockContent.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer(
          (_) async => [
            _makeItem('Shabbat', sortOrder: 2),
            _makeItem('Berakhot', sortOrder: 0),
            _makeItem('Peah', sortOrder: 1),
          ],
        );

        final items = await repo.getOrder(CurriculumId.mishnayos);

        expect(items.map((i) => i.sefariaRef).toList(), [
          'Berakhot',
          'Peah',
          'Shabbat',
        ]);
        expect(items.every((i) => !i.isCustomOrdered), isTrue);
      },
    );

    test(
      'getOrder returns custom order when DAO rows exist, overriding content order',
      () async {
        when(
          () => mockContent.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer(
          (_) async => [
            _makeItem('Berakhot', sortOrder: 0),
            _makeItem('Shabbat', sortOrder: 1),
          ],
        );

        // Custom order: Shabbat first
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

        final items = await repo.getOrder(CurriculumId.mishnayos);

        expect(items.map((i) => i.sefariaRef).toList(), [
          'Shabbat',
          'Berakhot',
        ]);
        expect(items.every((i) => i.isCustomOrdered), isTrue);
      },
    );

    test(
      'saveOrder writes correct userSortOrder (position index) for each item',
      () async {
        when(
          () => mockContent.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer((_) async => []);

        final itemsToSave = [
          const LearningOrderItem(
            sefariaRef: 'Shabbat',
            displayNameHe: 'שבת',
            displayNameEn: 'Shabbat',
            userSortOrder: 0,
          ),
          const LearningOrderItem(
            sefariaRef: 'Berakhot',
            displayNameHe: 'ברכות',
            displayNameEn: 'Berakhot',
            userSortOrder: 1,
          ),
        ];

        await repo.saveOrder(CurriculumId.mishnayos, itemsToSave);

        final rows = await database.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos');
        expect(rows.map((r) => r.sefariaRef).toList(), ['Shabbat', 'Berakhot']);
        expect(rows.map((r) => r.userSortOrder).toList(), [0, 1]);
      },
    );

    test(
      'resetToDefault deletes all rows; subsequent getOrder falls back to natural order',
      () async {
        when(
          () => mockContent.getContentForCurriculum(CurriculumId.mishnayos),
        ).thenAnswer(
          (_) async => [
            _makeItem('Berakhot', sortOrder: 0),
            _makeItem('Shabbat', sortOrder: 1),
          ],
        );

        // Add custom row
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
        expect(order.every((i) => !i.isCustomOrdered), isTrue);
        expect(order.map((i) => i.sefariaRef).toList(), [
          'Berakhot',
          'Shabbat',
        ]);
      },
    );
  });
}
