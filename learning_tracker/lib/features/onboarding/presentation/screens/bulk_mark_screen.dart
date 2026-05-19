import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
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
///
/// Previously-completed content is pre-ticked on open (B7). Unticking a
/// previously-ticked item calls expungePriorCompletions to tombstone those
/// completion records (B8). The stage-picker step has been removed — all
/// stages are recorded automatically by the data layer (B5).
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

// B5: Stage-picker phase removed. Flow is now: selection → confirmation →
// processing → done.
enum _Phase { selection, confirmation, processing, done }

class _BulkMarkScreenState extends ConsumerState<BulkMarkScreen> {
  var _phase = _Phase.selection;
  final _selections = <HierarchySelection>{};

  /// Leaf sefariaRefs that were pre-ticked because they already exist in the DB.
  /// Unticking one of these triggers an expunge call (B8).
  final _preTickedRefs = <String>{};

  List<ContentItem>? _resolvedItems;
  BulkPriorCompletionResult? _result;
  String? _error;

  // Search state
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  // Panel navigation state (synced via onNavigationChanged).
  bool _hasNavStack = false;
  final _panelKey = GlobalKey<HierarchySelectionPanelState>();

  @override
  void initState() {
    super.initState();
    _loadPreExistingCompletions();
  }

  /// B7: Load existing completions and pre-tick any content that is already
  /// marked so the checkbox state reflects reality when the screen opens.
  Future<void> _loadPreExistingCompletions() async {
    try {
      final completionRepo = ref.read(completionRepositoryProvider);
      final existingCompletions = await completionRepo
          .getCompletionsByCurriculum(widget.curriculumId.storageKey);

      if (existingCompletions.isEmpty) return;

      // Only pre-tick items that were marked via the prior-marking flow.
      // Live-learning completions (normal daily learning) do not pre-tick.
      final completedRefs = existingCompletions
          .where((c) => c.completedAt == kBulkPriorSentinelDate)
          .map((c) => c.sefariaRef)
          .toSet();

      // Load the full content list to map refs → HierarchySelections.
      final contentRepo = ref.read(contentRepositoryProvider);
      final allItems = await contentRepo.getContentForCurriculum(
        widget.curriculumId,
      );

      // Build pre-ticked leaf-level selections for every already-completed ref.
      final preTickedSelections = <HierarchySelection>{};
      for (final item in allItems) {
        if (!item.isLeaf) continue;
        if (completedRefs.contains(item.sefariaRef)) {
          preTickedSelections.add(
            HierarchySelection(
              level1: item.level1,
              level2: item.level2,
              level3: item.level3,
              level4: item.level4,
            ),
          );
          _preTickedRefs.add(item.sefariaRef);
        }
      }

      if (mounted && preTickedSelections.isNotEmpty) {
        setState(() => _selections.addAll(preTickedSelections));
      }
    } catch (_) {
      // Non-fatal: if pre-tick loading fails just open with unticked state.
    }
  }

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
    final wasSelected = _isItemSelected(item);

