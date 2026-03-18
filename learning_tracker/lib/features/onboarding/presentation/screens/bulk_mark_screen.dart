import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/stages/presentation/providers/stage_providers.dart';

/// Result returned from the bulk mark screen.
class BulkMarkResult {
  final int itemCount;
  final int completionCount;

  const BulkMarkResult({
    required this.itemCount,
    required this.completionCount,
  });
}

/// Screen for bulk-marking prior completions during onboarding.
///
/// Allows users to browse the content hierarchy and select items they've
/// already completed. Selecting at a higher level (e.g., seder) automatically
/// includes all items within.
class BulkMarkScreen extends ConsumerStatefulWidget {
  final CurriculumId curriculumId;

  const BulkMarkScreen({super.key, required this.curriculumId});

  @override
  ConsumerState<BulkMarkScreen> createState() => _BulkMarkScreenState();
}

enum _Phase { selection, stageSelection, confirmation, processing, done }

class _BulkMarkScreenState extends ConsumerState<BulkMarkScreen> {
  var _phase = _Phase.selection;
  final _selections = <HierarchySelection>{};
  final _selectedStageIds = <int>{};
  List<ContentItem>? _resolvedItems;
  BulkPriorCompletionResult? _result;
  String? _error;

  // Search state
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  // Per-stage marking: maps each selection to its own stage set
  final _perSelectionStages = <HierarchySelection, Set<int>>{};

  // Navigation stack for hierarchy browsing within selection
  List<String> _navigationStack = [];

