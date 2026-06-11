import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/hierarchy_browser.dart';
import 'package:learning_tracker/core/content/hierarchy_selection.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// A self-contained widget that loads curriculum content, shows a breadcrumb
/// navigation bar, renders a [HierarchyBrowser], and provides action buttons.
///
/// **Default mode** (no [tileBuilder] / [bottomActions]):
/// - Checkbox tiles with internal [Set<HierarchySelection>] selection management.
/// - Skip / Confirm buttons driven by [onSkip] and [onConfirmed].
///
/// **Custom mode** ([tileBuilder] and/or [bottomActions] provided):
/// - Caller supplies tile rendering and action buttons.
/// - Use a [GlobalKey<HierarchySelectionPanelState>] to call
///   [HierarchySelectionPanelState.navigateBack] from an AppBar back button.
/// - [onNavigationChanged] and [onDisplayItemsChanged] keep the caller in sync
///   with navigation state and visible items.
class HierarchySelectionPanel extends ConsumerStatefulWidget {
  const HierarchySelectionPanel({
    required this.curriculumId,
    this.scopeConstraints,
    this.onSkip,
    this.onConfirmed,
    this.skipLabel,
    this.confirmLabel,
    this.tileBuilder,
    this.bottomActions,
    this.onNavigationChanged,
    this.onDisplayItemsChanged,
    this.autoAdvanceSingleOption = true,
    super.key,
  });

  final CurriculumId curriculumId;

  /// Optional scope filter — only items whose level-N value is in this list
  /// are shown. Pass null to show the full curriculum.
  final List<ScopeEntry>? scopeConstraints;

  // ── Default-mode callbacks (used when [bottomActions] is null) ────────────

  final VoidCallback? onSkip;
  final ValueChanged<Set<HierarchySelection>>? onConfirmed;
  final String? skipLabel;
  final String? confirmLabel;

  // ── Custom-mode overrides ─────────────────────────────────────────────────

  /// Custom tile builder. When non-null, internal checkbox selection is
  /// disabled and no selection counter is shown.
  final HierarchyTileBuilder? tileBuilder;

  /// Widget shown below the browser. When non-null, replaces the default
  /// Skip / Confirm row.
  final WidgetBuilder? bottomActions;

  /// Notified whenever the navigation stack changes. Use to update an AppBar
  /// back button or external breadcrumb UI.
  final void Function(List<String> path, List<String?> hebrewNames)?
  onNavigationChanged;

  /// Notified after every render with the items currently visible at this
  /// level. Use to implement "select all visible" functionality.
  final void Function(List<ContentItem> items)? onDisplayItemsChanged;

  /// Whether to skip past levels with a single option automatically.
  /// Defaults to true (keeps the original track-setup behaviour).
  final bool autoAdvanceSingleOption;

  @override
  HierarchySelectionPanelState createState() => HierarchySelectionPanelState();
}

