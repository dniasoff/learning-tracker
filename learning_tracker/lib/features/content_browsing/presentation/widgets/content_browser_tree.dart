import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/content_tree.dart';
import 'package:learning_tracker/core/content/hierarchy_selection.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/content_item_tile.dart';

export 'package:learning_tracker/core/content/hierarchy_selection.dart';

/// Which selection mode the tree operates in.
enum ContentBrowserSelectionMode {
  /// Browse-only, no selection — replicates the [ContentHierarchyScreen] body.
  none,

  /// Tap a leaf to select a single item; [ContentBrowserTree.onSelectionChanged]
  /// is emitted with a one-element set.
  single,

  /// Checkboxes for multi-select — replicates the [BulkMarkScreen] list.
  /// Toggling a container selects/deselects all of its children.
  multiCheckbox,
}

/// Reusable content hierarchy browser widget.
///
/// Embeds the drill-down navigation stack from [ContentHierarchyScreen] so
/// any feature can show a browse-tree without duplicating the data-loading
/// logic.
///
/// Layering: lives in `features/content_browsing/presentation/widgets/` and
/// imports only from `core/`. The [HierarchySelection] type is also exported
/// from `core/content/hierarchy_selection.dart`.
class ContentBrowserTree extends ConsumerStatefulWidget {
  const ContentBrowserTree({
    required this.curriculum,
    this.selectionMode = ContentBrowserSelectionMode.none,
    this.initialSelection = const {},
    this.onSelectionChanged,
    this.onNavigationStackChanged,
    super.key,
  });

  final CurriculumId curriculum;
  final ContentBrowserSelectionMode selectionMode;

  /// Initial selection set (for [ContentBrowserSelectionMode.multiCheckbox]).
  final Set<HierarchySelection> initialSelection;

  /// Called whenever the selection changes.
  final void Function(Set<HierarchySelection>)? onSelectionChanged;

  /// Called whenever the internal navigation stack changes (drill-down / up).
  /// Callers can use this to sync an external breadcrumb widget.
  final void Function(List<String> navigationStack)? onNavigationStackChanged;

  @override
  ConsumerState<ContentBrowserTree> createState() => _ContentBrowserTreeState();
}

class _ContentBrowserTreeState extends ConsumerState<ContentBrowserTree> {
  List<String> _navigationStack = [];
  late Set<HierarchySelection> _selections;