  String? get _currentLevel1 =>
      _navigationStack.isNotEmpty ? _navigationStack[0] : null;
  String? get _currentLevel2 =>
      _navigationStack.length > 1 ? _navigationStack[1] : null;
  String? get _currentLevel3 =>
      _navigationStack.length > 2 ? _navigationStack[2] : null;

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
    // Check if this specific item or any ancestor is selected
    if (item.isLeaf) {
      // Check exact match or any ancestor level
      return _selections.any((s) {
        if (s.level1 != null && s.level1 != item.level1) return false;
        if (s.level2 != null && s.level2 != item.level2) return false;
        if (s.level3 != null && s.level3 != item.level3) return false;
        if (s.level4 != null && s.level4 != item.level4) return false;
        return true;
      });
    }
    // For containers, check if this exact container is selected
    final sel = _selectionForItem(item);
    return _selections.contains(sel);
  }

  void _toggleItem(ContentItem item) {
    setState(() {
      final sel = _selectionForItem(item);
      if (_selections.contains(sel)) {
        _selections.remove(sel);
      } else {
        _selections.add(sel);
      }
    });
  }

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
    }
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _proceedToStageSelection() async {
    if (_selections.isEmpty) return;

    final service = ref.read(bulkPriorCompletionServiceProvider);
    final resolved = await service.resolveSelections(
      curriculumId: widget.curriculumId,
      selections: _selections.toList(),
    );

    setState(() {
      _resolvedItems = resolved;
      _phase = _Phase.stageSelection;
      // Initialize per-selection stage maps with stage 1 (Learn) as default
      for (final sel in _selections) {
        _perSelectionStages.putIfAbsent(sel, () => {1});
      }
      // Also keep the global set for backward compat
      _selectedStageIds.add(1);
    });
  }

  Future<void> _proceedToConfirmation() async {
    // Validate at least one selection has stages
    final hasStages = _perSelectionStages.values.any((s) => s.isNotEmpty);
    if (!hasStages) return;
    setState(() => _phase = _Phase.confirmation);
  }

  Future<void> _executeBulkMark() async {
    if (_resolvedItems == null) return;

    setState(() => _phase = _Phase.processing);

    try {
      final service = ref.read(bulkPriorCompletionServiceProvider);
      var totalItems = 0;
      var totalCompletions = 0;
      String? bookmarkRef;

      // Execute per-selection-group with their own stage sets
      for (final entry in _perSelectionStages.entries) {
        final selection = entry.key;
        final stageIds = entry.value.toList()..sort();
        if (stageIds.isEmpty) continue;

        final groupItems = await service.resolveSelections(
          curriculumId: widget.curriculumId,
          selections: [selection],
        );
        if (groupItems.isEmpty) continue;

        final result = await service.execute(
          curriculumId: widget.curriculumId,
          resolvedItems: groupItems,
          stageIds: stageIds,
        );
        totalItems += result.itemCount;
        totalCompletions += result.completionCount;
        bookmarkRef ??= result.bookmarkSefariaRef;
      }

      setState(() {
        _result = BulkPriorCompletionResult(
          itemCount: totalItems,
          completionCount: totalCompletions,
          bookmarkSefariaRef: bookmarkRef,
        );
        _phase = _Phase.done;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _phase = _Phase.confirmation;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search content...',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : AppBarTitle(
                text:
                    'Mark Prior Completions — ${widget.curriculumId.displayNameEn}',
              ),
        leading: _phase == _Phase.selection && _navigationStack.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _navigateUp,
              )
            : null,
        actions: [
          if (_phase == _Phase.selection)
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = '';
                  }
                });
              },
            ),
        ],
      ),
      body: switch (_phase) {
        _Phase.selection => _buildSelection(theme),
        _Phase.stageSelection => _buildStageSelection(theme),
        _Phase.confirmation => _buildConfirmation(theme),
        _Phase.processing => _buildProcessing(theme),
        _Phase.done => _buildDone(theme),
      },
    );
  }

  Widget _buildSelection(ThemeData theme) {
    final configAsync = ref.watch(
      curriculumHierarchyConfigProvider(widget.curriculumId),
    );

    // Use search results when searching, hierarchy browsing otherwise
    final isSearchActive = _searchQuery.length >= 2;
    final AsyncValue<List<ContentItem>> itemsAsync;
    if (isSearchActive) {
      itemsAsync = ref.watch(
        contentSearchProvider(
          curriculumId: widget.curriculumId,
          query: _searchQuery,
        ),
      );
    } else {
      itemsAsync = ref.watch(
        filteredContentProvider(
          curriculumId: widget.curriculumId,
          level1: _currentLevel1,
          level2: _currentLevel2,
          level3: _currentLevel3,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Text(
            'Select content you\'ve already completed',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        if (_navigationStack.isNotEmpty && !isSearchActive)
          configAsync.when(
            data: (config) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                children: [
                  for (var i = 0; i < _navigationStack.length; i++)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _navigationStack = _navigationStack.sublist(0, i + 1);
                        });
                      },
                      child: Text(
                        '${i < config.levelLabels.length ? config.levelLabels[i] : ''}: ${_navigationStack[i]}',
                      ),
                    ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              final displayItems = isSearchActive
                  ? items
                  : _groupItemsByNextLevel(items);
              if (displayItems.isEmpty) {
                return Center(
                  child: Text(
                    isSearchActive
                        ? 'No results for "$_searchQuery"'
                        : 'No content available',
                  ),
                );
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
                    title: Text(item.displayNameEn),
                    subtitle: item.displayNameHe != item.displayNameEn
                        ? Text(item.displayNameHe)
                        : null,
                    trailing: item.isLeaf || isSearchActive
                        ? null
                        : const Icon(Icons.chevron_right),
                    onTap: item.isLeaf || isSearchActive
                        ? () => _toggleItem(item)
                        : () => _drillDown(item),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
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
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _selections.isNotEmpty
                      ? _proceedToStageSelection
                      : null,
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _selectionLabel(HierarchySelection sel) {
    final parts = [sel.level1, sel.level2, sel.level3, sel.level4]
        .whereType<String>()
        .toList();
    return parts.isEmpty ? 'All' : parts.last;
  }

  Widget _buildStageSelection(ThemeData theme) {
    final stagesAsync = ref.watch(stageListProvider(widget.curriculumId));
    final selections = _perSelectionStages.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'Which stages have you completed?',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Set stages per selection, or use "Apply to All" for the same stages everywhere.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: stagesAsync.when(
            data: (stages) => ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final sel in selections) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      _selectionLabel(sel),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  for (final stage in stages)
                    CheckboxListTile(
                      dense: true,
                      value: _perSelectionStages[sel]
                              ?.contains(stage.stageOrder) ??
                          false,
                      onChanged: (checked) {
                        setState(() {
                          final stageSet = _perSelectionStages[sel] ??= {};
                          if (checked ?? false) {
                            for (var i = 1; i <= stage.stageOrder; i++) {
                              stageSet.add(i);
                            }
                          } else {
                            stageSet.removeWhere(
                              (id) => id >= stage.stageOrder,
                            );
                          }
                        });
                      },
                      title: Text(stage.stageName),
                      subtitle: stage.delayDays > 0
                          ? Text('${stage.delayDays} day delay')
                          : null,
                    ),
                  const Divider(),
                ],
                // "Apply to All" shortcut
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Apply to All',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                for (final stage in stages)
                  CheckboxListTile(
                    dense: true,
                    value: _selectedStageIds.contains(stage.stageOrder),
                    onChanged: (checked) {
                      setState(() {
                        if (checked ?? false) {
                          for (var i = 1; i <= stage.stageOrder; i++) {
                            _selectedStageIds.add(i);
                            for (final s in selections) {
                              _perSelectionStages[s]?.add(i);
                            }
                          }
                        } else {
                          _selectedStageIds
                              .removeWhere((id) => id >= stage.stageOrder);
                          for (final s in selections) {
                            _perSelectionStages[s]
                                ?.removeWhere((id) => id >= stage.stageOrder);
                          }
                        }
                      });
                    },
                    title: Text(stage.stageName),
                    subtitle: stage.delayDays > 0
                        ? Text('${stage.delayDays} day delay')
                        : null,
                  ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _phase = _Phase.selection),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _perSelectionStages.values
                          .any((s) => s.isNotEmpty)
                      ? _proceedToConfirmation
                      : null,
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmation(ThemeData theme) {
    final itemCount = _resolvedItems?.length ?? 0;
    final stageCount = _selectedStageIds.length;
    final totalCompletions = itemCount * stageCount;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text('Confirm Bulk Mark', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(
              '$itemCount items across $stageCount stage(s)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$totalCompletions completion records will be created',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      setState(() => _phase = _Phase.stageSelection),
                  child: const Text('Back'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: _executeBulkMark,
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessing(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text('Marking completions...', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildDone(ThemeData theme) {
    final result = _result;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Done!', style: theme.textTheme.headlineSmall),
            if (result != null) ...[
              const SizedBox(height: 8),
              Text(
                'Marked ${result.itemCount} items as completed '
                '(${result.completionCount} records)',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                result != null
                    ? BulkMarkResult(
                        itemCount: result.itemCount,
                        completionCount: result.completionCount,
                      )
                    : null,
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  /// Group items by the next hierarchy level (same logic as ContentHierarchyScreen).
  List<ContentItem> _groupItemsByNextLevel(List<ContentItem> items) {
    final currentDepth = _navigationStack.length;

    if (currentDepth >= 4) return items;
    if (items.isNotEmpty && items.every((i) => i.isLeaf)) return items;

    final uniqueItems = <String, ContentItem>{};

    for (final item in items) {
      final nextLevelValue = switch (currentDepth) {
        0 => item.level1,
        1 => item.level2,
        2 => item.level3,
        3 => item.level4,
        _ => null,
      };

      if (nextLevelValue != null && !uniqueItems.containsKey(nextLevelValue)) {
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

    return uniqueItems.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
}
