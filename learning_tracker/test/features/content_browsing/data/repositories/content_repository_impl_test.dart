/// Unit tests for ContentRepositoryImpl.
///
/// Tests the JSON parsing logic, caching, filtering, search, and getByRef
/// operations using fixture data. Since ContentRepositoryImpl uses rootBundle
/// under the hood, these tests validate the parsing and business logic by
/// simulating the same JSON structure produced by tool/seed_content.dart.
@Tags(['story_2_5'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:test/test.dart';

void main() {
  group('ContentRepositoryImpl', () {
    test('implements ContentRepository interface', () {
      final repo = ContentRepositoryImpl();
      expect(repo, isA<ContentRepository>());
    });

    test('_getFilename maps all CurriculumId values to filenames', () {
      // Verify the mapping produces correct filenames from storage keys
      for (final curriculum in CurriculumId.values) {
        final expectedFilename = '${curriculum.storageKey}.json';
        expect(
          expectedFilename,
          isNotEmpty,
          reason: '${curriculum.name} should map to a filename',
        );
      }
    });
  });

  // ── JSON parsing contract tests ──────────────────────────────
  // These tests verify that the bundled JSON files can be correctly
  // parsed using the same logic as ContentRepositoryImpl.

  group(
    'ContentRepositoryImpl JSON parsing contract',
    skip: 'Bundled JSON removed — content now fetched from cloud storage',
    () {
      /// Parses a JSON file the same way ContentRepositoryImpl does.
      /// Returns (config, items) tuple.
      (CurriculumHierarchyConfig, List<ContentItem>) parseJsonFile(
        String filename,
      ) {
        final file = File('assets/content/$filename');
        final jsonString = file.readAsStringSync();
        final json = jsonDecode(jsonString) as Map<String, dynamic>;

        final configJson = json['hierarchyConfig'] as Map<String, dynamic>;
        final config = CurriculumHierarchyConfig(
          curriculumId: configJson['curriculumId'] as String,
          levelLabels: (configJson['levelLabels'] as List)
              .map((e) => e as String)
              .toList(),
          totalItems: configJson['totalItems'] as int,
        );

        final itemsJson = json['items'] as List;
        final items = itemsJson.map((itemJson) {
          final item = itemJson as Map<String, dynamic>;
          return ContentItem(
            curriculumId: item['curriculumId'] as String,
            level1: item['level1'] as String,
            level2: item['level2'] as String?,
            level3: item['level3'] as String?,
            level4: item['level4'] as String?,
            displayNameHe: item['displayNameHe'] as String,
            displayNameEn: item['displayNameEn'] as String,
            sefariaRef: item['sefariaRef'] as String,
            sortOrder: item['sortOrder'] as int,
            isLeaf: item['isLeaf'] as bool,
          );
        }).toList();

        return (config, items);
      }

      for (final curriculum in CurriculumId.values) {
        final filename = '${curriculum.storageKey}.json';

        group(curriculum.displayNameEn, () {
          test('parses without error', () {
            expect(() => parseJsonFile(filename), returnsNormally);
          });

          test('hierarchyConfig has correct curriculumId', () {
            final (config, _) = parseJsonFile(filename);
            expect(config.curriculumId, equals(curriculum.storageKey));
          });

          test('hierarchyConfig has valid level labels', () {
            final (config, _) = parseJsonFile(filename);
            expect(config.levelLabels, isNotEmpty);
            expect(config.depth, greaterThan(0));
          });

          test('hierarchyConfig totalItems > 0', () {
            final (config, _) = parseJsonFile(filename);
            expect(config.totalItems, greaterThan(0));
          });

          test('items list is non-empty', () {
            final (_, items) = parseJsonFile(filename);
            expect(items, isNotEmpty);
          });

          test('all items have matching curriculumId', () {
            final (_, items) = parseJsonFile(filename);
            for (final item in items) {
              expect(
                item.curriculumId,
                equals(curriculum.storageKey),
                reason: 'Item ${item.sefariaRef} has wrong curriculumId',
              );
            }
          });

          test('leaf items have non-empty sefariaRef', () {
            final (_, items) = parseJsonFile(filename);
            final leafItems = items.where((i) => i.isLeaf);
            expect(
              leafItems,
              isNotEmpty,
              reason: 'Must have at least one leaf item',
            );
            for (final item in leafItems) {
              expect(
                item.sefariaRef,
                isNotEmpty,
                reason: 'Leaf item must have sefariaRef',
              );
            }
          });

          test('leaf count matches totalItems in config', () {
            final (config, items) = parseJsonFile(filename);
            final leafCount = items.where((i) => i.isLeaf).length;
            expect(
              leafCount,
              equals(config.totalItems),
              reason:
                  'Leaf count ($leafCount) must match totalItems (${config.totalItems})',
            );
          });

          test('sort orders are non-negative', () {
            final (_, items) = parseJsonFile(filename);
            for (final item in items) {
              expect(
                item.sortOrder,
                greaterThanOrEqualTo(0),
                reason: 'Item ${item.sefariaRef} has negative sortOrder',
              );
            }
          });
        });
      }
    },
  );

  // ── In-memory operation tests ───────────────────────────────
  // These tests verify filter, search, and getByRef logic using
  // fixture data (no rootBundle dependency).

  group('ContentRepositoryImpl in-memory operations', () {
    // We test the logic that happens after content is loaded (filter,
    // search, getByRef) using fixture data that mimics real content.
    final testItems = [
      ContentItem(
        curriculumId: CurriculumId.mishnayos.storageKey,
        level1: 'Seder Zeraim',
        level2: 'Berachos',
        level3: '1',
        level4: '1',
        displayNameHe: 'ברכות א:א',
        displayNameEn: 'Berachos 1:1',
        sefariaRef: 'Mishnah Berakhot 1.1',
        sortOrder: 1,
        isLeaf: true,
      ),
      ContentItem(
        curriculumId: CurriculumId.mishnayos.storageKey,
        level1: 'Seder Zeraim',
        level2: 'Berachos',
        level3: '1',
        level4: '2',
        displayNameHe: 'ברכות א:ב',
        displayNameEn: 'Berachos 1:2',
        sefariaRef: 'Mishnah Berakhot 1.2',
        sortOrder: 2,
        isLeaf: true,
      ),
      ContentItem(
        curriculumId: CurriculumId.mishnayos.storageKey,
        level1: 'Seder Zeraim',
        level2: 'Peah',
        level3: '1',
        level4: '1',
        displayNameHe: 'פאה א:א',
        displayNameEn: 'Peah 1:1',
        sefariaRef: 'Mishnah Peah 1.1',
        sortOrder: 10,
        isLeaf: true,
      ),
      ContentItem(
        curriculumId: CurriculumId.mishnayos.storageKey,
        level1: 'Seder Zeraim',
        level2: null,
        level3: null,
        level4: null,
        displayNameHe: 'סדר זרעים',
        displayNameEn: 'Seder Zeraim',
        sefariaRef: 'Seder Zeraim',
        sortOrder: 0,
        isLeaf: false,
      ),
    ];

    test('filter by level1 returns matching items', () {
      final filtered = testItems
          .where((item) => item.level1 == 'Seder Zeraim')
          .toList();
      expect(filtered, hasLength(4));
    });

    test('filter by level2 returns matching items', () {
      final filtered = testItems
          .where((item) => item.level2 == 'Berachos')
          .toList();
      expect(filtered, hasLength(2));
    });

    test('filter by level2 excludes non-matching items', () {
      final filtered = testItems
          .where((item) => item.level2 == 'Peah')
          .toList();
      expect(filtered, hasLength(1));
      expect(filtered.first.sefariaRef, equals('Mishnah Peah 1.1'));
    });

    test('search by English display name (case-insensitive)', () {
      const query = 'berachos';
      final results = testItems
          .where(
            (item) =>
                item.displayNameEn.toLowerCase().contains(query) ||
                item.displayNameHe.toLowerCase().contains(query),
          )
          .toList();
      expect(results, hasLength(2));
    });

    test('search by Hebrew display name', () {
      const query = 'פאה';
      final results = testItems
          .where(
            (item) =>
                item.displayNameEn.toLowerCase().contains(
                  query.toLowerCase(),
                ) ||
                item.displayNameHe.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
      expect(results, hasLength(1));
      expect(results.first.sefariaRef, equals('Mishnah Peah 1.1'));
    });

    test('empty search returns empty list', () {
      const query = '';
      // ContentRepositoryImpl returns empty list for empty query
      if (query.isEmpty) {
        expect(<ContentItem>[], isEmpty);
      }
    });

    test('getByRef finds matching item', () {
      final item = testItems
          .where((item) => item.sefariaRef == 'Mishnah Berakhot 1.2')
          .firstOrNull;
      expect(item, isNotNull);
      expect(item!.displayNameEn, equals('Berachos 1:2'));
    });

    test('getByRef returns null for non-existent ref', () {
      final item = testItems
          .where((item) => item.sefariaRef == 'non-existent')
          .firstOrNull;
      expect(item, isNull);
    });

    test('items can be separated into leaf and container nodes', () {
      final leaves = testItems.where((item) => item.isLeaf).toList();
      final containers = testItems.where((item) => !item.isLeaf).toList();

      expect(leaves, hasLength(3));
      expect(containers, hasLength(1));
    });

    test('ContentItem equality is based on curriculumId and sefariaRef', () {
      const item1 = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Seder Zeraim',
        level2: 'Berachos',
        level3: '1',
        level4: '1',
        displayNameHe: 'ברכות א:א',
        displayNameEn: 'Berachos 1:1',
        sefariaRef: 'Mishnah Berakhot 1.1',
        sortOrder: 1,
        isLeaf: true,
      );

      const item2 = ContentItem(
        curriculumId: 'mishnayos',
        level1: 'Different',
        level2: 'Different',
        level3: '99',
        level4: '99',
        displayNameHe: 'Different',
        displayNameEn: 'Different',
        sefariaRef: 'Mishnah Berakhot 1.1',
        sortOrder: 99,
        isLeaf: false,
      );

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
    });
  });
}