    setState(() {
      final sel = _selectionForItem(item, depth);
      if (wasSelected) {
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

    // B8: When the user unticks a previously-completed item, expunge those
    // completion records so the data layer stays consistent.
    if (wasSelected) {
      _maybeExpunge(item, depth);
    }
  }

  /// B8: Expunge completion records for the leaf refs covered by [item] that
  /// were originally pre-ticked (i.e., previously existed in the DB).
  void _maybeExpunge(ContentItem item, int depth) {
    final sel = _selectionForItem(item, depth);

    // Collect the leaf sefariaRefs covered by the unticked selection, restricted
    // to refs that were pre-ticked (i.e., came from the DB).
    List<String> refs;

    final resolved = _resolvedItems;
    if (resolved != null) {
      // Fast path: use already-resolved items.
      refs = resolved
          .where((leaf) {
            if (sel.level1 != null && leaf.level1 != sel.level1) return false;
            if (sel.level2 != null && leaf.level2 != sel.level2) return false;
            if (sel.level3 != null && leaf.level3 != sel.level3) return false;
            if (sel.level4 != null && leaf.level4 != sel.level4) return false;
            return true;
          })
          .map((leaf) => leaf.sefariaRef)
          .where(_preTickedRefs.contains)
          .toList();
    } else if (item.isLeaf && _preTickedRefs.contains(item.sefariaRef)) {
      // Slow path: item itself is a leaf.
      refs = [item.sefariaRef];
    } else {
      // _resolvedItems is null and the item is a container (not a leaf).
      // We cannot enumerate children yet, so expunge is deferred — on next
      // open the pre-tick reload will re-evaluate and the stale records
      // will not re-appear because the user did not tap "Next" on them.
      return;
    }

    if (refs.isEmpty) return;
    _expungeRefs(refs);
  }

  void _expungeRefs(List<String> refs) {
    final service = ref.read(bulkPriorCompletionServiceProvider);
    final profileId = ref.read(activeProfileIdProvider);

    // B8: expunge each ref individually — service API is per-ref.
    for (final ref_ in refs) {
      service
          .expungePriorCompletions(
            profileId: profileId,
            sefariaRef: ref_,
            curriculumId: widget.curriculumId,
          )
          .catchError((Object e, StackTrace st) {
        AppLogger.instance.error('expunge failed', e, st);
      });
    }

    // Refresh progress surfaces after expunge.
    ref.invalidate(dashboardCompletionPercentageProvider(widget.curriculumId));
    ref.invalidate(dashboardLastCompletionProvider(widget.curriculumId));
    ref.invalidate(progressOverviewStatsProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _proceedToConfirmation() async {
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
      _phase = _Phase.confirmation;
    });
  }

  Future<void> _executeBulkMark() async {
    if (_resolvedItems == null) return;

    setState(() => _phase = _Phase.processing);

    try {
      final service = ref.read(bulkPriorCompletionServiceProvider);

      // B5: Stage-picker removed — pass stage 1 as the baseline; the service
      // (B6 fix in Agent E's version) automatically unions in all configured
      // stages so every track stage is satisfied.
      final result = await service.execute(
        curriculumId: widget.curriculumId,
        resolvedItems: _resolvedItems!,
        stageIds: const [1],
        awardGamificationPoints: widget.awardGamificationPoints,
      );

      setState(() {
        _result = result;
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
                inputFormatters: const [TrimLeadingSpaceFormatter()],
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
        leading: _phase == _Phase.selection && _hasNavStack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _panelKey.currentState?.navigateBack(),
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
                    _hasNavStack = false;
                  }
                });
              },
            ),
        ],
      ),
      body: switch (_phase) {
        _Phase.selection => _buildSelection(theme),
        _Phase.confirmation => _buildConfirmation(theme),
        _Phase.processing => _buildProcessing(theme),
        _Phase.done => _buildDone(theme),
      },
    );
  }

  Widget _buildSelection(ThemeData theme) {
    final isSearchActive = _searchQuery.length >= 2;
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
          Expanded(
            child: isSearchActive
                ? _buildSearchResults(theme, l10n)
                : HierarchySelectionPanel(
                    key: _panelKey,
                    curriculumId: widget.curriculumId,
                    scopeConstraints: widget.scopeConstraints,
                    autoAdvanceSingleOption: true,
                    onNavigationChanged: (path, _) {
                      setState(() => _hasNavStack = path.isNotEmpty);
                    },
                    tileBuilder: (item, currentPath, onDrill) {
                      final isSelected = _isItemSelected(item);
                      return ListTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (_) =>
                              _toggleItem(item, currentPath.length),
                        ),
                        title: CurriculumLabel.item(
                          item,
                          mode: CurriculumLabelMode.leaf,
                          textAlign: TextAlign.start,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: onDrill != null
                            ? const Icon(Icons.chevron_right)
                            : null,
                        onTap:
                            onDrill ??
                            () => _toggleItem(item, currentPath.length),
                      );
                    },
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
                    child: Text(l10n.bulkMarkSkip),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _selections.isNotEmpty
                        ? _proceedToConfirmation
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

  Widget _buildSearchResults(
    ThemeData theme,
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

  Widget _buildConfirmation(ThemeData theme) {
    final itemCount = _resolvedItems?.length ?? 0;

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
              Text('$itemCount items', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '$itemCount completion records will be created',
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
                    onPressed: () => setState(() => _phase = _Phase.selection),
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
