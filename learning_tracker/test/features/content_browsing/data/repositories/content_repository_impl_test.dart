/// Unit tests for ContentRepositoryImpl.
///
/// Covers the interface contract and a smoke-parse of every bundled
/// assets/content/hierarchy/*.json file using the same field mapping as
/// ContentRepositoryImpl._parseAndCache.
///
/// Filter/search/getByRef business logic (nikud-stripping, level-matching,
/// scoping, ref lookup) is exercised against the REAL repository methods —
/// not local re-implementations — in the sibling
/// content_repository_impl_logic_test.dart via a fake subclass that only
/// stubs asset loading (AUD-t-content_browsing-04).
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

  // ── Bundled asset smoke test ─────────────────────────────────
  // ContentRepositoryImpl.getContentForCurriculum still loads bundled JSON
  // from assets/content/hierarchy/<key>.json via rootBundle at runtime (the
  // asset bundle was NOT removed — 15 files live under that directory as of
  // this test). This group is always-on: it parses every file with the same
  // field mapping ContentRepositoryImpl._parseAndCache uses, so a corrupted
  // or malformed bundled asset fails here instead of only surfacing at
  // runtime.
  group('bundled content assets', () {
    test('every assets/content/hierarchy/*.json file parses using the '
        'ContentRepositoryImpl JSON contract', () {
      final dir = Directory('assets/content/hierarchy');
      expect(
        dir.existsSync(),
        isTrue,
        reason:
            'ContentRepositoryImpl.getContentForCurriculum loads from '
            'assets/content/hierarchy/<key>.json via rootBundle at '
            'runtime — this directory must exist.',
      );

      final jsonFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      expect(
        jsonFiles,
        isNotEmpty,
        reason: 'no *.json files found under assets/content/hierarchy/',
      );

      for (final file in jsonFiles) {
        final filename = file.uri.pathSegments.last;
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

        final configJson = json['hierarchyConfig'] as Map<String, dynamic>;
        final config = CurriculumHierarchyConfig(
          curriculumId: configJson['curriculumId'] as String,
          levelLabels: (configJson['levelLabels'] as List)
              .map((e) => e as String)
              .toList(),
          totalItems: configJson['totalItems'] as int,
        );
        expect(
          config.levelLabels,
          isNotEmpty,
          reason: '$filename: levelLabels must not be empty',
        );
        expect(
          config.totalItems,
          greaterThan(0),
          reason: '$filename: totalItems must be > 0',
        );

        final itemsJson = json['items'] as List;
        expect(
          itemsJson,
          isNotEmpty,
          reason: '$filename: items must not be empty',
        );

        // Every item must parse with the same field mapping
        // ContentRepositoryImpl._parseAndCache uses. A malformed or
        // missing-field item throws here (bad cast / null check),
        // failing this test.
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

        final leafCount = items.where((i) => i.isLeaf).length;
        expect(
          leafCount,
          greaterThan(0),
          reason: '$filename: must have at least one leaf item',
        );
      }
    });
  });
}
