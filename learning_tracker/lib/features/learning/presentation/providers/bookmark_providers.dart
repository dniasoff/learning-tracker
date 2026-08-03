import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';

/// The app's bookmark repository — Firestore-backed, scoped to the active
/// learner profile via `activeProfileDocIdProvider` (a ULID doc-id) inside
/// [FirestoreBookmarkRepositoryAdapter]. No Drift, no int profile id, and
/// no delegated-profile factory: to write bookmarks for a profile, that
/// profile must be the ACTIVE one (see `onboarding_screen.dart`, which
/// selects a freshly created child before its add-track/bulk-mark phase).
///
/// Construction stays synchronous: the adapter holds a `Ref` and resolves
/// `firestoreBookmarkRepositoryProvider` per method call, so
/// `completionOrchestratorProvider` and `bulkPriorCompletionServiceProvider`
/// keep watching this as a plain `Provider`.
///
/// `ContentIndex` is passed through for the O(1) adjacent-item fast path
/// (Story 26.14 / DNI-357); `null` while it is still warming up, which the
/// repository handles by falling back to its O(N) content scan.
final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  final contentRepository = ref.watch(contentRepositoryProvider);
  final contentIndex = ref.watch(contentIndexProvider).asData?.value;
  return FirestoreBookmarkRepositoryAdapter(
    ref: ref,
    contentRepository: contentRepository,
    contentIndex: contentIndex,
  );
});
