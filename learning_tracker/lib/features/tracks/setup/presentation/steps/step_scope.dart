import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/scope_views.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Hierarchical scope selector — drill down through the content tree
/// (e.g. Seder → Masechta → Perek) and select at any level.
///
/// Selecting at a higher level implicitly includes all children.
/// Auto-skips levels with only one option (DNI-202).
class ScopeStepContent extends ConsumerStatefulWidget {
  const ScopeStepContent({
    required this.curriculumId,
    required this.onComplete,
    super.key,
  });

  final CurriculumId curriculumId;
  final ValueChanged<List<ScopeEntry>?> onComplete;

  @override
  ConsumerState<ScopeStepContent> createState() => _ScopeStepContentState();
}

class _ScopeStepContentState extends ConsumerState<ScopeStepContent> {
  final List<ScopeEntry> _breadcrumbs = [];
  final List<String> _breadcrumbLabels = []; // parallel rendered labels
  final List<ScopeEntry> _selections = [];
  final Map<String, String> _selectionLabels = {}; // rawValue → rendered label
  bool _didAutoSkip = false;

  int get _maxLevels => CurriculumLabels.depth(widget.curriculumId);

  int get _currentLevel =>
      _breadcrumbs.isEmpty ? 1 : _breadcrumbs.last.level + 1;

  int get _maxSelectableLevel => _maxLevels - 1;

  String _labelForLevel(
    int level, {
    required bool useHebrew,
    required TransliterationVariant variant,
  }) {
    final levels = CurriculumLabels.levels(widget.curriculumId);
    return level <= levels.length
        ? levels[level - 1].inLanguage(useHebrew: useHebrew, variant: variant)
        : 'Level $level';
  }

  /// Filters [allItems] to those matching the current breadcrumb path.
  List<ContentItem> _filteredToCurrentPath(List<ContentItem> allItems) {
    var filtered = allItems;
    for (final crumb in _breadcrumbs) {
      filtered = filtered
          .where((item) => levelValueAt(item, crumb.level) == crumb.value)
          .toList();
    }
    return filtered;
  }

  bool _isRawSelected(String rawValue) {
    if (_selections.any(
      (s) => s.level == _currentLevel && s.value == rawValue,
    )) {
      return true;
    }
    for (final crumb in _breadcrumbs) {
      if (_selections.any(
        (s) => s.level == crumb.level && s.value == crumb.value,
      )) {
        return true;
      }
    }
    return false;
  }

  bool _isRawDirectlySelected(String rawValue) =>
      _selections.any((s) => s.level == _currentLevel && s.value == rawValue);

  bool _isItemSelected(ContentItem item) =>
      _isRawSelected(levelValueAt(item, _currentLevel) ?? '');

  bool _isItemDirectlySelected(ContentItem item) =>
      _isRawDirectlySelected(levelValueAt(item, _currentLevel) ?? '');

  void _toggleItem(ContentItem item, bool useHebrew) {
    final rawValue = levelValueAt(item, _currentLevel) ?? '';
    final label = itemDisplayName(item, useHebrew: useHebrew);
    setState(() {
      final idx = _selections.indexWhere(
        (s) => s.level == _currentLevel && s.value == rawValue,
      );
      if (idx >= 0) {
        _selections.removeAt(idx);
      } else {
        _selections.removeWhere((s) => s.level > _currentLevel);
        _selections.add(ScopeEntry(level: _currentLevel, value: rawValue));
        _selectionLabels[rawValue] = label;
      }
    });
  }

