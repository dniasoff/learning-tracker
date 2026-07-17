import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Factory for a [BookmarkRepository] scoped to an arbitrary profile,
/// carrying the same [ContentIndex]/sync/gateway wiring as
/// [bookmarkRepositoryProvider] (which is hard-scoped to the active
/// profile).
///
/// AUD-learning-04: `CompletionRepositoryImpl` uses this (via
/// `completionRepositoryProvider`) so delegated-profile bookmark advances
/// (e.g. `bulkMarkComplete` with `profileId` != the active profile — parent
/// bulk-marking prior learning for a child) keep the O(1) adjacent-item
/// fast path instead of falling back to an ad-hoc, non-indexed
/// [BookmarkRepositoryImpl].
final bookmarkRepositoryFactoryProvider =
    Provider<BookmarkRepository Function(int profileId)>((ref) {
      final database = ref.watch(userDatabaseProvider);
      final syncFacade = ref.watch(syncWriteFacadeProvider);
      final firestoreGateway = ref.watch(firestoreGatewayProvider);
      final contentRepository = ref.watch(contentRepositoryProvider);
      // ContentIndex may still be loading — pass null until it's ready so
      // the repository falls back to its O(N) scan path (correct
      // behaviour, just slightly slower during the first warmup).
      final contentIndex = ref.watch(contentIndexProvider).asData?.value;

      return (profileId) => BookmarkRepositoryImpl(
        database: database,
        syncEngine: syncFacade,
        firestoreGateway: firestoreGateway,
        contentRepository: contentRepository,
        profileId: profileId,
        contentIndex: contentIndex,
      );
    });

/// Provider for bookmark repository, scoped to the active profile.
///
/// Injects [ContentIndex] (Story 26.14 / DNI-357) so [advanceBookmark] and
/// [initializeBookmark] use O(1) adjacent-item lookups instead of O(N) scans.
final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  final factory = ref.watch(bookmarkRepositoryFactoryProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return factory(profileId);
});

/// Provider family for a specific bookmark (one track per curriculum).
final bookmarkProvider = FutureProvider.autoDispose
    .family<BookmarkEntity?, CurriculumId>((ref, curriculumId) async {
      final repository = ref.watch(bookmarkRepositoryProvider);
      return await repository.getBookmark(curriculumId: curriculumId);
    });

/// Actions for bookmark operations.
class BookmarkActions {
  BookmarkActions(this.ref);

  final Ref ref;

  /// Set bookmark to a specific content item (manual jump).
  Future<void> setBookmark({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async {
    final repository = ref.read(bookmarkRepositoryProvider);
    await repository.setBookmark(
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
    );

    // Invalidate the bookmark provider to refresh UI
    ref.invalidate(bookmarkProvider(curriculumId));
  }

  /// Initialize bookmark for a new curriculum.
  Future<void> initializeBookmark({required CurriculumId curriculumId}) async {
    final repository = ref.read(bookmarkRepositoryProvider);
    await repository.initializeBookmark(curriculumId: curriculumId);

    // Invalidate the bookmark provider to refresh UI
    ref.invalidate(bookmarkProvider(curriculumId));
  }
}

/// Provider for bookmark actions.
final bookmarkActionsProvider = Provider<BookmarkActions>((ref) {
  return BookmarkActions(ref);
});
