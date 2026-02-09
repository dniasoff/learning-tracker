import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/learning/presentation/providers/bookmark_providers.dart';

/// Card widget displaying "Continue where you left off" with bookmarked item.
///
/// Shows the current bookmarked content item for a curriculum/track combination.
/// Tapping the card navigates to the content learning screen for that item.
class BookmarkCard extends ConsumerWidget {
  const BookmarkCard({
    super.key,
    required this.curriculumId,
    required this.trackType,
  });

  final CurriculumId curriculumId;
  final TrackType trackType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkAsync = ref.watch(
      bookmarkProvider((curriculumId: curriculumId, trackType: trackType)),
    );

    return bookmarkAsync.when(
      data: (bookmark) {
        if (bookmark == null) {
          // No bookmark yet - show "Start learning" card
          return Card(
            margin: const EdgeInsets.all(16),
            child: InkWell(
              onTap: () => _initializeAndNavigate(context, ref),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Start Learning',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Begin your ${curriculumId.displayNameEn} journey',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Bookmark exists - show "Continue" card
        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 2,
          child: InkWell(
            onTap: () => _navigateToBookmark(context, bookmark.contentItemId),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bookmark,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Continue where you left off',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // TODO: Fetch and display content item name
                  Text(
                    'Content Item #${bookmark.contentItemId}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last updated: ${_formatDate(bookmark.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                'Error loading bookmark',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initializeAndNavigate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Initialize bookmark to first item
    await ref
        .read(bookmarkActionsProvider)
        .initializeBookmark(curriculumId: curriculumId, trackType: trackType);

    // Get the newly created bookmark
    final bookmark = await ref.read(
      bookmarkProvider((
        curriculumId: curriculumId,
        trackType: trackType,
      )).future,
    );

    if (bookmark != null && context.mounted) {
      _navigateToBookmark(context, bookmark.contentItemId);
    }
  }

  void _navigateToBookmark(BuildContext context, int contentItemId) {
    // Navigate to curriculum learning screen
    // TODO: Update this to navigate to the specific content item
    context.router.push(
      CurriculumLearningRoute(curriculumId: curriculumId.storageKey),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
