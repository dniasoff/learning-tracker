import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/core/widgets/error_display.dart';
import 'package:learning_tracker/core/widgets/loading_indicator.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_hierarchy_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/hierarchy_breadcrumbs.dart';

/// Generic content hierarchy browsing screen.
/// Works for any curriculum depth (1-4 levels) by using the hierarchy key.
@RoutePage()
class ContentBrowsingScreen extends ConsumerStatefulWidget {
  const ContentBrowsingScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
  });

  final String curriculumId;

  @override
  ConsumerState<ContentBrowsingScreen> createState() =>
      _ContentBrowsingScreenState();
}

class _ContentBrowsingScreenState extends ConsumerState<ContentBrowsingScreen> {
  // Navigation stack for breadcrumb trail
  final List<_HierarchyLevel> _navigationStack = [];

  String get _currentHierarchyKey {
    if (_navigationStack.isEmpty) {
      return widget.curriculumId;
    }
    return HierarchyQueryParams(
      curriculumId: widget.curriculumId,
      level1: _navigationStack.length >= 1 ? _navigationStack[0].value : null,
      level2: _navigationStack.length >= 2 ? _navigationStack[1].value : null,
      level3: _navigationStack.length >= 3 ? _navigationStack[2].value : null,
    ).toKey();
  }

  void _navigateToChild(
    String levelValue,
    String displayNameHe,
    String displayNameEn,
  ) {
    setState(() {
      _navigationStack.add(
        _HierarchyLevel(
          value: levelValue,
          displayNameHe: displayNameHe,
          displayNameEn: displayNameEn,
        ),
      );
    });
  }

  void _navigateBack() {
    if (_navigationStack.isEmpty) {
      // At top level, go back to curriculum list
      context.router.maybePop();
    } else {
      setState(() {
        _navigationStack.removeLast();
      });
    }
  }

  void _navigateToLevel(int targetDepth) {
    if (targetDepth < 0 || targetDepth > _navigationStack.length) return;

    setState(() {
      _navigationStack.removeRange(targetDepth, _navigationStack.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(hierarchyItemsProvider(_currentHierarchyKey));
    final labelsAsync = ref.watch(hierarchyLabelsProvider(widget.curriculumId));

    return PopScope(
      canPop: _navigationStack.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _navigateBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getTitle()),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _navigateBack,
          ),
        ),
        body: Column(
          children: [
            // Breadcrumb navigation
            if (_navigationStack.isNotEmpty)
              HierarchyBreadcrumbs(
                curriculumId: widget.curriculumId,
                navigationStack: _navigationStack
                    .map(
                      (l) => BreadcrumbItem(
                        displayNameHe: l.displayNameHe,
                        displayNameEn: l.displayNameEn,
                      ),
                    )
                    .toList(),
                onTapLevel: _navigateToLevel,
              ),

            // Content list
            Expanded(
              child: itemsAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyState(
                      message: 'No items found',
                      subtitle: 'This section is empty',
                    );
                  }

                  return labelsAsync.when(
                    data: (labels) => _buildItemsList(items, labels),
                    loading: () => _buildItemsList(items, []),
                    error: (_, __) => _buildItemsList(items, []),
                  );
                },
                loading: () => const LoadingIndicator(),
                error: (error, stack) => ErrorDisplay(
                  message: 'Failed to load content: ${error.toString()}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(List<HierarchyItemDTO> items, List<String> labels) {
    final currentDepth = _navigationStack.length;
    final currentLevelLabel = currentDepth < labels.length
        ? labels[currentDepth]
        : 'Items';

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = items[index];
        return _HierarchyItemTile(
          item: item,
          levelLabel: currentLevelLabel,
          onTap: item.isLeaf
              ? () {
                  // TODO: Navigate to learning screen for leaf item
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Learn: ${item.displayNameHe}')),
                  );
                }
              : () {
                  final nextLevelValue = switch (currentDepth) {
                    0 => item.level1,
                    1 => item.level2!,
                    2 => item.level3!,
                    3 => item.level4!,
                    _ => item.level1,
                  };
                  _navigateToChild(
                    nextLevelValue,
                    item.displayNameHe,
                    item.displayNameEn,
                  );
                },
        );
      },
    );
  }

  String _getTitle() {
    if (_navigationStack.isEmpty) {
      return 'Browse';
    }
    return _navigationStack.last.displayNameHe;
  }
}

class _HierarchyLevel {
  const _HierarchyLevel({
    required this.value,
    required this.displayNameHe,
    required this.displayNameEn,
  });

  final String value;
  final String displayNameHe;
  final String displayNameEn;
}

class _HierarchyItemTile extends StatelessWidget {
  const _HierarchyItemTile({
    required this.item,
    required this.levelLabel,
    required this.onTap,
  });

  final HierarchyItemDTO item;
  final String levelLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Item icon
              Icon(
                item.isLeaf ? Icons.article : Icons.folder,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              // Item name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayNameHe,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.displayNameEn,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Trailing indicator
              if (!item.isLeaf)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              // TODO: Add completion indicators for leaf items
            ],
          ),
        ),
      ),
    );
  }
}
