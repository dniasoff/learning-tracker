import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

/// Get a scope summary string for display (e.g., "Seder Zeraim, Seder Moed" or "All").
final curriculumScopeSummaryProvider =
    FutureProvider.family<String, CurriculumId>((ref, curriculumId) async {
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final values = await db.curriculumScopeDao.getScopeValues(
    profileId,
    curriculumId,
  );
  if (values.isEmpty) return 'All';
  return values.join(', ');
});

/// Get scoped content items for a curriculum (respects scope filters).
/// Returns all items if no scopes are set.
final scopedCurriculumContentProvider =
    FutureProvider.family<List<ContentItem>, CurriculumId>((
  ref,
  curriculumId,
) async {
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final repository = ref.watch(contentRepositoryProvider);

  final scopes = await db.curriculumScopeDao.getScopes(
    profileId,
    curriculumId,
  );
  if (scopes.isEmpty) {
    return repository.getContentForCurriculum(curriculumId);
  }

  final scopeLevel = scopes.first.scopeLevel;
  final scopeValues = scopes.map((s) => s.scopeValue).toList();
  return repository.getScopedContent(
    curriculumId: curriculumId,
    scopeLevel: scopeLevel,
    scopeValues: scopeValues,
  );
});

/// Count of leaf items in scoped content.
final scopedItemCountProvider =
    FutureProvider.family<int, CurriculumId>((ref, curriculumId) async {
  final items = await ref.watch(
    scopedCurriculumContentProvider(curriculumId).future,
  );
  return items.where((i) => i.isLeaf).length;
});
