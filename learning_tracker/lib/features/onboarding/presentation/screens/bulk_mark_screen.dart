import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/bulk_prior_completion_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
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

  const BulkMarkScreen({
    super.key,
    required this.curriculumId,
    this.scopeConstraints,
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

  /// Full (scope-applied) content list for this curriculum. Loaded once on
  /// open — used both to map pre-ticked refs to selections and to compute the
  /// tri-state (partial) checkbox value for container rows.
  List<ContentItem>? _allItems;

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
      // Load the full content list up-front (scope-applied). Needed both to
      // map pre-ticked refs to selections AND to compute partial checkbox
      // state — so load it unconditionally, even when there are no prior
      // completions to pre-tick.
      final contentRepo = ref.read(contentRepositoryProvider);
      final allItems = _applyScope(
        await contentRepo.getContentForCurriculum(widget.curriculumId),
      );
      if (mounted) setState(() => _allItems = allItems);

      final completionRepo = ref.read(completionRepositoryProvider);
      final existingCompletions = await completionRepo
          .getCompletionsByCurriculum(widget.curriculumId.storageKey);

      if (existingCompletions.isEmpty) return;

      // Only pre-tick items that were marked via the prior-marking flow.
      // Live-learning completions (normal daily learning) do not pre-tick.
      // Use isBulkPriorSentinel (moment-based) — a prior completion synced
      // down from Firestore comes back with a different isUtc flag than
      // DateTime.utc(2000,1,1), so a plain `==` misses every synced row and
      // nothing pre-ticks.
      final completedRefs = existingCompletions
          .where((c) => isBulkPriorSentinel(c.completedAt))
          .map((c) => c.sefariaRef)
          .toSet();

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

  /// Tri-state selection value for a hierarchy row at [depth]:
  ///   true  — every leaf descendant is selected
  ///   false — none selected
  ///   null  — some, but not all, selected (indeterminate)
  ///
  /// Leaf rows are always a plain true/false. Container rows resolve their
  /// state from the leaf descendants in [_allItems]; before that list has
  /// loaded they fall back to the covering-selection check.
  bool? _itemSelectionState(ContentItem item, int depth) {
    if (item.isLeaf) return _isItemSelected(item);
    final all = _allItems;
    if (all == null) return _isItemSelected(item);

    // rowLevel: 1=seder, 2=masechta, 3=perek, 4=mishna.
    final rowLevel = depth + 1;
    bool underRow(ContentItem leaf) {
      if (leaf.level1 != item.level1) return false;
      if (rowLevel >= 2 && leaf.level2 != item.level2) return false;
      if (rowLevel >= 3 && leaf.level3 != item.level3) return false;
      if (rowLevel >= 4 && leaf.level4 != item.level4) return false;
      return true;
    }

    var total = 0;
    var selected = 0;
    for (final leaf in all) {
      if (!leaf.isLeaf || !underRow(leaf)) continue;
      total++;
      if (_isItemSelected(leaf)) selected++;
    }
    if (total == 0) return _isItemSelected(item);
    if (selected == 0) return false;
    if (selected == total) return true;
    return null;
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
    // Tri-state aware: a row counts as "selected" only when it is FULLY
    // selected. Tapping a partial (indeterminate) container therefore
    // selects all of its descendants rather than clearing the few that
    // were ticked — the standard tri-state cycle none/partial → all → none.
    // For leaf rows _itemSelectionState collapses to _isItemSelected, so
    // their behaviour is unchanged.
    final wasSelected = _itemSelectionState(item, depth) ?? false;

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
            AppLogger.instance.error(
              event: 'expunge failed',
              exception: e,
              stackTrace: st,
            );
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

    // AUD-onboarding-01 (SM-4): resolveSelections is a DB read that may
    // still be in flight when this screen is popped (backgrounding the app,
    // hitting back). Touching ref/context/setState below unconditionally
    // after that await throws once this State is disposed.
    if (!mounted) return;

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

    // AUD-onboarding-01 (SM-4): second guard for the getContentForCurriculum
    // await above — disposal could also land there, not just at the first
    // await, before reaching this setState.
    if (!mounted) return;

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
      );

      // AUD-onboarding-01 (SM-4): execute() commits the bulk-mark write and
      // may still be in flight when this screen is popped. Touching setState
      // below unconditionally after that await throws once this State is
      // disposed.
      if (!mounted) return;

      setState(() {
        _result = result;
        _phase = _Phase.done;
      });

      // Wave 5 Task #17: post-save toast clarifying tier credit — shown
      // immediately after the bulk-mark commits so users see WHERE the items
      // will land (Lifetime Knowledge, possibly unlocking siyumim).
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.bulkMarkConfirmationToast(result.itemCount)),
          ),
        );
      }

      // Refresh progress surfaces immediately after bulk mark.
      ref.invalidate(
        dashboardCompletionPercentageProvider(widget.curriculumId),
      );
      ref.invalidate(dashboardLastCompletionProvider(widget.curriculumId));
      ref.invalidate(progressOverviewStatsProvider);
      ref.invalidate(allDailyTasksProvider);
    } catch (e) {
      // AUD-onboarding-01 (SM-4): the try block above awaits execute(); if
      // this screen was popped while that write was in flight and it then
      // throws, touching setState here unconditionally throws again (on a
      // disposed State) instead of surfacing the original error.
      if (!mounted) return;
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
                text: AppLocalizations.of(context)!.bulkMarkScreenTitle(
                  curriculumLabelText(ref, curriculum: widget.curriculumId),
                ),
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
              l10n.bulkMarkSelectHeading,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          // Wave 5 Task #17: B1 tier-policy explainer — bulk marks credit
          // siyumim + lifetime knowledge but NOT streak or points.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              l10n.bulkMarkWizardSubtitle(domainTermLabels(ref).siyumim),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
                      return ListTile(
                        leading: Checkbox(
                          // tristate: a container row whose children are
                          // partially selected shows the indeterminate dash.
                          tristate: true,
                          value: _itemSelectionState(item, currentPath.length),
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

  Widget _buildSearchResults(ThemeData theme, AppLocalizations l10n) {
    final itemsAsync = ref.watch(
      contentSearchProvider(
        curriculumId: widget.curriculumId,
        query: _searchQuery,
      ),
    );
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => AppErrorView(
        error: e,
        stackTrace: st,
        onRetry: () => ref.refresh(
          contentSearchProvider(
            curriculumId: widget.curriculumId,
            query: _searchQuery,
          ),
        ),
      ),
      data: (rawItems) {
        final items = _applyScope(rawItems);
        if (items.isEmpty) {
          return Center(child: Text(l10n.noResultsForQuery(_searchQuery)));
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