  void _drillInto(
    ContentItem item,
    List<ContentItem> allItems,
    bool useHebrew,
  ) {
    final rawValue = levelValueAt(item, _currentLevel) ?? '';
    final label = itemDisplayName(item, useHebrew: useHebrew);
    final nextLevel = _currentLevel + 1;
    if (nextLevel > _maxSelectableLevel) return;
    setState(() {
      _breadcrumbs.add(ScopeEntry(level: _currentLevel, value: rawValue));
      _breadcrumbLabels.add(label);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final variant = ref.read(currentTransliterationVariantProvider);
      final filtered = _filteredToCurrentPath(allItems);
      final nextItems = groupItemsByNextLevel(
        items: filtered,
        currentDepth: _breadcrumbs.length,
        curriculumId: widget.curriculumId,
        variant: variant,
      );
      if (nextItems.length == 1 && _currentLevel < _maxSelectableLevel) {
        _drillInto(nextItems.first, allItems, useHebrew);
      }
    });
  }

  void _goBack() {
    setState(() {
      if (_breadcrumbs.isNotEmpty) {
        _breadcrumbs.removeLast();
        _breadcrumbLabels.removeLast();
      }
    });
  }

  void _done() {
    if (_selections.isEmpty) {
      widget.onComplete(null);
    } else {
      widget.onComplete(List.of(_selections));
    }
  }

  bool _allItemsDirectlySelected(List<ContentItem> items) {
    if (items.isEmpty) return false;
    return items.every(_isItemDirectlySelected);
  }

  void _toggleSelectAll(List<ContentItem> displayItems, bool useHebrew) {
    if (displayItems.isEmpty) return;
    setState(() {
      if (_allItemsDirectlySelected(displayItems)) {
        for (final item in displayItems) {
          final rawValue = levelValueAt(item, _currentLevel) ?? '';
          _selections.removeWhere(
            (s) => s.level == _currentLevel && s.value == rawValue,
          );
        }
      } else {
        _selections.removeWhere((s) => s.level > _currentLevel);
        for (final item in displayItems) {
          final rawValue = levelValueAt(item, _currentLevel) ?? '';
          if (!_selections.any(
            (s) => s.level == _currentLevel && s.value == rawValue,
          )) {
            _selections.add(ScopeEntry(level: _currentLevel, value: rawValue));
            _selectionLabels[rawValue] = itemDisplayName(
              item,
              useHebrew: useHebrew,
            );
          }
        }
      }
    });
  }

