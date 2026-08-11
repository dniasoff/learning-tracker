import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/settings/data/repositories/firestore_curriculum_scope_settings_adapter.dart';

/// Adapter provider — see [FirestoreCurriculumScopeSettingsAdapter]'s class
/// doc comment for why this feature owns its own adapter over the shared
/// Firestore repository rather than importing tracks/setup's write adapter
/// (AD-23/AD-28 forbids the cross-feature deep import).
final curriculumScopeSettingsAdapterProvider =
    Provider<FirestoreCurriculumScopeSettingsAdapter>(
      (ref) => FirestoreCurriculumScopeSettingsAdapter(ref: ref),
    );

/// Get a scope summary string for display (e.g., "Seder Zeraim, Seder Moed" or "All").
final curriculumScopeSummaryProvider =
    FutureProvider.family<String, CurriculumId>((ref, curriculumId) async {
      final adapter = ref.watch(curriculumScopeSettingsAdapterProvider);
      final values = await adapter.getScopeValues(curriculumId);
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
      final adapter = ref.watch(curriculumScopeSettingsAdapterProvider);
      final repository = ref.watch(contentRepositoryProvider);

      final scopes = await adapter.getScopes(curriculumId);
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

/// Scope-aware filtered content provider.
/// First applies scope filters, then applies hierarchy level filters.
final scopedFilteredContentProvider = FutureProvider.family
    .autoDispose<
      List<ContentItem>,
      ({
        CurriculumId curriculumId,
        String? level1,
        String? level2,
        String? level3,
        String? level4,
      })
    >((ref, params) async {
      final items = await ref.watch(
        scopedCurriculumContentProvider(params.curriculumId).future,
      );

      return items.where((item) {
        if (params.level1 != null && item.level1 != params.level1) return false;
        if (params.level2 != null && item.level2 != params.level2) return false;
        if (params.level3 != null && item.level3 != params.level3) return false;
        if (params.level4 != null && item.level4 != params.level4) return false;
        return true;
      }).toList();
    });

/// Count of leaf items in scoped content.
final scopedItemCountProvider = FutureProvider.family<int, CurriculumId>((
  ref,
  curriculumId,
) async {
  final items = await ref.watch(
    scopedCurriculumContentProvider(curriculumId).future,
  );
  return items.where((i) => i.isLeaf).length;
});

/// Count of DISTINCT coarse "learning units" — the leaf's PARENT level — in the
/// scoped content. E.g. distinct dapim (not amudim) for Talmud, distinct perakim
/// (not pesukim) for Chumash, distinct simanim (not seif-katan) for Mishna
/// Berurah.
///
/// A pace goal whose granularity is a COARSE unit (daf/perek/seif — the
/// [PaceGranularity] enum values) measures pace in these units, so a
/// completion-date estimate must divide by THIS count, not the leaf count. The
/// add-track wizard already does this (StepGoal._countScopeInLearningUnit); the
/// track-detail estimate previously divided the leaf (amudim) count by the
/// daf-per-week rate, doubling the projected timeline. This provider mirrors the
/// wizard's coarse-branch counting so both surfaces agree.
final scopedCoarseUnitCountProvider = FutureProvider.family<int, CurriculumId>((
  ref,
  curriculumId,
) async {
  final items = await ref.watch(
    scopedCurriculumContentProvider(curriculumId).future,
  );
  final keys = <String>{};
  for (final item in items) {
    if (!item.isLeaf) continue;
    // Collapse each leaf to its parent (one level up): the coarse unit.
    final key = item.level4 != null
        ? '${item.level1}|${item.level2}|${item.level3}'
        : item.level3 != null
        ? '${item.level1}|${item.level2}'
        : item.level2 != null
        ? item.level1
        : item.sefariaRef;
    keys.add(key);
  }
  return keys.length;
});
