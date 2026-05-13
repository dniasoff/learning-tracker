import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/scope_views.dart';
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
  final List<ScopeEntry> _selections = [];
  bool _didAutoSkip = false;

  List<String> get _levelLabels =>
      CurriculumLabels.labelsEn(widget.curriculumId);

  int get _maxLevels => CurriculumLabels.depth(widget.curriculumId);

  int get _currentLevel =>
      _breadcrumbs.isEmpty ? 1 : _breadcrumbs.last.level + 1;

  int get _maxSelectableLevel => _maxLevels - 1;

  String _labelForLevel(int level) {
    return level <= _levelLabels.length
        ? _levelLabels[level - 1]
        : 'Level $level';
  }

  String? _getItemLevel(ContentItem item, int level) {
    return switch (level) {
      1 => item.level1,
      2 => item.level2,
      3 => item.level3,
      4 => item.level4,
      _ => null,
    };
  }

  List<String> _valuesAtCurrentLevel(List<ContentItem> items) {
    var filtered = items;
    for (final crumb in _breadcrumbs) {
      filtered = filtered
          .where((item) => _getItemLevel(item, crumb.level) == crumb.value)
          .toList();
    }
    final seen = <String>{};
    final result = <String>[];
    for (final item in filtered) {
      final value = _getItemLevel(item, _currentLevel);
      if (value != null && seen.add(value)) result.add(value);
    }
    return result;
  }

  bool _isSelected(String value) {
    if (_selections.any((s) => s.level == _currentLevel && s.value == value)) {
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

  bool _isDirectlySelected(String value) {
    return _selections.any((s) => s.level == _currentLevel && s.value == value);
  }

  void _toggleSelection(String value) {
    setState(() {
      final existing = _selections.indexWhere(
        (s) => s.level == _currentLevel && s.value == value,
      );
      if (existing >= 0) {
        _selections.removeAt(existing);
      } else {
        _selections.removeWhere((s) => s.level > _currentLevel);
        _selections.add(ScopeEntry(level: _currentLevel, value: value));
      }
    });
  }

  void _drillInto(String value, List<ContentItem> items) {
    final nextLevel = _currentLevel + 1;
    if (nextLevel > _maxSelectableLevel) return;
    setState(() {
      _breadcrumbs.add(ScopeEntry(level: _currentLevel, value: value));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nextValues = _valuesAtCurrentLevel(items);
      if (nextValues.length == 1 && _currentLevel < _maxSelectableLevel) {
        _drillInto(nextValues.first, items);
      }
    });
  }

  void _goBack() {
    setState(() {
      if (_breadcrumbs.isNotEmpty) _breadcrumbs.removeLast();
    });
  }

  void _done() {
    if (_selections.isEmpty) {
      widget.onComplete(null);
    } else {
      widget.onComplete(List.of(_selections));
    }
  }

  bool _allValuesDirectlySelected(List<String> values) {
    if (values.isEmpty) return false;
    return values.every(_isDirectlySelected);
  }

  void _toggleSelectAllCurrentLevel(List<ContentItem> items) {
    final values = _valuesAtCurrentLevel(items);
    if (values.isEmpty) return;
    setState(() {
      if (_allValuesDirectlySelected(values)) {
        for (final v in values) {
          _selections.removeWhere(
            (s) => s.level == _currentLevel && s.value == v,
          );
        }
      } else {
        _selections.removeWhere((s) => s.level > _currentLevel);
        for (final v in values) {
          if (!_selections.any(
            (s) => s.level == _currentLevel && s.value == v,
          )) {
            _selections.add(ScopeEntry(level: _currentLevel, value: v));
          }
        }
      }
    });
  }

  int _childCountForValue(List<ContentItem> items, String value) {
    final nextLevel = _currentLevel + 1;
    if (nextLevel > _maxLevels) return 0;
    final seen = <String>{};
    for (final item in items) {
      var matches = true;
      for (final crumb in _breadcrumbs) {
        if (_getItemLevel(item, crumb.level) != crumb.value) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      if (_getItemLevel(item, _currentLevel) != value) continue;
      final child = _getItemLevel(item, nextLevel);
      if (child != null) seen.add(child);
    }
    return seen.length;
  }

  String _scopeDescription(String value) {
    if (widget.curriculumId == CurriculumId.mishnayos) {
      return switch (value.toLowerCase()) {
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

  IconData _scopeIcon(String value) {
    final normalized = value.toLowerCase();
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
                color: const Color(0xFFE5E9FF),
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
              data: (items) {
                if (items.isEmpty) {
                  if (!_didAutoSkip) {
                    _didAutoSkip = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      widget.onComplete(null);
                    });
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                final values = _valuesAtCurrentLevel(items);
                if (_breadcrumbs.isEmpty) {
                  return ScopeTopLevelView(
                    curriculumId: widget.curriculumId,
                    values: values,
                    selections: _selections,
                    allDirectlySelected: _allValuesDirectlySelected(values),
                    currentLevel: _currentLevel,
                    maxSelectableLevel: _maxSelectableLevel,
                    labelForLevel: _labelForLevel,
                    scopeDescription: _scopeDescription,
                    scopeIcon: _scopeIcon,
                    childCountForValue: (v) => _childCountForValue(items, v),
                    isDirectlySelected: _isDirectlySelected,
                    onLearnAll: () => widget.onComplete(null),
                    onToggle: _toggleSelection,
                    onDrill: (v) => _drillInto(v, items),
                    onToggleAll: () => _toggleSelectAllCurrentLevel(items),
                    onDone: _done,
                  );
                }
                return ScopeHierarchyView(
                  curriculumId: widget.curriculumId,
                  breadcrumbs: _breadcrumbs,
                  values: values,
                  selections: _selections,
                  allDirectlySelected: _allValuesDirectlySelected(values),
                  currentLevel: _currentLevel,
                  maxSelectableLevel: _maxSelectableLevel,
                  labelForLevel: _labelForLevel,
                  isSelected: _isSelected,
                  isDirectlySelected: _isDirectlySelected,
                  onToggle: _toggleSelection,
                  onDrill: (v) => _drillInto(v, items),
                  onToggleAll: () => _toggleSelectAllCurrentLevel(items),
                  onBack: _goBack,
                  onClearBreadcrumbs: () =>
                      setState(() => _breadcrumbs.clear()),
                  onTrimBreadcrumbs: (upToIndex) => setState(
                    () => _breadcrumbs.removeRange(
                      upToIndex,
                      _breadcrumbs.length,
                    ),
                  ),
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