  int _childCountForItem(List<ContentItem> allItems, ContentItem item) {
    final rawValue = levelValueAt(item, _currentLevel) ?? '';
    final nextLevel = _currentLevel + 1;
    if (nextLevel > _maxLevels) return 0;
    final seen = <String>{};
    for (final allItem in allItems) {
      var matches = true;
      for (final crumb in _breadcrumbs) {
        if (levelValueAt(allItem, crumb.level) != crumb.value) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      if (levelValueAt(allItem, _currentLevel) != rawValue) continue;
      final child = levelValueAt(allItem, nextLevel);
      if (child != null) seen.add(child);
    }
    return seen.length;
  }

  String _scopeDescription(String rawValue) {
    if (widget.curriculumId == CurriculumId.mishnayos) {
      return switch (rawValue.toLowerCase()) {
        'seder zeraim' => 'Seeds & Agriculture',
        'seder moed' => 'Festivals & Sabbaths',
        'seder nashim' => 'Women & Marriage',
        'seder nezikin' => 'Damages & Civil Law',
        'seder kodashim' => 'Temple Service & Sacrifices',
        'seder taharos' => 'Purity & Ritual Law',
        _ => 'Core section focus',
      };
    }
    return 'Core section focus';
  }

  IconData _scopeIcon(String rawValue) {
    final normalized = rawValue.toLowerCase();
    if (normalized.contains('zeraim')) return Icons.eco_rounded;
    if (normalized.contains('moed')) return Icons.calendar_month_rounded;
    if (normalized.contains('nashim')) return Icons.family_restroom_rounded;
    if (normalized.contains('nezikin')) return Icons.balance_rounded;
    if (normalized.contains('kodashim')) return Icons.temple_buddhist_rounded;
    if (normalized.contains('taharos')) return Icons.water_drop_rounded;
    return Icons.book_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final contentAsync = ref.watch(
      curriculumContentProvider(widget.curriculumId),
    );
    final useHebrew = domainTermLabels(ref).isHebrew;
    final variant = ref.watch(currentTransliterationVariantProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.selfPacedScopeTitle,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceBlueLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      size: 15,
                      color: AppTheme.brandBlueDeep,
                    ),
                    const SizedBox(width: 6),
                    CurriculumLabel.curriculum(
                      widget.curriculumId,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.brandBlueDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: contentAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) {
                if (!_didAutoSkip) {
                  _didAutoSkip = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onComplete(null);
                  });
                }
                return const Center(child: CircularProgressIndicator());
              },
              data: (allItems) {
                if (allItems.isEmpty) {
                  if (!_didAutoSkip) {
                    _didAutoSkip = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      widget.onComplete(null);
                    });
                  }
                  return const Center(child: CircularProgressIndicator());
                }

                final filtered = _filteredToCurrentPath(allItems);
                final displayItems = groupItemsByNextLevel(
                  items: filtered,
                  currentDepth: _breadcrumbs.length,
                  curriculumId: widget.curriculumId,
                  variant: variant,
                );

                if (_breadcrumbs.isEmpty) {
                  return ScopeTopLevelView(
                    curriculumId: widget.curriculumId,
                    items: displayItems,
                    useHebrew: useHebrew,
                    selections: _selections,
                    allDirectlySelected: _allItemsDirectlySelected(
                      displayItems,
                    ),
                    currentLevel: _currentLevel,
                    maxSelectableLevel: _maxSelectableLevel,
                    labelForLevel: (level) => _labelForLevel(
                      level,
                      useHebrew: useHebrew,
                      variant: variant,
                    ),
                    scopeDescription: _scopeDescription,
                    scopeIcon: _scopeIcon,
                    childCountForItem: (item) =>
                        _childCountForItem(allItems, item),
                    isDirectlySelected: _isItemDirectlySelected,
                    onLearnAll: () => widget.onComplete(null),
                    onToggle: (item) => _toggleItem(item, useHebrew),
                    onDrill: (item) => _drillInto(item, allItems, useHebrew),
                    onToggleAll: () =>
                        _toggleSelectAll(displayItems, useHebrew),
                    onDone: _done,
                  );
                }
                return ScopeHierarchyView(
                  curriculumId: widget.curriculumId,
                  breadcrumbs: _breadcrumbs,
                  breadcrumbLabels: _breadcrumbLabels,
                  items: displayItems,
                  useHebrew: useHebrew,
                  selections: _selections,
                  selectionLabels: _selectionLabels,
                  allDirectlySelected: _allItemsDirectlySelected(displayItems),
                  currentLevel: _currentLevel,
                  maxSelectableLevel: _maxSelectableLevel,
                  labelForLevel: (level) => _labelForLevel(
                    level,
                    useHebrew: useHebrew,
                    variant: variant,
                  ),
                  isSelected: _isItemSelected,
                  isDirectlySelected: _isItemDirectlySelected,
                  onToggle: (item) => _toggleItem(item, useHebrew),
                  onDrill: (item) => _drillInto(item, allItems, useHebrew),
                  onToggleAll: () => _toggleSelectAll(displayItems, useHebrew),
                  onBack: _goBack,
                  onClearBreadcrumbs: () => setState(() {
                    _breadcrumbs.clear();
                    _breadcrumbLabels.clear();
                  }),
                  onTrimBreadcrumbs: (upToIndex) => setState(() {
                    _breadcrumbs.removeRange(upToIndex, _breadcrumbs.length);
                    _breadcrumbLabels.removeRange(
                      upToIndex,
                      _breadcrumbLabels.length,
                    );
                  }),
                  onRemoveSelection: (s) =>
                      setState(() => _selections.remove(s)),
                  onDone: _done,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