class HierarchySelectionPanelState
    extends ConsumerState<HierarchySelectionPanel> {
  final _selections = <HierarchySelection>{};
  List<String> _navigationStack = [];
  List<String?> _navigationStackHebrewNames = [];
  final _browserKey = GlobalKey<HierarchyBrowserState>();

  // ── Public API ─────────────────────────────────────────────────────────────

  void navigateBack() => _browserKey.currentState?.navigateBack();
  void clearNavigation() => _browserKey.currentState?.clearNavigation();
  bool get canGoBack => _navigationStack.isNotEmpty;

  // ── Internal helpers ───────────────────────────────────────────────────────

  List<ContentItem> _applyScope(List<ContentItem> items) {
    final scopes = widget.scopeConstraints;
    if (scopes == null || scopes.isEmpty) return items;
    final level = scopes.first.level;
    final values = scopes.map((s) => s.value).toSet();
    return items.where((item) {
      final v = levelValueAt(item, level);
      return v != null && values.contains(v);
    }).toList();
  }

  HierarchySelection _selectionForItem(ContentItem item, int depth) {
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

  void _toggleItem(ContentItem item, int depth) {
    setState(() {
      final sel = _selectionForItem(item, depth);
      if (_isItemSelected(item)) {
        _selections.removeWhere((s) {
          if (s.level1 != null && s.level1 != item.level1) return false;
          if (s.level2 != null && s.level2 != item.level2) return false;
          if (s.level3 != null && s.level3 != item.level3) return false;
          if (s.level4 != null && s.level4 != item.level4) return false;
          return true;
        });
      } else {
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
  }

  void _handleNavChanged(List<String> path, List<String?> hebrewNames) {
    setState(() {
      _navigationStack = path;
      _navigationStackHebrewNames = hebrewNames;
    });
    widget.onNavigationChanged?.call(path, hebrewNames);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final terms = domainTermLabels(ref);
    final variant = ref.watch(currentTransliterationVariantProvider);
    final contentAsync = ref.watch(
      curriculumContentProvider(widget.curriculumId),
    );

    final useDefaultTiles = widget.tileBuilder == null;

    final effectiveTileBuilder =
        widget.tileBuilder ??
        (ContentItem item, List<String> currentPath, VoidCallback? onDrill) {
          final isSelected = _isItemSelected(item);
          return ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleItem(item, currentPath.length),
            ),
            title: CurriculumLabel.item(
              item,
              mode: CurriculumLabelMode.leaf,
              textAlign: TextAlign.start,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: onDrill != null ? const Icon(Icons.chevron_right) : null,
            onTap: onDrill ?? () => _toggleItem(item, currentPath.length),
          );
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_navigationStack.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: clearNavigation,
                  child: CurriculumLabel.curriculum(widget.curriculumId),
                ),
                for (var i = 0; i < _navigationStack.length; i++) ...[
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  TextButton(
                    onPressed: i < _navigationStack.length - 1
                        ? () {
                            for (
                              var j = _navigationStack.length;
                              j > i + 1;
                              j--
                            ) {
                              _browserKey.currentState?.navigateBack();
                            }
                          }
                        : null,
                    child: Text(
                      CurriculumLabelRenderer.renderBreadcrumb(
                        curriculumId: widget.curriculumId,
                        rawSegmentValues: _navigationStack.sublist(0, i + 1),
                        useHebrew: terms.isHebrew,
                        hebrewNamesPerSegment: _navigationStackHebrewNames
                            .sublist(0, i + 1),
                        transliterationVariant: variant,
                      ).last,
                    ),
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: contentAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => AppErrorView(
              error: e,
              stackTrace: st,
              onRetry: () =>
                  ref.refresh(curriculumContentProvider(widget.curriculumId)),
            ),
            data: (allItems) => HierarchyBrowser(
              key: _browserKey,
              items: allItems,
              curriculumId: widget.curriculumId,
              filterItems: _applyScope,
              autoAdvanceSingleOption: widget.autoAdvanceSingleOption,
              onNavigationChanged: _handleNavChanged,
              onDisplayItemsChanged: widget.onDisplayItemsChanged,
              tileBuilder: effectiveTileBuilder,
            ),
          ),
        ),
        if (useDefaultTiles && _selections.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              // IL-9: use localized plural form instead of raw "selection(s)".
              AppLocalizations.of(context)!.selectionCount(_selections.length),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        if (widget.bottomActions != null)
          widget.bottomActions!(context)
        else if (widget.onSkip != null || widget.onConfirmed != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (widget.onSkip != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onSkip,
                      child: Text(widget.skipLabel ?? l10n.actionSkipForNow),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (widget.onConfirmed != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: _selections.isNotEmpty
                          ? () => widget.onConfirmed!(Set.of(_selections))
                          : null,
                      child: Text(widget.confirmLabel ?? l10n.actionNext),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
