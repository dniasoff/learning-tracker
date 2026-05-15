import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/hierarchy_browser.dart';
import 'package:learning_tracker/core/content/hierarchy_selection.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// A self-contained widget that presents a hierarchical content browser with
/// checkboxes, breadcrumb navigation, a selection counter, and Skip/Next buttons.
///
/// Used wherever the user needs to pick content nodes at any depth before
/// confirming a bulk action (e.g. track-setup "prior learning" step).
class HierarchySelectionPanel extends ConsumerStatefulWidget {
  const HierarchySelectionPanel({
    required this.curriculumId,
    required this.onSkip,
    required this.onConfirmed,
    this.scopeConstraints,
    this.skipLabel,
    this.confirmLabel,
    super.key,
  });

  final CurriculumId curriculumId;

  /// Optional scope filter — only items whose level-N value is in this list
  /// are shown. Pass null to show the full curriculum.
  final List<ScopeEntry>? scopeConstraints;

  final VoidCallback onSkip;

  /// Called with the current selection set when the user taps the confirm button.
  final ValueChanged<Set<HierarchySelection>> onConfirmed;

  /// Label for the skip button. Defaults to [AppLocalizations.actionSkipForNow].
  final String? skipLabel;

  /// Label for the confirm button. Defaults to [AppLocalizations.actionNext].
  final String? confirmLabel;

  @override
  ConsumerState<HierarchySelectionPanel> createState() =>
      _HierarchySelectionPanelState();
}

class _HierarchySelectionPanelState
    extends ConsumerState<HierarchySelectionPanel> {
  final _selections = <HierarchySelection>{};
  List<String> _navigationStack = [];
  List<String?> _navigationStackHebrewNames = [];
  final _browserKey = GlobalKey<HierarchyBrowserState>();

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final useHebrew = ref.watch(useHebrewTermsProvider);
    final variant = ref.watch(currentTransliterationVariantProvider);
    final contentAsync = ref.watch(
      curriculumContentProvider(widget.curriculumId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_navigationStack.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              children: [
                for (var i = 0; i < _navigationStack.length; i++)
                  TextButton(
                    onPressed: () {
                      for (var j = _navigationStack.length; j > i + 1; j--) {
                        _browserKey.currentState?.navigateBack();
                      }
                    },
                    child: Text(
                      CurriculumLabelRenderer.renderBreadcrumb(
                        curriculumId: widget.curriculumId,
                        rawSegmentValues: _navigationStack.sublist(0, i + 1),
                        useHebrew: useHebrew,
                        hebrewNamesPerSegment: _navigationStackHebrewNames
                            .sublist(0, i + 1),
                        transliterationVariant: variant,
                      ).last,
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: contentAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(l10n.errorGeneric(e.toString()))),
            data: (allItems) => HierarchyBrowser(
              key: _browserKey,
              items: allItems,
              curriculumId: widget.curriculumId,
              filterItems: _applyScope,
              autoAdvanceSingleOption: true,
              onNavigationChanged: (path, hebrewNames) {
                setState(() {
                  _navigationStack = path;
                  _navigationStackHebrewNames = hebrewNames;
                });
              },
              tileBuilder: (item, currentPath, onDrill) {
                final isSelected = _isItemSelected(item);
                return ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleItem(item, currentPath.length),
                  ),
                  title: CurriculumLabel.item(
                    item,
                    mode: CurriculumLabelMode.leaf,
                    textDirection: useHebrew
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    textAlign: TextAlign.start,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: onDrill != null
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: onDrill ?? () => _toggleItem(item, currentPath.length),
                );
              },
            ),
          ),
        ),
        if (_selections.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '${_selections.length} selection(s)',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onSkip,
                  child: Text(widget.skipLabel ?? l10n.actionSkipForNow),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _selections.isNotEmpty
                      ? () => widget.onConfirmed(Set.of(_selections))
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
