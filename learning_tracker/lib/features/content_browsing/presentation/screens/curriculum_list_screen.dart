import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_hierarchy_providers.dart';

/// Curriculum list screen showing all active curricula with icons and item counts.
/// Entry point for content hierarchy browsing.
@RoutePage()
class CurriculumListScreen extends ConsumerWidget {
  const CurriculumListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final curriculaAsync = ref.watch(curriculumListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Browse Content')),
      body: curriculaAsync.when(
        data: (curricula) {
          if (curricula.isEmpty) {
            return const EmptyState(
              message: 'No content available',
              subtitle: 'Content will appear here once imported',
            );
          }

          return ListView.builder(
            itemCount: curricula.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final info = curricula[index];
              return _CurriculumCard(info: info);
            },
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorDisplay(
          message: 'Failed to load curricula: ${error.toString()}',
        ),
      ),
    );
  }
}

class _CurriculumCard extends ConsumerWidget {
  const _CurriculumCard({required this.info});

  final CurriculumInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // Navigate to hierarchy screen for this curriculum
          context.router.push(
            ContentBrowsingRoute(curriculumId: info.curriculum.storageKey),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Curriculum icon (placeholder - can be enhanced with real icons)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForCurriculum(),
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              // Curriculum name and count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.curriculum.displayNameHe,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.curriculum.displayNameEn,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${info.itemCount} items',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForCurriculum() {
    // Simple icon mapping - can be enhanced with custom icons
    return switch (info.curriculum.storageKey) {
      'mishnayos' => Icons.menu_book,
      'bavli' => Icons.book,
      'yerushalmi' => Icons.book_outlined,
      'mishna_berurah' => Icons.auto_stories,
      'chumash' => Icons.library_books,
      _ => Icons.book,
    };
  }
}
