import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';

@RoutePage()
class ContentHierarchyScreen extends ConsumerStatefulWidget {
  const ContentHierarchyScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
    this.level1,
    this.level2,
    this.level3,
    this.level4,
  });

  final String curriculumId;
  final String? level1;
  final String? level2;
  final String? level3;
  final String? level4;

  @override
  ConsumerState<ContentHierarchyScreen> createState() =>
      _ContentHierarchyScreenState();
}

class _ContentHierarchyScreenState
    extends ConsumerState<ContentHierarchyScreen> {
  // Navigation stack to track drill-down path
  List<String> _navigationStack = [];

  @override
  void initState() {
    super.initState();
    // Initialize navigation stack from route parameters
    _navigationStack = [
      if (widget.level1 != null) widget.level1!,
      if (widget.level2 != null) widget.level2!,
      if (widget.level3 != null) widget.level3!,
      if (widget.level4 != null) widget.level4!,
    ];
  }

  /// Returns the [CurriculumId] matching the route parameter, or null if
  /// the parameter does not correspond to any known curriculum.
  CurriculumId? get _curriculumOrNull {
    final matches = CurriculumId.values.where(
      (c) => c.storageKey == widget.curriculumId,
    );
    return matches.isNotEmpty ? matches.first : null;
  }

  String? get _currentLevel1 =>
      _navigationStack.isNotEmpty ? _navigationStack[0] : null;
  String? get _currentLevel2 =>
      _navigationStack.length > 1 ? _navigationStack[1] : null;
  String? get _currentLevel3 =>
      _navigationStack.length > 2 ? _navigationStack[2] : null;
  String? get _currentLevel4 =>
      _navigationStack.length > 3 ? _navigationStack[3] : null;

  @override
  Widget build(BuildContext context) {
    final curriculum = _curriculumOrNull;

    if (curriculum == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Unknown Curriculum')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Unknown curriculum: "${widget.curriculumId}"',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final configAsync = ref.watch(
      curriculumHierarchyConfigProvider(curriculum),
    );
    final itemsAsync = ref.watch(
      filteredContentProvider(
        curriculumId: curriculum,
        level1: _currentLevel1,
        level2: _currentLevel2,
        level3: _currentLevel3,
        level4: _currentLevel4,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(curriculum.displayNameEn),
        leading: _navigationStack.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _navigateUp,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => context.router.push(
              ContentSearchRoute(curriculumId: curriculum.storageKey),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Breadcrumb navigation
          if (_navigationStack.isNotEmpty)
            configAsync.when(
              data: (config) => BreadcrumbNavigation(
                curriculum: curriculum,
                levelLabels: config.levelLabels,
                navigationStack: _navigationStack,
                onBreadcrumbTap: _navigateToLevel,
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

          // Content list
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No content available'));
                }

                // Group items by the next level in hierarchy
                final groupedItems = _groupItemsByNextLevel(items);

                return ListView.builder(
                  itemCount: groupedItems.length,
                  itemBuilder: (context, index) {
                    final item = groupedItems[index];
                    return ContentItemTile(
                      item: item,
                      curriculum: curriculum,
                      onTap: () => _handleItemTap(item),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading content: $error'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Group items by the next level in the hierarchy to show unique containers.
  List<ContentItem> _groupItemsByNextLevel(List<ContentItem> items) {
    // Determine current depth
    final currentDepth = _navigationStack.length;

    if (currentDepth >= 4) {
      // At max depth, show all leaf items
      return items;
    }

    // If all items at this depth are leaves, show them directly without grouping.
    if (items.isNotEmpty && items.every((i) => i.isLeaf)) {
      return items;
    }

    // Group by the next level value, creating a representative container item
    // for each group whose display name is the group key (e.g. "Seder Zeraim"),
    // not the name of an arbitrary leaf inside it.
    final uniqueItems = <String, ContentItem>{};

    for (final item in items) {
      final nextLevelValue = _getNextLevelValue(item, currentDepth);
      if (nextLevelValue != null && !uniqueItems.containsKey(nextLevelValue)) {
        // Prefer container items (non-leaf) as representatives because they
        // already have the correct display names for the group (e.g., the
        // seder name). Leaf items have their own sub-level names and must not
        // be used directly — in that case we create a synthetic container item
        // using the group key as the display name.
        if (!item.isLeaf) {
          uniqueItems[nextLevelValue] = item;
        } else {
          uniqueItems[nextLevelValue] = ContentItem(
            curriculumId: item.curriculumId,
            level1: item.level1,
            level2: currentDepth >= 1 ? item.level2 : null,
            level3: currentDepth >= 2 ? item.level3 : null,
            level4: currentDepth >= 3 ? item.level4 : null,
            displayNameHe: nextLevelValue,
            displayNameEn: nextLevelValue,
            sefariaRef: item.sefariaRef,
            sortOrder: item.sortOrder,
            isLeaf: false,
          );
        }
      }
    }

    // Sort by sortOrder of the first representative item encountered.
    final result = uniqueItems.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return result;
  }

  String? _getNextLevelValue(ContentItem item, int currentDepth) {
    return switch (currentDepth) {
      0 => item.level1,
      1 => item.level2,
      2 => item.level3,
      3 => item.level4,
      _ => null,
    };
  }

  void _handleItemTap(ContentItem item) {
    if (item.isLeaf) {
      // Navigate to text display screen
      context.router.push(TextDisplayRoute(sefariaRef: item.sefariaRef));
    } else {
      // Drill down into container
      _drillDown(item);
    }
  }

  void _drillDown(ContentItem item) {
    setState(() {
      final currentDepth = _navigationStack.length;
      final nextValue = _getNextLevelValue(item, currentDepth);

      if (nextValue != null && currentDepth < 4) {
        _navigationStack = [..._navigationStack, nextValue];
      }
    });
  }

  void _navigateUp() {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _navigationStack = _navigationStack.sublist(
          0,
          _navigationStack.length - 1,
        );
      });
    }
  }

  void _navigateToLevel(int level) {
    if (level < _navigationStack.length) {
      setState(() {
        _navigationStack = _navigationStack.sublist(0, level + 1);
      });
    }
  }
}
