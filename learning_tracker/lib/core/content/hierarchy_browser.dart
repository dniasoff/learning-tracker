import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';

/// Builds a single tile in the hierarchy list.
///
/// [item] — pre-rendered ContentItem at the current level.
/// [currentPath] — raw navigation stack (raw Sefaria values drilled into so far).
/// [onDrill] — call to drill into this item; null if item is a leaf.
typedef HierarchyTileBuilder =
    Widget Function(
      ContentItem item,
      List<String> currentPath,
      VoidCallback? onDrill,
    );

/// Reusable drill-down hierarchy browser for curriculum content.
///
/// Manages the navigation stack, filters items to the current path,
/// groups them via [groupItemsByNextLevel], and renders via [tileBuilder].
///
/// Content loading and selection are the caller's responsibility. Callers
/// typically:
///   1. Load all items for the curriculum via a Riverpod provider.
///   2. Pass them in as [items].
///   3. Implement [tileBuilder] to render their specific tile UI.
///   4. Use a [GlobalKey] to call [HierarchyBrowserState.navigateBack] from
///      an AppBar back button.
///
/// Lives in `core/content/` so any feature can import it.
class HierarchyBrowser extends ConsumerStatefulWidget {
  const HierarchyBrowser({
    required this.items,
    required this.curriculumId,
    required this.tileBuilder,
    this.filterItems,
    this.onNavigationChanged,
    this.onDisplayItemsChanged,
    this.autoAdvanceSingleOption = false,
    this.emptyBuilder,
    super.key,
  });

  /// All curriculum items (pre-loaded). HierarchyBrowser filters these to
  /// the current path internally.
  final List<ContentItem> items;

  final CurriculumId curriculumId;

  /// Custom tile builder — called for each grouped item in the current level.
  final HierarchyTileBuilder tileBuilder;

  /// Optional filter applied to [items] before path-based filtering (e.g.
  /// scope constraints). Return a subset of the input.
  final List<ContentItem> Function(List<ContentItem>)? filterItems;

  /// Called whenever the navigation path changes.
  ///
  /// [path] — raw level values (e.g. ["Seder Zeraim", "Berakhot"]).
  /// [hebrewNames] — rendered Hebrew display label for each crumb (null for
  /// ordinal levels that have no named Hebrew form).
  final void Function(List<String> path, List<String?> hebrewNames)?
  onNavigationChanged;

  /// Called after every rebuild with the current list of display items (after
  /// path-filtering + grouping). Useful for "select all" buttons that need
  /// to know what's visible.
  final void Function(List<ContentItem> displayItems)? onDisplayItemsChanged;

  /// If true, automatically drills past levels that contain only one option
  /// (mimics the scope-step and bulk-mark auto-advance behaviour).
  final bool autoAdvanceSingleOption;

  /// Widget shown when no items are available at the current level. Defaults
  /// to a centered "No content available" text.
  final WidgetBuilder? emptyBuilder;

  @override
  HierarchyBrowserState createState() => HierarchyBrowserState();
}

class HierarchyBrowserState extends ConsumerState<HierarchyBrowser> {
  List<String> _path = [];
  List<String?> _hebrewNames = [];

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Public API for external callers ──────────────────────────────────────

  /// Navigate up one level. Call from an AppBar back button using a GlobalKey.
  void navigateBack() {
    if (_path.isEmpty) return;
    setState(() {
      _path = _path.sublist(0, _path.length - 1);
      _hebrewNames = _hebrewNames.sublist(0, _hebrewNames.length - 1);
    });
    widget.onNavigationChanged?.call(_path, _hebrewNames);
  }

  /// Reset to the top level.
  void clearNavigation() {
    if (_path.isEmpty) return;
    setState(() {
      _path = [];
      _hebrewNames = [];
    });
    widget.onNavigationChanged?.call(_path, _hebrewNames);
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  void _drillInto(ContentItem item) {
    final depth = _path.length;
    final nextValue = levelValueAt(item, depth + 1);
    if (nextValue == null) return;

    setState(() {
      _path = [..._path, nextValue];
      _hebrewNames = [
        ..._hebrewNames,
        item.displayNameHe.isNotEmpty ? item.displayNameHe : null,
      ];
    });
    widget.onNavigationChanged?.call(_path, _hebrewNames);

    if (widget.autoAdvanceSingleOption) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final variant = ref.read(currentTransliterationVariantProvider);
        final nextItems = groupItemsByNextLevel(
          items: _pathFilteredItems(),
          currentDepth: _path.length,
          curriculumId: widget.curriculumId,
          variant: variant,
        );
        if (nextItems.length == 1 && !nextItems.first.isLeaf) {
          _drillInto(nextItems.first);
        }
      });
    }
  }

  List<ContentItem> _pathFilteredItems() {
    var items = widget.filterItems != null
        ? widget.filterItems!(widget.items)
        : widget.items;
    for (var i = 0; i < _path.length; i++) {
      final level = i + 1;
      final value = _path[i];
      items = items
          .where((item) => levelValueAt(item, level) == value)
          .toList();
    }
    return items;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final variant = ref.watch(currentTransliterationVariantProvider);

    final displayItems = groupItemsByNextLevel(
      items: _pathFilteredItems(),
      currentDepth: _path.length,
      curriculumId: widget.curriculumId,
      variant: variant,
    );

    // Notify caller of the current display items (e.g. for "select all").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDisplayItemsChanged?.call(displayItems);
    });

    if (displayItems.isEmpty) {
      return widget.emptyBuilder != null
          ? widget.emptyBuilder!(context)
          : const Center(child: Text('No content available'));
    }

    final path = _path; // capture for closure
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: displayItems.length,
        itemBuilder: (context, index) {
          final item = displayItems[index];
          final onDrill = item.isLeaf ? null : () => _drillInto(item);
          return widget.tileBuilder(item, path, onDrill);
        },
      ),
    );
  }
}
