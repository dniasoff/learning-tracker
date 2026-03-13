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
@Riverpod(keepAlive: true)
ContentRepository contentRepository(Ref ref) {
  return ContentRepositoryImpl();
}

/// Provides all content items for a specific curriculum (family provider).
///
/// Lazily loads the content from JSON assets on first access for each
/// curriculum, then caches in memory.
@riverpod
Future<List<ContentItem>> curriculumContent(
  Ref ref,
  CurriculumId curriculumId,
) async {
  final repository = ref.watch(contentRepositoryProvider);
  return repository.getContentForCurriculum(curriculumId);
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
