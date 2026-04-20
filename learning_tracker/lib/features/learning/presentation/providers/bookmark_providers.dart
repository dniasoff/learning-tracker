import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/data/repositories/bookmark_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/bookmark.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tutor_mode/domain/tutor_mode_provider.dart';

/// Provider for bookmark repository, scoped to the active profile.
final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  final database = ref.watch(userDatabaseProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  final contentRepository = ref.watch(contentRepositoryProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  return BookmarkRepositoryImpl(
    database: database,
    syncEngine: syncEngine,
    contentRepository: contentRepository,
    profileId: profileId,
  );
});

/// Provider family for a specific bookmark (curriculum + track).
final bookmarkProvider = FutureProvider.autoDispose
    .family<
      BookmarkEntity?,
      ({CurriculumId curriculumId, TrackType trackType})
    >((ref, params) async {
      final repository = ref.watch(bookmarkRepositoryProvider);
      return await repository.getBookmark(
        curriculumId: params.curriculumId,
        trackType: params.trackType,
      );
    });

/// Actions for bookmark operations.
class BookmarkActions {
  BookmarkActions(this.ref);

  final Ref ref;

  /// Set bookmark to a specific content item (manual jump).
  ///
  /// Throws [TutorModeReadOnlyException] if tutor mode is active.
  Future<void> setBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
    required String sefariaRef,
  }) async {
    guardTutorModeWrite(ref);
    final repository = ref.read(bookmarkRepositoryProvider);
    await repository.setBookmark(
      curriculumId: curriculumId,
      trackType: trackType,
      sefariaRef: sefariaRef,
    );

    // Invalidate the bookmark provider to refresh UI
    ref.invalidate(
      bookmarkProvider((curriculumId: curriculumId, trackType: trackType)),
    );
  }

  /// Initialize bookmark for a new curriculum/track.
  Future<void> initializeBookmark({
    required CurriculumId curriculumId,
    required TrackType trackType,
  }) async {
    final repository = ref.read(bookmarkRepositoryProvider);
    await repository.initializeBookmark(
      curriculumId: curriculumId,
      trackType: trackType,
    );

    // Invalidate the bookmark provider to refresh UI
    ref.invalidate(
      bookmarkProvider((curriculumId: curriculumId, trackType: trackType)),
    );
  }
}

/// Provider for bookmark actions.
final bookmarkActionsProvider = Provider<BookmarkActions>((ref) {
  return BookmarkActions(ref);
});
