import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';
import 'package:learning_tracker/features/content_browsing/domain/profile_visible_content_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';

class _DiskContentRepository extends ContentRepositoryImpl {
  @override
  Future<String> loadRawContentJson(String key) =>
      File('assets/content/hierarchy/$key.json').readAsString();
}

class _RawRepository implements ContentRepository {
  final items = [
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      level2: 'Berakhot',
      displayNameHe: 'ברכות',
      displayNameEn: 'Berakhot',
      sefariaRef: 'Berakhot',
      sortOrder: 0,
      isLeaf: false,
    ),
    const ContentItem(
      curriculumId: 'mishnayos',
      level1: 'Zeraim',
      level2: 'Berakhot',
      displayNameHe: 'ברכות א:א',
      displayNameEn: 'Berakhot 1:1',
      sefariaRef: 'Berakhot 1:1',
      sortOrder: 1,
      isLeaf: true,
    ),
  ];

  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId id) async =>
      items;

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(CurriculumId id) async =>
      CurriculumHierarchyConfig(
        curriculumId: id.storageKey,
        levelLabels: const ['Seder', 'Masechta'],
        totalItems: 1,
      );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => items;

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => items;

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => items;

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => items.where((item) => item.sefariaRef == sefariaRef).firstOrNull;
}

void main() {
  test('filters the raw repository by the profile hidden refs', () async {
    final repository = ProfileVisibleContentRepository(_RawRepository(), {
      'Berakhot',
    });

    final visible = await repository.getContentForCurriculum(
      CurriculumId.mishnayos,
    );

    expect(visible, isEmpty);
  });

  test('updates hierarchy leaf count after filtering', () async {
    final repository = ProfileVisibleContentRepository(_RawRepository(), {});

    final config = await repository.getHierarchyConfig(CurriculumId.mishnayos);

    expect(config.totalItems, 1);
  });

  test(
    'bounded lifetime leaves filter hidden containers and hidden leaves',
    () async {
      final hiddenMasechta = ProfileVisibleContentRepository(
        _DiskContentRepository(),
        {'Mishnah Niddah'},
      );

      final containerHidden = await hiddenMasechta.loadLeavesTransient(
        CurriculumId.mishnayos,
      );
      expect(
        containerHidden.where(
          (item) => item.sefariaRef.startsWith('Mishnah Niddah'),
        ),
        isEmpty,
        reason:
            'hiding a container must remove every descendant from lifetime totals',
      );
      expect(
        containerHidden.map((item) => item.sefariaRef),
        contains('Mishnah Berakhot 1:1'),
      );

      final hiddenLeaf = ProfileVisibleContentRepository(
        _DiskContentRepository(),
        {'Mishnah Berakhot 1:1'},
      );
      final leafHidden = await hiddenLeaf.loadLeavesTransient(
        CurriculumId.mishnayos,
      );
      expect(
        leafHidden.map((item) => item.sefariaRef),
        isNot(contains('Mishnah Berakhot 1:1')),
      );
      expect(
        leafHidden.map((item) => item.sefariaRef),
        contains('Mishnah Berakhot 1:2'),
      );
    },
  );

  test('bounded hidden-leaf loading completes for every curriculum', () async {
    final repository = ProfileVisibleContentRepository(
      _DiskContentRepository(),
      {'Mishnah Niddah'},
    );
    for (final curriculum in CurriculumId.values) {
      final leaves = await repository.loadLeavesTransient(curriculum);
      expect(leaves.every((item) => item.isLeaf), isTrue);
    }
  });
}
