import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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
  List<String> _navigationStack = [];

  @override
  void initState() {
    super.initState();
    _navigationStack = [
      if (widget.level1 != null) widget.level1!,
      if (widget.level2 != null) widget.level2!,
      if (widget.level3 != null) widget.level3!,
      if (widget.level4 != null) widget.level4!,
    ];
  }

  CurriculumId? get _curriculumOrNull {
    final matches = CurriculumId.values.where(
      (c) => c.storageKey == widget.curriculumId,
    );
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Returns the value at [depth] in the navigation stack (0-indexed), or null
  /// when the stack is shallower than [depth] + 1.
  ///
  /// Replaces the four separate `_currentLevel1/2/3/4` getters — one helper
  /// via [ContentTree] eliminates the ladder.
  String? _levelAt(int depth) =>
      _navigationStack.length > depth ? _navigationStack[depth] : null;

  @override
  Widget build(BuildContext context) {
    final curriculum = _curriculumOrNull;

    if (curriculum == null) {
      return Scaffold(
        appBar: AppBar(title: const AppBarTitle(text: 'Unknown Curriculum')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.brandCoralDeep,
              ),
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

    final curriculumColor = AppTheme.getCurriculumColor(curriculum);
    final configAsync = ref.watch(
      curriculumHierarchyConfigProvider(curriculum),
    );

    // ContentTree-backed items lookup: O(1) child retrieval replaces the
    // four-argument level1/2/3/4 filter (T2.10).
    final treeAsync = ref.watch(contentTreeProvider);
    final itemsAsync = treeAsync.when(
      data: (tree) {
        final children = tree.children(curriculum, _navigationStack);
        // Fall back to the filteredContent provider if the tree hasn't
        // indexed these items yet (e.g. during the very first load when the
        // curriculum content hasn't been cached in the tree yet).
        if (children.isEmpty && _navigationStack.isNotEmpty) {
          return ref.watch(
            filteredContentProvider(
              curriculumId: curriculum,
              level1: _levelAt(0),
              level2: _levelAt(1),
              level3: _levelAt(2),
              level4: _levelAt(3),
            ),
          );
        }
        return AsyncValue.data(children);
      },
      loading: () => const AsyncValue<List<ContentItem>>.loading(),
      error: (e, st) => ref.watch(
        filteredContentProvider(
          curriculumId: curriculum,
          level1: _levelAt(0),
          level2: _levelAt(1),
          level3: _levelAt(2),
          level4: _levelAt(3),
        ),
      ),
    );

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          child: Text(
            'Browse Content',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              letterSpacing: -0.2,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _navigationStack.isNotEmpty
              ? _navigateUp
              : () => context.router.maybePop(),
        ),
      ),
      body: Column(
        children: [
          // Breadcrumb / curriculum chip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: curriculumColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CurriculumLabel.curriculum(
                    curriculum,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: curriculumColor,
                    ),
                  ),
                ),
                if (_navigationStack.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: configAsync.when(
                      data: (config) {
                        final useHebrew = ref.watch(useHebrewTermsProvider);
                        final variant = ref.watch(
                          currentTransliterationVariantProvider,
                        );
                        final allCurriculumItems = ref
                            .watch(curriculumContentProvider(curriculum))
                            .asData
                            ?.value;
                        // Look up each ancestor's container ContentItem so
                        // the renderer can use its displayNameHe (e.g.
                        // 'סדר זרעים') instead of falling back to the raw
                        // English value ('Seder Zeraim').
                        final hebrewNames = _hebrewNamesForNavStack(
                          allCurriculumItems,
                        );
                        final segments =
                            CurriculumLabelRenderer.renderBreadcrumb(
                              curriculumId: curriculum,
                              rawSegmentValues: _navigationStack,
                              useHebrew: useHebrew,
                              transliterationVariant: variant,
                              hebrewNamesPerSegment: hebrewNames,
                            );
                        return BreadcrumbNavigation(
                          curriculum: curriculum,
                          levelLabels: config.levelLabels,
                          navigationStack: segments,
                          onBreadcrumbTap: _navigateToLevel,
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Content list
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No content available',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final useHebrew = ref.watch(useHebrewTermsProvider);
                final variant = ref.watch(
                  currentTransliterationVariantProvider,
                );
                final groupedItems = _groupItemsByNextLevel(
                  items,
                  useHebrew,
                  variant,
                );

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    const Icon(
                      Icons.error,
                      size: 48,
                      color: AppTheme.brandCoralDeep,
                    ),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.errorLoadingContent(error.toString())),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the list of rows shown at the current drill-down depth.
  ///
  /// All display strings — every row's Hebrew and English title — flow
  /// through `CurriculumLabelRenderer`. The screen no longer carries any
  /// bespoke prefix-stripping or amud-letter mapping; the renderer is the
  /// single source of truth.
  ///
  /// Browse depth is capped at `CurriculumLabels.maxBrowseDepth(curriculum)`
  /// so no curriculum drills into pasuk / mishna / seif / halacha rows —
  /// the perek-or-equivalent row opens the reader directly instead.
  List<ContentItem> _groupItemsByNextLevel(
    List<ContentItem> items,
    bool useHebrew,
    TransliterationVariant variant,
  ) {
    final curriculum = _curriculumOrNull;
    if (curriculum == null) return items;
    final currentDepth = _navigationStack.length;
    final maxBrowseDepth = CurriculumLabels.maxBrowseDepth(curriculum);
    if (currentDepth >= maxBrowseDepth) return const [];

    final nextLevel = currentDepth + 1;
    final uniqueItems = <String, ContentItem>{};

    for (final item in items) {
      final nextLevelValue = _getNextLevelValue(item, currentDepth);
      if (nextLevelValue == null || uniqueItems.containsKey(nextLevelValue)) {
        continue;
      }

      final renderedHe = CurriculumLabelRenderer.renderValue(
        curriculumId: curriculum,
        level: nextLevel,
        rawValue: nextLevelValue,
        useHebrew: true,
        hebrewName: !item.isLeaf ? item.displayNameHe : null,
        parentL1Value: item.level1,
        transliterationVariant: variant,
      );
      final renderedEn = CurriculumLabelRenderer.renderValue(
        curriculumId: curriculum,
        level: nextLevel,
        rawValue: nextLevelValue,
        useHebrew: false,
        hebrewName: !item.isLeaf ? item.displayNameHe : null,
        parentL1Value: item.level1,
        transliterationVariant: variant,
      );

      uniqueItems[nextLevelValue] = ContentItem(
        curriculumId: item.curriculumId,
        level1: item.level1,
        level2: currentDepth >= 1 ? item.level2 : null,
        level3: currentDepth >= 2 ? item.level3 : null,
        level4: currentDepth >= 3 ? item.level4 : null,
        displayNameHe: renderedHe,
        displayNameEn: renderedEn,
        sefariaRef: item.sefariaRef,
        sortOrder: item.sortOrder,
        isLeaf: item.isLeaf,
      );
    }

    return uniqueItems.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
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
    if (item.isLeaf || _isChapterLevelRef(item)) {
      context.router.push(TextDisplayRoute(sefariaRef: item.sefariaRef));
    } else {
      _drillDown(item);
    }
  }

  /// Returns true when tapping this item should open the text reader.
  ///
  /// Generalized rule: when a curriculum's `maxBrowseDepth` is less than
  /// its full depth (every curriculum except Bavli/Yerushalmi), items
  /// sitting at the max-browse depth open the reader instead of drilling
  /// — there's nothing useful to browse below them.
  bool _isChapterLevelRef(ContentItem item) {
    final curriculum = _curriculumOrNull;
    if (curriculum == null) return false;
    final maxDepth = CurriculumLabels.maxBrowseDepth(curriculum);
    if (maxDepth >= CurriculumLabels.depth(curriculum)) return false;
    final itemDepth = item.level4 != null
        ? 4
        : item.level3 != null
        ? 3
        : item.level2 != null
        ? 2
        : 1;
    return itemDepth == maxDepth;
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

  /// For each entry in [_navigationStack], find the container ContentItem
  /// (matching levels 1..N and no deeper) so the renderer can use its
  /// `displayNameHe` instead of falling back to the raw English value.
  ///
  /// Uses [ContentTree.containerFor] for O(1) lookup per segment when the
  /// tree is ready; falls back to a linear scan over [allItems] when not.
  ///
  /// Returns null entries when no container is found (e.g. during the first
  /// load or when a level carries an ordinal value rather than a named one).
  List<String?> _hebrewNamesForNavStack(List<ContentItem>? allItems) {
    if (_navigationStack.isEmpty) return const [];
    final curriculum = _curriculumOrNull;

    // Fast path: O(1) via ContentTree when available.
    if (curriculum != null) {
      final treeValue = ref.read(contentTreeProvider).asData?.value;
      if (treeValue != null) {
        final result = <String?>[];
        for (var depth = 0; depth < _navigationStack.length; depth++) {
          final prefixStack = _navigationStack.sublist(0, depth + 1);
          final container = treeValue.containerFor(curriculum, prefixStack);
          result.add(container?.displayNameHe);
        }
        return result;
      }
    }

    // Fallback: linear scan when tree is still loading.
    final result = <String?>[];
    if (allItems == null) {
      return List<String?>.filled(_navigationStack.length, null);
    }
    for (var depth = 0; depth < _navigationStack.length; depth++) {
      final segmentDepth = depth + 1;
      ContentItem? match;
      for (final item in allItems) {
        if (item.level1 != _navigationStack[0]) continue;
        if (segmentDepth >= 2 && item.level2 != _levelAt(1)) continue;
        if (segmentDepth >= 3 && item.level3 != _levelAt(2)) continue;
        if (segmentDepth >= 4 && item.level4 != _levelAt(3)) continue;
        if (segmentDepth < 2 && item.level2 != null) continue;
        if (segmentDepth < 3 && item.level3 != null) continue;
        if (segmentDepth < 4 && item.level4 != null) continue;
        match = item;
        break;
      }
      result.add(match?.displayNameHe);
    }
    return result;
  }
}
