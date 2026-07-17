import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/breadcrumb_navigation.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
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
      final l10nEarly = AppLocalizations.of(context)!;
      return Scaffold(
        appBar: AppBar(
          title: AppBarTitle(text: l10nEarly.contentHierarchyUnknownTitle),
        ),
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
                l10nEarly.errorUnknownCurriculum(widget.curriculumId),
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
        // curriculum content hasn't been cached in the tree yet).  This
        // applies at ALL depths — including root level (empty nav stack) —
        // so that an unpopulated tree does not incorrectly show "No content".
        if (children.isEmpty) {
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
    final l10n = AppLocalizations.of(context)!;
    // R2 finding 6: make the Android/system Back button step up ONE hierarchy
    // level (matching the AppBar back-arrow) instead of popping the whole route
    // and discarding the entire drill path. Only when already at the top level
    // (empty stack) does Back pop the route. canPop is recomputed every build,
    // so it tracks the stack as the user drills in/out.
    return PopScope(
      canPop: _navigationStack.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        // didPop == false means the pop was blocked (canPop was false because
        // we are drilled in); intercept it to step up one level instead.
        if (!didPop && _navigationStack.isNotEmpty) {
          _navigateUp();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: AppBarTitle(
            child: Text(
              l10n.contentHierarchyBrowseTitle,
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
          actions: [
            IconButton(
              key: const Key('content_hierarchy_search_icon'),
              icon: const Icon(Icons.search),
              tooltip: l10n.contentHierarchySearchTooltip,
              onPressed: () => context.router.push(
                ContentSearchRoute(curriculumId: widget.curriculumId),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Breadcrumb / curriculum chip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  // The curriculum root chip. When the user has drilled in
                  // (navigation stack non-empty) this chip is the only visible
                  // affordance for the *root* level — the breadcrumb below shows
                  // only the drill segments. Tapping it must navigate back to the
                  // curriculum root (clear the stack); previously it was a dead,
                  // non-interactive Container, so tapping the leftmost ancestor
                  // crumb did nothing.
                  _RootCurriculumChip(
                    curriculum: curriculum,
                    color: curriculumColor,
                    onTap: _navigationStack.isNotEmpty ? _navigateToRoot : null,
                  ),
                  if (_navigationStack.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        // R2 finding 4: the root-chip separator must point the
                        // same way as the inner breadcrumb separators. Reuse the
                        // shared direction-aware helper so in RTL it flips to
                        // chevron_left instead of hardcoding chevron_right (which
                        // disagreed with the inner separators in one RTL trail).
                        breadcrumbSeparatorIcon(Directionality.of(context)),
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: configAsync.when(
                        data: (config) {
                          final terms = domainTermLabels(ref);
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
                                useHebrew: terms.isHebrew,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.contentHierarchyNoContent,
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

                  final variant = ref.watch(
                    currentTransliterationVariantProvider,
                  );
                  // Chazara product rule: only show the review badge when at
                  // least one active track in this profile has chazara enabled.
                  final anyChazara =
                      ref
                          .watch(anyActiveTrackHasChazaraProvider)
                          .asData
                          ?.value ??
                      false;
                  final groupedItems = groupItemsByNextLevel(
                    items: items,
                    currentDepth: _navigationStack.length,
                    curriculumId: curriculum,
                    variant: variant,
                    maxBrowseDepth: CurriculumLabels.maxBrowseDepth(curriculum),
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
                        showReviewBadge: anyChazara,
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
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.errorLoadingContent(error.toString()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  /// Navigate back to the curriculum root, clearing the entire drill path.
  ///
  /// Bound to the curriculum root chip. The breadcrumb row only renders the
  /// drill segments, so this chip is the sole tap target for returning to the
  /// top of the hierarchy in a single tap.
  void _navigateToRoot() {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _navigationStack = const [];
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
          result.add(CurriculumLabelRenderer.hebrewNameOf(container));
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
      result.add(CurriculumLabelRenderer.hebrewNameOf(match));
    }
    return result;
  }
}

/// The leftmost breadcrumb chip showing the curriculum root (e.g. "חומש").
///
/// When [onTap] is non-null (i.e. the user has drilled in) the chip is
/// interactive and navigates back to the curriculum root. When null it renders
/// as a static label (at the root there is nowhere further up to go).
class _RootCurriculumChip extends StatelessWidget {
  const _RootCurriculumChip({
    required this.curriculum,
    required this.color,
    required this.onTap,
  });

  final CurriculumId curriculum;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: CurriculumLabel.curriculum(
        curriculum,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );

    if (onTap == null) return chip;

    return InkWell(
      key: const Key('content_hierarchy_root_chip'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: chip,
    );
  }
}
