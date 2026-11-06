import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/core/providers/account_functions_provider.dart';
import 'package:learning_tracker/core/providers/active_account_firebase_provider.dart';
import 'package:learning_tracker/data/repositories/firestore_hidden_content_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';
import 'package:learning_tracker/features/content_browsing/domain/profile_visible_content_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'content_providers.g.dart';

/// Provides the content repository (singleton).
///
/// **Composition-root carve-out (AUD-content_browsing-04):** this file's
/// `data/repositories/content_repository_impl.dart` import constructs the
/// concrete repository to bind it to [ContentRepository] — the DI wiring
/// step, not an entity leak. See "Composition-root carve-out" in
/// docs/coding-standards.md; the same pattern is used by ~11 other
/// feature `presentation/providers/` files repo-wide.
///
/// keepAlive: true ensures the in-memory content cache persists for the
/// lifetime of the app — rebuilding this provider would discard cached data.
/// Loads hierarchy content from bundled assets.
// keepAlive: singleton in-memory content cache must survive rebuilds for the app's lifetime.
@Riverpod(keepAlive: true)
ContentRepository contentRepository(Ref ref) {
  return ContentRepositoryImpl();
}

/// Repository for the active profile's hidden node refs. The owner uid
/// switches to the parent namespace when a tutor is viewing a talmid.
final hiddenContentRepositoryProvider =
    FutureProvider<FirestoreHiddenContentRepository?>((ref) async {
      final profileId = ref.watch(activeProfileIdProvider);
      if (profileId == null) {
        return null;
      }
      final handles = await ref.watch(activeAccountFirebaseProvider.future);
      if (handles == null) {
        return null;
      }
      final ownerUid =
          ref.watch(activeTutoredProfileSelectionProvider)?.ownerUid ??
          handles.uid;
      return FirestoreHiddenContentRepository(
        firestore: handles.firestore,
        ownerUid: ownerUid,
        profileId: profileId,
        resolveFunctions: ref.watch(accountFunctionsProvider),
        parentSessionId: ownerUid == handles.uid
            ? ref.watch(parentSessionIdProvider)
            : null,
      );
    });

/// Live hidden node refs for the active profile.
final hiddenContentRefsProvider = StreamProvider<Set<String>>((ref) async* {
  final repository = await ref.watch(hiddenContentRepositoryProvider.future);
  if (repository == null) {
    yield const {};
    return;
  }
  yield* repository.watchHiddenRefs();
});

/// Hidden refs for an explicitly addressed learner scope. Tutor roster rows
/// use this family rather than the active-profile stream: several talmidim
/// can be visible at once, and each row must receive its own policy.
final hiddenContentRefsForScopeProvider = FutureProvider.autoDispose
    .family<Set<String>, LearnerScope>((ref, scope) async {
      final handles = await ref.watch(activeAccountFirebaseProvider.future);
      if (handles == null) return const {};
      final repository = FirestoreHiddenContentRepository(
        firestore: handles.firestore,
        ownerUid: scope.ownerUid,
        profileId: scope.profileId,
        resolveFunctions: ref.watch(accountFunctionsProvider),
      );
      return repository.getHiddenRefs();
    });

/// The profile-keyed visibility seam above the raw, process-cached repository.
/// Consumers that need content should resolve this provider rather than the
/// raw repository so a profile switch cannot reuse another child's view.
///
/// A separate scope family below serves tutor roster rows whose target is not
/// the active profile.
final visibleContentRepositoryProvider = FutureProvider<ContentRepository>((
  ref,
) async {
  final hidden = await ref.watch(hiddenContentRefsProvider.future);
  return ProfileVisibleContentRepository(
    ref.watch(contentRepositoryProvider),
    hidden,
  );
});

/// Profile-keyed visibility for a target learner, including tutor roster
/// targets that are not the currently active profile.
final visibleContentRepositoryForScopeProvider = FutureProvider.autoDispose
    .family<ContentRepository, LearnerScope>((ref, scope) async {
      final hidden = await ref.watch(
        hiddenContentRefsForScopeProvider(scope).future,
      );
      return ProfileVisibleContentRepository(
        ref.watch(contentRepositoryProvider),
        hidden,
      );
    });

/// Provides all content items for a specific curriculum (family provider).
@riverpod
Future<List<ContentItem>> curriculumContent(
  Ref ref,
  CurriculumId curriculumId,
) async {
  final repository = await ref.watch(visibleContentRepositoryProvider.future);
  return repository.getContentForCurriculum(curriculumId);
}

/// Map of `sefariaRef → displayNameHe` for every leaf in [curriculumId].
///
/// Lets widgets that have a Sefaria ref (daily-task cards, completion
/// history, etc.) show the canonical Hebrew form when Hebrew Terms is on,
/// without having to plumb the Hebrew name through the model layer.
// keepAlive: built from a full-curriculum scan; must survive last-listener-disappear so repeat lookups stay cheap.
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
  final repository = await ref.watch(visibleContentRepositoryProvider.future);
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
  final repository = await ref.watch(visibleContentRepositoryProvider.future);
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
  final repository = await ref.watch(visibleContentRepositoryProvider.future);
  return repository.search(curriculumId: curriculumId, query: query);
}

/// Provides a specific content item by its sefariaRef.
@riverpod
Future<ContentItem?> contentByRef(
  Ref ref, {
  required CurriculumId curriculumId,
  required String sefariaRef,
}) async {
  final repository = await ref.watch(visibleContentRepositoryProvider.future);
  return repository.getContentByRef(
    curriculumId: curriculumId,
    sefariaRef: sefariaRef,
  );
}

/// Returns the prev and next sibling refs for [sefariaRef] at the same
/// hierarchy depth within its curriculum.
///
/// Used by the text reader to show ← / → navigation arrows.
/// Navigates through all items at the same level (e.g., amudim within a
/// masechta, chapters within a sefer).
@riverpod
Future<({String? prev, String? next})> adjacentContentRefs(
  Ref ref,
  String sefariaRef,
) async {
  for (final curriculum in CurriculumId.values) {
    final items = await ref.watch(curriculumContentProvider(curriculum).future);
    final currentIdx = items.indexWhere((i) => i.sefariaRef == sefariaRef);
    if (currentIdx < 0) continue;

    final depth = _levelDepth(items[currentIdx]);
    final sameLevel = items.where((i) => _levelDepth(i) == depth).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final sameIdx = sameLevel.indexWhere((i) => i.sefariaRef == sefariaRef);
    if (sameIdx < 0) continue;

    return (
      prev: sameIdx > 0 ? sameLevel[sameIdx - 1].sefariaRef : null,
      next: sameIdx < sameLevel.length - 1
          ? sameLevel[sameIdx + 1].sefariaRef
          : null,
    );
  }
  return (prev: null, next: null);
}

int _levelDepth(ContentItem item) {
  if (item.level4 != null) return 4;
  if (item.level3 != null) return 3;
  if (item.level2 != null) return 2;
  return 1;
}
