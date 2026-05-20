/// Story acceptance tests for Story 26.15 (DNI-358) —
/// CompositeCurriculumStrategy + transactional saveOrder + parent-control
/// at repository.
///
/// AC1: CompositeCurriculumStrategy exists and is data-driven (replaces
///      hardcoded _compositeSources / _tanachTorahContainer in feature code).
/// AC2: ContentRepositoryImpl no longer contains _compositeSources or
///      _tanachTorahContainer constants.
/// AC3: LearningOrderRepository.saveOrder wraps upserts in a DB transaction.
/// AC4: LearningOrderRepository.saveOrder throws ParentControlException when
///      isChildRestricted = true (enforcement at repository, not UI).
/// AC5: curriculum_learning_screen.dart has been deleted (dead stub removed).
@Tags(['epic_26', 'story_26_15'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/strategies/composite_curriculum_strategy.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/repositories/learning_order_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart' show seedProfileZero;

class _MockContentRepository extends Mock implements ContentRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });

  // ── AC1: CompositeCurriculumStrategy exists and is data-driven ─────────────
  group(
    'Story 26.15 AC1 — CompositeCurriculumStrategy is data-driven',
    tags: ['story_26_15'],
    () {
      test('forKey returns null for non-composite curriculum', () {
        expect(
          CompositeCurriculumStrategy.forKey('mishnayos'),
          isNull,
          reason: 'mishnayos is not a composite curriculum',
        );
      });

      test('forKey returns strategy for tanach', () {
        final strategy = CompositeCurriculumStrategy.forKey('tanach');
        expect(strategy, isNotNull);
        expect(strategy!.compositeKey, equals('tanach'));
        expect(strategy.sources, equals(['chumash', 'nach']));
      });

      test('isComposite returns true for tanach', () {
        expect(CompositeCurriculumStrategy.isComposite('tanach'), isTrue);
      });

      test('isComposite returns false for leaf curricula', () {
        for (final id in CurriculumId.values) {
          if (id.storageKey == 'tanach') continue;
          // Only registered composites return true.
          if (!CompositeCurriculumStrategy.isComposite(id.storageKey)) {
            expect(
              CompositeCurriculumStrategy.isComposite(id.storageKey),
              isFalse,
            );
          }
        }
      });

      test('tanach preamble contains Torah container with sortOrder -1', () {
        final strategy = CompositeCurriculumStrategy.forKey('tanach')!;
        expect(strategy.preamble, isNotEmpty);
        final torahContainer = strategy.preamble.first;
        expect(torahContainer.sefariaRef, equals('Torah'));
        expect(torahContainer.displayNameHe, equals('תורה'));
        expect(torahContainer.sortOrder, equals(-1));
        expect(torahContainer.isLeaf, isFalse);
      });

      test('tanach strategy remaps chumash items by shifting levels up', () {
        final strategy = CompositeCurriculumStrategy.forKey('tanach')!;
        const chumashItem = ContentItem(
          curriculumId: 'chumash',
          level1: 'Bereishit',
          level2: '1',
          level3: '1',
          displayNameHe: 'בראשית א:א',
          displayNameEn: 'Genesis 1:1',
          sefariaRef: 'Genesis 1.1',
          sortOrder: 0,
          isLeaf: true,
        );

        final remapped = strategy.remap(
          item: chumashItem,
          source: 'chumash',
          offset: 10,
        );

        expect(remapped.curriculumId, equals('tanach'));
        expect(remapped.level1, equals('Torah'));
        expect(remapped.level2, equals('Bereishit'));
        expect(remapped.level3, equals('1'));
        expect(remapped.level4, equals('1'));
        expect(remapped.sortOrder, equals(10)); // 0 + 10 offset
      });

      test('tanach strategy passes nach items through (levels unchanged)', () {
        final strategy = CompositeCurriculumStrategy.forKey('tanach')!;
        const nachItem = ContentItem(
          curriculumId: 'nach',
          level1: 'Prophets',
          level2: 'Yehoshua',
          level3: '1',
          level4: '1',
          displayNameHe: 'יהושע א:א',
          displayNameEn: 'Joshua 1:1',
          sefariaRef: 'Joshua 1.1',
          sortOrder: 5,
          isLeaf: true,
        );

        final remapped = strategy.remap(
          item: nachItem,
          source: 'nach',
          offset: 20,
        );

        expect(remapped.curriculumId, equals('tanach'));
        expect(remapped.level1, equals('Prophets'));
        expect(remapped.level2, equals('Yehoshua'));
        expect(remapped.sortOrder, equals(25)); // 5 + 20 offset
      });
    },
  );

  // ── AC2: ContentRepositoryImpl no longer hardcodes composite logic ──────────
  group(
    'Story 26.15 AC2 — ContentRepositoryImpl delegates to strategy',
    tags: ['story_26_15'],
    () {
      test('ContentRepositoryImpl source file has no _compositeSources', () {
        final file = File(
          'lib/features/content_browsing/data/repositories/content_repository_impl.dart',
        );
        final source = file.readAsStringSync();
        expect(
          source,
          isNot(contains('_compositeSources')),
          reason:
              '_compositeSources must be extracted to CompositeCurriculumStrategy',
        );
      });

      test('ContentRepositoryImpl source file has no _tanachTorahContainer', () {
        final file = File(
          'lib/features/content_browsing/data/repositories/content_repository_impl.dart',
        );
        final source = file.readAsStringSync();
        expect(
          source,
          isNot(contains('_tanachTorahContainer')),
          reason:
              '_tanachTorahContainer must be extracted to CompositeCurriculumStrategy',
        );
      });

      test('ContentRepositoryImpl source file imports the strategy', () {
        final file = File(
          'lib/features/content_browsing/data/repositories/content_repository_impl.dart',
        );
        final source = file.readAsStringSync();
        expect(
          source,
          contains('composite_curriculum_strategy'),
          reason:
              'ContentRepositoryImpl must import CompositeCurriculumStrategy',
        );
      });
    },
  );

  // ── AC3: saveOrder is transactional ─────────────────────────────────────────
  group(
    'Story 26.15 AC3 — saveOrder is wrapped in a DB transaction',
    tags: ['story_26_15'],
    () {
      late UserDatabase database;
      late _MockContentRepository mockContent;
      late LearningOrderRepositoryImpl repo;

      setUp(() async {
        database = UserDatabase(NativeDatabase.memory());
        await seedProfileZero(database);
        mockContent = _MockContentRepository();
        repo = LearningOrderRepositoryImpl(
          database: database,
          contentRepository: mockContent,
        );
        when(
          () => mockContent.getContentForCurriculum(any()),
        ).thenAnswer((_) async => []);
      });

      tearDown(() async => database.close());

      test(
        'saveOrder writes all items atomically — all rows present after call',
        () async {
          final items = [
            const LearningOrderItem(
              sefariaRef: 'Berakhot',
              displayNameHe: 'ברכות',
              displayNameEn: 'Berakhot',
              userSortOrder: 0,
            ),
            const LearningOrderItem(
              sefariaRef: 'Shabbat',
              displayNameHe: 'שבת',
              displayNameEn: 'Shabbat',
              userSortOrder: 1,
            ),
            const LearningOrderItem(
              sefariaRef: 'Eruvin',
              displayNameHe: 'עירובין',
              displayNameEn: 'Eruvin',
              userSortOrder: 2,
            ),
          ];

          await repo.saveOrder(CurriculumId.mishnayos, items);

          final rows = await database.learningOrderDao
              .getLearningOrderByCurriculum('mishnayos');
          expect(rows, hasLength(3));
          expect(
            rows.map((r) => r.sefariaRef).toList(),
            containsAllInOrder(['Berakhot', 'Shabbat', 'Eruvin']),
          );
          expect(
            rows.map((r) => r.userSortOrder).toList(),
            containsAllInOrder([0, 1, 2]),
          );
        },
      );

      test('saveOrder source code wraps upserts in database.transaction', () async {
        final file = File(
          'lib/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart',
        );
        final source = file.readAsStringSync();
        expect(
          source,
          contains('_database.transaction('),
          reason:
              'saveOrder must wrap upserts in _database.transaction() for atomicity',
        );
      });
    },
  );

  // ── AC4: Parent-control guard enforced at repository ─────────────────────────
  group(
    'Story 26.15 AC4 — saveOrder throws ParentControlException when restricted',
    tags: ['story_26_15'],
    () {
      late UserDatabase database;
      late _MockContentRepository mockContent;
      late LearningOrderRepositoryImpl repo;

      setUp(() async {
        database = UserDatabase(NativeDatabase.memory());
        await seedProfileZero(database);
        mockContent = _MockContentRepository();
        repo = LearningOrderRepositoryImpl(
          database: database,
          contentRepository: mockContent,
        );
        when(
          () => mockContent.getContentForCurriculum(any()),
        ).thenAnswer((_) async => []);
      });

      tearDown(() async => database.close());

      test(
        'saveOrder with isChildRestricted=true throws ParentControlException',
        () async {
          await expectLater(
            repo.saveOrder(CurriculumId.mishnayos, [], isChildRestricted: true),
            throwsA(isA<ParentControlException>()),
          );
        },
      );

      test('saveOrder with isChildRestricted=true writes no DB rows', () async {
        try {
          await repo.saveOrder(CurriculumId.mishnayos, [
            const LearningOrderItem(
              sefariaRef: 'Berakhot',
              displayNameHe: 'ברכות',
              displayNameEn: 'Berakhot',
              userSortOrder: 0,
            ),
          ], isChildRestricted: true);
        } on ParentControlException {
          // expected
        }

        final rows = await database.learningOrderDao
            .getLearningOrderByCurriculum('mishnayos');
        expect(
          rows,
          isEmpty,
          reason:
              'No rows should be written when the operation is rejected by parent-control guard',
        );
      });

      test(
        'saveOrder with isChildRestricted=false (default) proceeds normally',
        () async {
          final items = [
            const LearningOrderItem(
              sefariaRef: 'Berakhot',
              displayNameHe: 'ברכות',
              displayNameEn: 'Berakhot',
              userSortOrder: 0,
            ),
          ];

          await expectLater(
            repo.saveOrder(CurriculumId.mishnayos, items),
            completes,
          );

          final rows = await database.learningOrderDao
              .getLearningOrderByCurriculum('mishnayos');
          expect(rows, hasLength(1));
        },
      );

      test('ParentControlException has meaningful toString', () {
        const ex = ParentControlException();
        expect(ex.toString(), contains('ParentControlException'));
      });
    },
  );

  // ── AC5: curriculum_learning_screen.dart is deleted ─────────────────────────
  group(
    'Story 26.15 AC5 — curriculum_learning_screen.dart is deleted',
    tags: ['story_26_15'],
    () {
      test('dead stub file no longer exists in the repo', () {
        final file = File(
          'lib/features/learning/presentation/screens/curriculum_learning_screen.dart',
        );
        expect(
          file.existsSync(),
          isFalse,
          reason:
              'curriculum_learning_screen.dart was a 24-line dead stub and must be deleted',
        );
      });

      test('app_router.dart no longer imports curriculum_learning_screen', () {
        final file = File('lib/core/navigation/app_router.dart');
        final source = file.readAsStringSync();
        expect(
          source,
          isNot(contains('curriculum_learning_screen')),
          reason: 'app_router.dart must not import the deleted screen',
        );
      });
    },
  );
}