  @override
  void initState() {
    super.initState();
    _selections = Set.of(widget.initialSelection);
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  String? _levelAt(int depth) =>
      _navigationStack.length > depth ? _navigationStack[depth] : null;

  void _drillDown(ContentItem item) {
    final depth = _navigationStack.length;
    final nextValue = switch (depth) {
      0 => item.level1,
      1 => item.level2,
      2 => item.level3,
      3 => item.level4,
      _ => null,
    };
    if (nextValue != null) {
      setState(() {
        _navigationStack = [..._navigationStack, nextValue];
      });
      widget.onNavigationStackChanged?.call(_navigationStack);
    }
  }

  void navigateUp() {
    if (_navigationStack.isNotEmpty) {
      setState(() {
        _navigationStack = _navigationStack.sublist(
          0,
          _navigationStack.length - 1,
        );
      });
      widget.onNavigationStackChanged?.call(_navigationStack);
    }
  }

  // ── Selection helpers ─────────────────────────────────────────────────────

  HierarchySelection _selectionForItem(ContentItem item) {
    final depth = _navigationStack.length;
    return HierarchySelection(
      level1: item.level1,
      level2: depth >= 1 ? item.level2 : null,
      level3: depth >= 2 ? item.level3 : null,
      level4: depth >= 3 ? item.level4 : null,
    );
  }

  bool _isItemSelected(ContentItem item) {
    return _selections.any((s) {
      if (s.level1 != null && s.level1 != item.level1) return false;
      if (s.level2 != null && s.level2 != item.level2) return false;
      if (s.level3 != null && s.level3 != item.level3) return false;
      if (s.level4 != null && s.level4 != item.level4) return false;
      return true;
    });
  }

  void _toggleItem(ContentItem item) {
    final sel = _selectionForItem(item);
    setState(() {
      if (_isItemSelected(item)) {
        _selections.removeWhere((s) {
          if (s.level1 != null && s.level1 != item.level1) return false;
          if (s.level2 != null && s.level2 != item.level2) return false;
          if (s.level3 != null && s.level3 != item.level3) return false;
          if (s.level4 != null && s.level4 != item.level4) return false;
          return true;
        });
      } else {
        // Add this selection; remove redundant narrower selections covered by it.
        _selections.removeWhere((s) {
          if (sel.level1 != null && sel.level1 != s.level1) return false;
          if (sel.level2 != null && sel.level2 != s.level2) return false;
          if (sel.level3 != null && sel.level3 != s.level3) return false;
          if (sel.level4 != null && sel.level4 != s.level4) return false;
          return true;
        });
        _selections.add(sel);
      }
    });
    widget.onSelectionChanged?.call(Set.of(_selections));
  }

  // ── Item grouping ──────────────────────────────────────────────────────────

  List<ContentItem> _groupItems(
    List<ContentItem> items,
    TransliterationVariant variant, {
    bool capped = false,
  }) => groupItemsByNextLevel(
    items: items,
    currentDepth: _navigationStack.length,
    curriculumId: widget.curriculum,
    variant: variant,
    maxBrowseDepth: capped
        ? CurriculumLabels.maxBrowseDepth(widget.curriculum)
        : null,
  );

  bool _isChapterLevelRef(ContentItem item) {
    final maxDepth = CurriculumLabels.maxBrowseDepth(widget.curriculum);
    if (maxDepth >= CurriculumLabels.depth(widget.curriculum)) return false;
    final itemDepth = item.level4 != null
        ? 4
        : item.level3 != null
        ? 3
        : item.level2 != null
        ? 2
        : 1;
    return itemDepth == maxDepth;
  }

  void _handleNoneTap(ContentItem item) {
    if (item.isLeaf || _isChapterLevelRef(item)) {
      context.router.push(TextDisplayRoute(sefariaRef: item.sefariaRef));
    } else {
      _drillDown(item);
    }
  }

  void _handleSingleTap(ContentItem item) {
    if (item.isLeaf || _isChapterLevelRef(item)) {
      final sel = HierarchySelection(
        level1: item.level1,
        level2: item.level2,
        level3: item.level3,
        level4: item.level4,
      );
      widget.onSelectionChanged?.call({sel});
    } else {
      _drillDown(item);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Resolve items via ContentTree (fast path) with filteredContentProvider
    // fallback — mirrors ContentHierarchyScreen.build().
    final treeAsync = ref.watch(contentTreeProvider);
    final itemsAsync = treeAsync.when(
      data: (tree) {
        final children = tree.children(widget.curriculum, _navigationStack);
        if (children.isEmpty && _navigationStack.isNotEmpty) {
          return ref.watch(
            filteredContentProvider(
              curriculumId: widget.curriculum,
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
          curriculumId: widget.curriculum,
          level1: _levelAt(0),
          level2: _levelAt(1),
          level3: _levelAt(2),
          level4: _levelAt(3),
        ),
      ),
    );

    return itemsAsync.when(
      data: (items) => _buildList(context, items),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error loading content: $error')),
    );
  }

  Widget _buildList(BuildContext context, List<ContentItem> items) {
    return switch (widget.selectionMode) {
      ContentBrowserSelectionMode.none => _buildNoneList(context, items),
      ContentBrowserSelectionMode.single => _buildSingleList(context, items),
      ContentBrowserSelectionMode.multiCheckbox => _buildMultiList(
        context,
        items,
      ),
    };
  }

  Widget _buildNoneList(BuildContext context, List<ContentItem> items) {
    final variant = ref.watch(currentTransliterationVariantProvider);
    final displayItems = _groupItems(items, variant, capped: true);

    if (displayItems.isEmpty) {
      return const Center(child: Text('No content available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final item = displayItems[index];
        return ContentItemTile(
          item: item,
          curriculum: widget.curriculum,
          onTap: () => _handleNoneTap(item),
        );
      },
    );
  }

  Widget _buildSingleList(BuildContext context, List<ContentItem> items) {
    final variant = ref.watch(currentTransliterationVariantProvider);
    final displayItems = _groupItems(items, variant, capped: true);

    if (displayItems.isEmpty) {
      return const Center(child: Text('No content available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final item = displayItems[index];
        return ContentItemTile(
          item: item,
          curriculum: widget.curriculum,
          onTap: () => _handleSingleTap(item),
        );
      },
    );
  }

  Widget _buildMultiList(BuildContext context, List<ContentItem> items) {
    final theme = Theme.of(context);
    final variant = ref.watch(currentTransliterationVariantProvider);
    final displayItems = _groupItems(items, variant);

    if (displayItems.isEmpty) {
      return const Center(child: Text('No content available'));
    }

    return ListView.builder(
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final item = displayItems[index];
        final isSelected = _isItemSelected(item);
        return ListTile(
          leading: Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleItem(item),
          ),
          title: CurriculumLabel.item(
            item,
            mode: CurriculumLabelMode.leaf,
            textAlign: TextAlign.start,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          trailing: item.isLeaf ? null : const Icon(Icons.chevron_right),
          onTap: item.isLeaf ? () => _toggleItem(item) : () => _drillDown(item),
        );
      },
    );
  }
}
