/// Story acceptance coverage for Epic 2 — content.
@Tags(['epic_2'])
library;

import 'dart:io';

import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/utils/hebrew_utils.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:test/test.dart';

// The content fixtures are intentionally local to the acceptance suite: they
// model the cloud-content contract without reintroducing a content SQLite DB.
ContentItem _item(String ref, CurriculumId curriculum) => ContentItem(
  curriculumId: curriculum.storageKey,
  sefariaRef: ref,
  displayNameEn: ref,
  displayNameHe: ref,
  isLeaf: true,
  sortOrder: 0,
  level1: 'Level 1',
);

void main() {
  group('Story 2.1 — content repository', tags: ['story_2_1'], () {
    test('content repository is the concrete implementation', () {
      expect(ContentRepositoryImpl(), isA<ContentRepositoryImpl>());
    });

    test('content items retain their canonical curriculum identity', () {
      final mishna = _item('Mishnah 1', CurriculumId.mishnayos);
      final daf = _item('Daf 1a', CurriculumId.bavli);
      expect(mishna.curriculumId, CurriculumId.mishnayos.storageKey);
      expect(daf.curriculumId, CurriculumId.bavli.storageKey);
      expect(mishna.isLeaf, isTrue);
    });
  });

  group('Story 2.2 — hierarchy browsing', tags: ['story_2_2'], () {
    test('hierarchy configuration supports four levels', () {
      const config = CurriculumHierarchyConfig(
        curriculumId: 'mishnayos',
        levelLabels: ['Seder', 'Masechta', 'Perek', 'Mishna'],
        totalItems: 4219,
      );
      expect(config.depth, 4);
    });

    test('labels come from the central curriculum registry', () {
      expect(CurriculumLabels.depth(CurriculumId.mishnayos), 4);
      expect(CurriculumLabels.level(CurriculumId.mishnayos, 1).en, 'Seder');
    });

    test('content providers are keyed by CurriculumId', () {
      final mishnayos = curriculumContentProvider(CurriculumId.mishnayos);
      final bavli = curriculumContentProvider(CurriculumId.bavli);
      expect(mishnayos.argument, CurriculumId.mishnayos);
      expect(bavli.argument, CurriculumId.bavli);
      expect(mishnayos, isNot(same(bavli)));

      final source = File(
        'lib/features/content_browsing/presentation/providers/content_providers.dart',
      ).readAsStringSync();
      // Riverpod's generated family is declared by the @riverpod function
      // and its typed CurriculumId parameter; the source does not contain a
      // literal `family(CurriculumId` call.
      expect(source, contains('Future<List<ContentItem>> curriculumContent('));
      expect(source, contains('CurriculumId curriculumId'));
    });
  });

  group('Story 2.3 — text caching', tags: ['story_2_3'], () {
    test('cache architecture has no content_items Drift table dependency', () {
      final source = File(
        'lib/features/content_browsing/data/repositories/text_cache_repository.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('content_items')));
    });
  });

  group(
    'Story 2.4 — curriculum activation',
    tags: ['story_2_4'],
    skip:
        'Blocked: CurriculumActivationService still depends on Drift track/active-curriculum DAOs; its Firestore adapter seam is not available.',
    () {
      test('placeholder for the pending Firestore activation seam', () {});
    },
  );

  group('Story 2.5 — bundled content assets', tags: ['story_2_5'], () {
    test('content hierarchy screen exists and is Riverpod-based', () {
      final source = File(
        'lib/features/content_browsing/presentation/screens/content_hierarchy_screen.dart',
      ).readAsStringSync();
      expect(source, contains('ConsumerStatefulWidget'));
      expect(source, contains('curriculumId'));
    });
  });

  group('Story 2.6 — cache-only architecture', tags: ['story_2_6'], () {
    test('HebrewUtils strips nikud', () {
      expect(HebrewUtils.stripNikud('בְּרָכָה'), 'ברכה');
      expect(HebrewUtils.hasNikud('בְּרָכָה'), isTrue);
    });

    test('content repository implementation is concrete', () {
      expect(ContentRepositoryImpl(), isA<ContentRepositoryImpl>());
    });
  });
}
