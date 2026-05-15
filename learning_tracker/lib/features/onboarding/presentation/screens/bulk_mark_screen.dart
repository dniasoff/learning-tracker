import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/hierarchy_browser.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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

  /// Optional scope constraints from the Add Track flow.
  /// When provided, only content within these scopes is shown.
  final List<ScopeEntry>? scopeConstraints;

  /// When true, completions are created with full gamification points.
  /// Defaults to false (onboarding "prior learning" bulk marks award no points).
  final bool awardGamificationPoints;

  const BulkMarkScreen({
    super.key,
    required this.curriculumId,
    this.scopeConstraints,
    this.awardGamificationPoints = false,
  });

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

  // HierarchyBrowser state (synced via onNavigationChanged).
  List<String> _navigationStack = [];
  List<String?> _navigationStackHebrewNames = [];
  final _browserKey = GlobalKey<HierarchyBrowserState>();

  /// Filter items by scope constraints if provided.
  List<ContentItem> _applyScope(List<ContentItem> items) {
    final scopes = widget.scopeConstraints;
    if (scopes == null || scopes.isEmpty) return items;
    final level = scopes.first.level;
    final values = scopes.map((s) => s.value).toSet();
    return items.where((item) {
      final itemValue = levelValueAt(item, level);
      return itemValue != null && values.contains(itemValue);
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

    // Validate: can't mark everything as completed
    final repository = ref.read(contentRepositoryProvider);
    final allItems = await repository.getContentForCurriculum(
      widget.curriculumId,
    );
    final scopedItems = _applyScope(allItems);
    final totalLeafs = scopedItems.where((i) => i.isLeaf).length;
    if (resolved.length >= totalLeafs && totalLeafs > 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must leave at least some content unmarked to continue learning.',
          ),
        ),
      );
      return;
    }

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
          awardGamificationPoints: widget.awardGamificationPoints,
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

      // Refresh progress surfaces immediately after bulk mark.
      ref.invalidate(
        dashboardCompletionPercentageProvider(widget.curriculumId),
      );
      ref.invalidate(dashboardLastCompletionProvider(widget.curriculumId));
      ref.invalidate(progressOverviewStatsProvider);
      ref.invalidate(allDailyTasksProvider);
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
                    'Mark Prior Completions — ${curriculumLabelText(ref, curriculum: widget.curriculumId)}',
              ),
        leading: _phase == _Phase.selection && _navigationStack.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _browserKey.currentState?.navigateBack(),
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
    final isSearchActive = _searchQuery.length >= 2;
    final useHebrew = ref.watch(useHebrewTermsProvider);
    final variant = ref.watch(currentTransliterationVariantProvider);
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: Column(
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
          // Breadcrumb bar — only shown during hierarchy browsing.
          if (_navigationStack.isNotEmpty && !isSearchActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                children: [
                  for (var i = 0; i < _navigationStack.length; i++)
                    TextButton(
                      onPressed: () {
                        // Trim browser's internal stack to i+1 entries.
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
            child: isSearchActive
                ? _buildSearchResults(theme, useHebrew, l10n)
                : _buildHierarchyBrowser(theme, useHebrew),
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
                    child: Text(l10n.bulkMarkSkip),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _selections.isNotEmpty
                        ? _proceedToStageSelection
                        : null,
                    child: Text(l10n.actionNext),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyBrowser(ThemeData theme, bool useHebrew) {
    final contentAsync = ref.watch(
      curriculumContentProvider(widget.curriculumId),
    );
    return contentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(AppLocalizations.of(context)!.errorGeneric(e.toString())),
      ),
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
              textDirection: useHebrew ? TextDirection.rtl : TextDirection.ltr,
              textAlign: TextAlign.start,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: onDrill != null ? const Icon(Icons.chevron_right) : null,
            onTap: onDrill ?? () => _toggleItem(item, currentPath.length),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(
    ThemeData theme,
    bool useHebrew,
    AppLocalizations l10n,
  ) {
    final itemsAsync = ref.watch(
      contentSearchProvider(
        curriculumId: widget.curriculumId,
        query: _searchQuery,
      ),
    );
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.errorGeneric(e.toString()))),
      data: (rawItems) {
        final items = _applyScope(rawItems);
        if (items.isEmpty) {
          return Center(child: Text('No results for "$_searchQuery"'));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected = _isItemSelected(item);
            return ListTile(
              leading: Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleItem(item, 3),
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
              onTap: () => _toggleItem(item, 3),
            );
          },
        );
      },
    );
  }

  String _selectionLabel(HierarchySelection sel) {
    final parts = [
      sel.level1,
      sel.level2,
      sel.level3,
      sel.level4,
    ].whereType<String>().toList();
    return parts.isEmpty ? 'All' : parts.last;
  }

  Widget _buildStageSelection(ThemeData theme) {
    final stagesAsync = ref.watch(stageListProvider(widget.curriculumId));
    final selections = _perSelectionStages.keys.toList();

    return SafeArea(
      top: false,
      child: Column(
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
                        value:
                            _perSelectionStages[sel]?.contains(
                              stage.stageOrder,
                            ) ??
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
                            ? Text(
                                AppLocalizations.of(
                                  context,
                                )!.reviewStageDayDelay(stage.delayDays),
                              )
                            : null,
                      ),
                    const Divider(),
                  ],
                  // "Apply to All" shortcut
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      AppLocalizations.of(context)!.applyToAll,
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
                            _selectedStageIds.removeWhere(
                              (id) => id >= stage.stageOrder,
                            );
                            for (final s in selections) {
                              _perSelectionStages[s]?.removeWhere(
                                (id) => id >= stage.stageOrder,
                              );
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
              error: (e, _) => Center(
                child: Text(
                  AppLocalizations.of(context)!.errorGeneric(e.toString()),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _phase = _Phase.selection),
                    child: Text(AppLocalizations.of(context)!.actionBack),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        _perSelectionStages.values.any((s) => s.isNotEmpty)
                        ? _proceedToConfirmation
                        : null,
                    child: Text(AppLocalizations.of(context)!.actionNext),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmation(ThemeData theme) {
    final itemCount = _resolvedItems?.length ?? 0;
    final stageCount = _selectedStageIds.length;
    final totalCompletions = itemCount * stageCount;

    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.checklist, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.bulkMarkConfirmBulkTitle,
                style: theme.textTheme.headlineSmall,
              ),
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
                    child: Text(AppLocalizations.of(context)!.actionBack),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _executeBulkMark,
                    child: Text(AppLocalizations.of(context)!.actionConfirm),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessing(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.bulkMarkingCompletions,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDone(ThemeData theme) {
    final result = _result;
    return SafeArea(
      top: false,
      child: Center(
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
              Text(
                AppLocalizations.of(context)!.bulkMarkDone,
                style: theme.textTheme.headlineSmall,
              ),
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
                child: Text(AppLocalizations.of(context)!.actionContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
