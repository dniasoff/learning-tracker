import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'content_providers.g.dart';

/// Provides the content repository (singleton).
///
/// keepAlive: true ensures the in-memory content cache persists for the
/// lifetime of the app — rebuilding this provider would discard cached data.
/// Loads hierarchy content from bundled assets.
@Riverpod(keepAlive: true)
ContentRepository contentRepository(Ref ref) {
  return ContentRepositoryImpl();
}

/// Provides all content items for a specific curriculum (family provider).
@riverpod
Future<List<ContentItem>> curriculumContent(
  Ref ref,
  CurriculumId curriculumId,
) async {
  final repository = ref.watch(contentRepositoryProvider);
  return repository.getContentForCurriculum(curriculumId);
}

/// Map of `sefariaRef → displayNameHe` for every leaf in [curriculumId].
///
/// Lets widgets that have a Sefaria ref (daily-task cards, completion
/// history, etc.) show the canonical Hebrew form when Hebrew Terms is on,
/// without having to plumb the Hebrew name through the model layer.
@Riverpod(keepAlive: true)
Future<Map<String, String>> curriculumHeNames(
  Ref ref,
  CurriculumId curriculumId,
) async {
  final items = await ref.watch(curriculumContentProvider(curriculumId).future);
  final out = <String, String>{};
  for (final it in items) {
    if (!it.isLeaf) continue;
    if (it.displayNameHe.isEmpty) continue;
    out[it.sefariaRef] = it.displayNameHe;
  }
  return out;
}

/// Provides the hierarchy configuration for a specific curriculum.
@riverpod
Future<CurriculumHierarchyConfig> curriculumHierarchyConfig(
  Ref ref,
  CurriculumId curriculumId,
) async {
  final repository = ref.watch(contentRepositoryProvider);
  return repository.getHierarchyConfig(curriculumId);
}

/// Provides filtered content by hierarchy level.
@riverpod
Future<List<ContentItem>> filteredContent(
  Ref ref, {
  required CurriculumId curriculumId,
  String? level1,
  String? level2,
  String? level3,
  String? level4,
}) async {
  final repository = ref.watch(contentRepositoryProvider);
  return repository.filterByLevel(
    curriculumId: curriculumId,
    level1: level1,
    level2: level2,
    level3: level3,
    level4: level4,
  );
}

/// Provides search results for a curriculum.
@riverpod
Future<List<ContentItem>> contentSearch(
  Ref ref, {
  required CurriculumId curriculumId,
  required String query,
}) async {
  final repository = ref.watch(contentRepositoryProvider);
  return repository.search(curriculumId: curriculumId, query: query);
}

/// Provides a specific content item by its sefariaRef.
@riverpod
Future<ContentItem?> contentByRef(
  Ref ref, {
  required CurriculumId curriculumId,
  required String sefariaRef,
}) async {
  final repository = ref.watch(contentRepositoryProvider);
  return repository.getContentByRef(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
  );
}

/// Finds the Hebrew display name for any leaf [sefariaRef] regardless of
/// which curriculum it came from. Used by screens (e.g. the text viewer)
/// that take a ref as a route param without knowing its curriculum.
///
/// Returns `null` when no curriculum knows about the ref or when the
/// curriculum hierarchies haven't loaded yet — callers should fall back
/// to the prettified English ref in that case.
@riverpod
Future<String?> hebrewNameForRef(Ref ref, String sefariaRef) async {
  for (final curriculum in CurriculumId.values) {
    final map = await ref.watch(curriculumHeNamesProvider(curriculum).future);
    final he = map[sefariaRef];
    if (he != null && he.isNotEmpty) return he;
  }
  return null;
}
