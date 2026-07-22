import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/domain/strategies/composite_curriculum_strategy.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_folder_styled_widgets.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class LifetimeMarkingScreen extends ConsumerWidget {
  const LifetimeMarkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final summariesAsync = ref.watch(
      lifetimeSummariesProvider(ref.watch(activeProfileIdProvider)),
    );

    return Scaffold(
      backgroundColor: context.colors.brandCreamCard,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: context.colors.brandInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 56,
        centerTitle: true,
        leadingWidth: 56,
        actions: const [SizedBox(width: 56, height: 56)],
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            l10n.addWhatYouLearned,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 26,
              height: 1.15,
              color: context.colors.brandInk,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.colors.brandCreamCard,
              context.colors.brandBlueSoft.withValues(alpha: 0.22),
              context.colors.brandCream,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Tier-policy subtitle — explains the lifetimeOnly source so the
              // user understands what gets credited where (Wave 5 Task #18).
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                child: Text(
                  l10n.lifetimeMarkingSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.brandInkMuted,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              for (var i = 0; i < CurriculumId.values.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _LifetimeLibraryCategoryCard(
                  curriculum: CurriculumId.values[i],
                  summariesAsync: summariesAsync,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LifetimeCurriculumMarkingScreen(
                          curriculumId: CurriculumId.values[i].storageKey,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData _curriculumIcon(CurriculumId id) {
  return switch (id) {
    CurriculumId.mishnayos => Icons.auto_stories_outlined,
    CurriculumId.bavli => Icons.balance_outlined,
    CurriculumId.yerushalmi => Icons.library_books_outlined,
    CurriculumId.mishnaBerurah => Icons.rule_folder_outlined,
    CurriculumId.chumash => Icons.menu_book_outlined,
    CurriculumId.mishnehTorah => Icons.import_contacts_outlined,
    CurriculumId.tanach => Icons.article_outlined,
    CurriculumId.nach => Icons.record_voice_over_outlined,
    CurriculumId.mussar => Icons.favorite_border_rounded,
  };
}

class _LifetimeLibraryCategoryCard extends ConsumerWidget {
  const _LifetimeLibraryCategoryCard({
    required this.curriculum,
    required this.summariesAsync,
    required this.onTap,
  });

  final CurriculumId curriculum;
  final AsyncValue<List<CurriculumLifetimeSummary>> summariesAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final useHebrew = domainTermLabels(ref).isHebrew;
    final summary =
        summariesAsync.asData?.value.firstWhere(
          (s) => s.curriculumId == curriculum,
          orElse: () => CurriculumLifetimeSummary(
            curriculumId: curriculum,
            learnedLeafCount: 0,
            totalLeafCount: 0,
            percentage: 0,
            tree: const [],
          ),
        ) ??
        CurriculumLifetimeSummary(
          curriculumId: curriculum,
          learnedLeafCount: 0,
          totalLeafCount: 0,
          percentage: 0,
          tree: const [],
        );

    final color = context.colors.curriculumFor(curriculum);
    final notStarted = summary.learnedLeafCount == 0;
    final pctText = percentTextForCurriculum(summary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.surfaceE9),
            boxShadow: const [
              BoxShadow(
                color: Color(0x121D2939),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _curriculumIcon(curriculum),
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CurriculumLabel.curriculum(
                          curriculum,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.colors.brandInk,
                          ),
                        ),
                        if (!useHebrew) ...[
                          const SizedBox(height: 2),
                          Text(
                            curriculumHebrewName(curriculum),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.colors.brandInkMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (pctText != null && !notStarted) ...[
                    Text(
                      pctText,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.colors.brandInk,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 34,
                    color: context.colors.brandInkMuted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (notStarted)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.lifetimeNotStarted,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.colors.brandInkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '—',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.colors.brandInkMuted,
                      ),
                    ),
                  ],
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: summary.percentage.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE8ECF3),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

@RoutePage()
class LifetimeCurriculumMarkingScreen extends ConsumerStatefulWidget {
  const LifetimeCurriculumMarkingScreen({
    required this.curriculumId,
    super.key,
  });

  final String curriculumId;

  @override
  ConsumerState<LifetimeCurriculumMarkingScreen> createState() =>
      _LifetimeCurriculumMarkingScreenState();
}

class _LifetimeCurriculumMarkingScreenState
    extends ConsumerState<LifetimeCurriculumMarkingScreen> {
  final List<ScopeEntry> _selections = [];
  bool _saving = false;

  // Navigation state kept in sync via HierarchySelectionPanel callbacks.
  bool _hasNavStack = false;
  List<ContentItem> _currentDisplayItems = [];

  // IL-LEVEL fix: the actual navigation depth reported by the panel. The
  // displayed items live at hierarchy level `_navPathLength + 1` (the same
  // value `tileBuilder` computes as `currentPath.length + 1`). The previous
  // code derived the level from `_currentDisplayItems.length` — a folder SIZE —
  // which (a) wrote ledger entries at the wrong level (selecting the ancestor
  // instead of the visible items) and (b) broke the select-all toggle whenever
  // a folder showed >4 items, because the bogus level fell past the 4-level cap
  // and `levelValueAt` returned null for every row.
  int _navPathLength = 0;
  final _panelKey = GlobalKey<HierarchySelectionPanelState>();

  CurriculumId get _curriculum => CurriculumId.values.firstWhere(
    (c) => c.storageKey == widget.curriculumId,
    orElse: () => CurriculumId.mishnayos,
  );

  /// Collision fix: a level2/level3/level4 mark must be stored/compared with its
  /// FULL ancestor path so daf '2' in Berakhos does not also select daf '2' in
  /// Shabbos, and perek '1' in Bereishis does not also select perek '1' in
  /// Shemos. Only level1 (the curriculum root) is unique, so
  /// [scopeUnitIdentifier] returns the bare value for it alone. [currentPath] is
  /// the navigation path of ANCESTORS above the item; [value] is the item's own
  /// level value at [level].
  String _qid(int level, String value, List<String> currentPath) {
    final l = <String?>[null, null, null, null]; // level1..level4
    for (var i = 0; i < currentPath.length && i < 4; i++) {
      l[i] = currentPath[i];
    }
    if (level >= 1 && level <= 4) l[level - 1] = value;
    return scopeUnitIdentifier(
      level: level,
      level1: l[0],
      level2: l[1],
      level3: l[2],
      level4: l[3],
    );
  }

  /// Derives the current navigation path (ancestor level values, level1-first)
  /// for the rows displayed in the panel. The displayed items live at level
  /// `_effectiveLevel`, so their level1..level(`_effectiveLevel - 1`) values are
  /// the shared ancestors. Used by the level-wide "all" helpers, which do not
  /// receive `currentPath` from the panel's tileBuilder.
  List<String> _currentNavPath() {
    if (_currentDisplayItems.isEmpty) return const [];
    final ancestorCount = _navPathLength; // _effectiveLevel - 1
    final first = _currentDisplayItems.first;
    final path = <String>[];
    for (var lvl = 1; lvl <= ancestorCount; lvl++) {
      final v = levelValueAt(first, lvl);
      if (v == null || v.isEmpty) break;
      path.add(v);
    }
    return path;
  }

  bool _isSelected(String value, List<String> currentPath) {
    final currentLevel = currentPath.length + 1;
    if (_selections.any(
      (s) =>
          s.level == currentLevel &&
          s.value == _qid(currentLevel, value, currentPath),
    )) {
      return true;
    }
    for (var i = 0; i < currentPath.length; i++) {
      final ancestorLevel = i + 1;
      final ancestorValue = currentPath[i];
      final ancestorId = _qid(
        ancestorLevel,
        ancestorValue,
        currentPath.sublist(0, i),
      );
      if (_selections.any(
        (s) => s.level == ancestorLevel && s.value == ancestorId,
      )) {
        return true;
      }
    }
    return false;
  }

  bool _isDirectlySelected(
    String value,
    int currentLevel,
    List<String> currentPath,
  ) {
    final id = _qid(currentLevel, value, currentPath);
    return _selections.any((s) => s.level == currentLevel && s.value == id);
  }

  void _toggleSelection(String value, int level, List<String> currentPath) {
    final id = _qid(level, value, currentPath);
    setState(() {
      final idx = _selections.indexWhere(
        (s) => s.level == level && s.value == id,
      );
      if (idx >= 0) {
        _selections.removeAt(idx);
      } else {
        _selections.removeWhere((s) => s.level > level);
        _selections.add(ScopeEntry(level: level, value: id));
      }
    });
  }

  /// Returns `true` when SOME-but-not-all leaves beneath the non-leaf row at
  /// [currentLevel]/[value] (under [currentPath]) are credited (by a current
  /// session selection OR a persisted ledger mark), and the row is not itself
  /// directly/implicitly fully selected.
  ///
  /// Drives the indeterminate ([MarkingRowVisual.partial]) checkbox so a parent
  /// container (e.g. Tanach→Torah) renders a dash — never a full check — when
  /// only some children (e.g. Bereishis) are marked. Without this a 1-of-N
  /// parent looked fully complete, which is what led users to (over-)mark the
  /// synthetic container directly.
  bool _isPartial(
    List<ContentItem> allLeaves,
    String value,
    int currentLevel,
    List<String> currentPath,
    List<LearningLedgerData> ledger,
  ) {
    if (allLeaves.isEmpty) return false;
    // Full ancestor path of this row (level1-first), including the row itself.
    final path = <String>[...currentPath, value];
    bool underRow(ContentItem leaf) {
      for (var i = 0; i < path.length; i++) {
        if (levelValueAt(leaf, i + 1) != path[i]) return false;
      }
      return true;
    }

    final descendants = allLeaves.where(underRow).toList();
    if (descendants.isEmpty) return false;

    // Build a learned-leaf set under this row from BOTH the persisted ledger and
    // the current session selections (modelled as ledger rows so the same
    // qualified-id matching logic applies).
    final sessionEntries = _selections.map((s) {
      return LearningLedgerData(
        id: 0,
        profileId: 0,
        ulid: '',
        curriculumId: _curriculum.storageKey,
        entryScope: 'level${s.level}',
        unitIdentifier: s.value,
        unitDisplayNameHe: '',
        unitDisplayNameEn: '',
        trackType: 'personal',
        trackId: null,
        completedAt: DateTime.utc(2000),
        completionNumber: 1,
        markedBy: 0,
        isManual: true,
        createdAt: DateTime.utc(2000),
      );
    }).toList();

    const builder = LifetimeTreeBuilder();
    final learned = builder.computeLearnedLeafRefs(
      leaves: descendants,
      completedRefs: const {},
      ledgerEntries: [...ledger, ...sessionEntries],
    );
    return learned.isNotEmpty && learned.length < descendants.length;
  }

  // PP-10 / IL-LEVEL fix: returns the hierarchy level the current panel is
  // displaying — the navigation depth + 1, matching the `currentPath.length + 1`
  // that `tileBuilder` uses for an individual tap. Both _markAllCurrentLevel and
  // _deselectAllCurrentLevel use this so a "select all" writes scope entries for
  // the VISIBLE rows, not their shared ancestor.
  int get _effectiveLevel => _navPathLength + 1;

  // PP-10 / IL-TOGGLE fix: true only when there is at least one selectable item
  // in the current panel AND every such item is already selected. Requiring a
  // selectable item prevents the toggle from vacuously reporting "all selected"
  // (and getting stuck on "Deselect all") when nothing is selected.
  bool get _allCurrentSelected {
    if (_currentDisplayItems.isEmpty) return false;
    final level = _effectiveLevel;
    final currentPath = _currentNavPath();
    var sawSelectable = false;
    for (final item in _currentDisplayItems) {
      final rawValue = levelValueAt(item, level) ?? '';
      if (rawValue.isEmpty) continue;
      sawSelectable = true;
      final id = _qid(level, rawValue, currentPath);
      if (!_selections.any((s) => s.level == level && s.value == id)) {
        return false;
      }
    }
    return sawSelectable;
  }

  void _markAllCurrentLevel() {
    final level = _effectiveLevel;
    final currentPath = _currentNavPath();
    setState(() {
      _selections.removeWhere((s) => s.level == level);
      for (final item in _currentDisplayItems) {
        final rawValue = levelValueAt(item, level) ?? '';
        if (rawValue.isNotEmpty) {
          _selections.add(
            ScopeEntry(level: level, value: _qid(level, rawValue, currentPath)),
          );
        }
      }
    });
  }

  // PP-10 fix: deselect all session-selected items in the current panel, while
  // leaving persisted (already-saved) rows unchanged.
  void _deselectAllCurrentLevel() {
    final level = _effectiveLevel;
    setState(() {
      _selections.removeWhere((s) => s.level == level);
    });
  }

  bool _ledgerHasUnit(
    List<LearningLedgerData> ledger,
    int level,
    String value,
    List<String> currentPath,
  ) {
    // Persisted level2/level3/level4 marks store the QUALIFIED path id
    // (collision fix), so compare against the qualified id; only level1 stays
    // bare via _qid.
    final id = _qid(level, value, currentPath);
    return ledger.any(
      (e) => e.entryScope == 'level$level' && e.unitIdentifier == id,
    );
  }

  Future<void> _markSelections(List<ScopeEntry> selections) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final repo = ref.read(learningLedgerRepositoryProvider);
      final profileId = ref.read(activeProfileIdProvider);
      final unique = <String>{};
      final batchItems = <LedgerManualBatchItem>[];
      for (final selection in selections) {
        final key = '${selection.level}:${selection.value}';
        if (!unique.add(key)) continue;
        // P0 over-credit guard: never persist a blanket mark on a composite
        // curriculum's SYNTHETIC level1 container (e.g. Tanach→'Torah'). Such a
        // row credits every leaf beneath the synthetic section (the whole Torah
        // from a single mark). The real learning belongs in the source
        // curriculum (Chumash), which propagates up to the composite by
        // canonical leaf. Drilling in and marking the concrete books still works.
        if (selection.level == 1 &&
            CompositeCurriculumStrategy.isSyntheticContainerLevel1(
              _curriculum.storageKey,
              selection.value,
            )) {
          continue;
        }
        batchItems.add(
          LedgerManualBatchItem(
            curriculumId: _curriculum.storageKey,
            entryScope: 'level${selection.level}',
            unitIdentifier: selection.value,
            unitDisplayNameHe: selection.value,
            unitDisplayNameEn: selection.value,
            trackType: 'personal',
            trackId: null,
            markedBy: profileId,
            isManual: true,
          ),
        );
      }

      await repo.recordCompletionsBatch(batchItems);

      _invalidateComputedViews();
      if (!mounted) return;
      // PP-3 fix: clear the session selection after a successful save so the
      // user does not see lingering green checkmarks on already-persisted rows
      // (the persisted state is now reflected by the ledger, not _selections).
      setState(() => _selections.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lifetimeMarkSavedCount(batchItems.length))),
      );
    } catch (e, stackTrace) {
      // EH-5/ST-4: never surface the raw exception's toString() in the UI —
      // log it for diagnostics and show only the fixed, localized fallback
      // copy instead.
      AppLogger.instance.error(
        event: 'lifetime_mark_save_failed',
        fields: {'curriculumId': _curriculum.storageKey},
        exception: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.lifetimeMarkSaveError)));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _invalidateComputedViews() {
    final profileId = ref.read(activeProfileIdProvider);
    ref.invalidate(lifetimeSummariesProvider(profileId));
    // ignore: deprecated_member_use
    ref.invalidate(globalLifetimeCurriculaProvider(profileId));
    ref.invalidate(
      lifetimeDataProvider((profileId: profileId, curriculumId: _curriculum)),
    );
    ref.invalidate(trackDualProgressMetricsProvider(profileId));
    ref.invalidate(progressOverviewStatsProvider);
    ref.invalidate(journeyViewModelProvider(profileId));
    ref.invalidate(dashboardCompletionPercentageProvider(_curriculum));
    ref.invalidate(dashboardLastCompletionProvider(_curriculum));
    ref.invalidate(lifetimeTotalsAcrossAllCurriculaProvider(profileId));
    ref.invalidate(curriculumLedgerProvider(widget.curriculumId));
    // The Lifetime KNOWLEDGE screen's TREE watches these two view providers
    // (all-sources / track-only). Without invalidating them, the headline count
    // refreshed after a save but the tree below stayed stale until the
    // source-filter segmented control forced a rebuild.
    ref.invalidate(lifetimeViewSummariesProvider(profileId));
    ref.invalidate(itemsLearnedSummariesProvider(profileId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ledgerAsync = ref.watch(
      curriculumLedgerProvider(widget.curriculumId),
    );
    // Drop any stray SYNTHETIC-container level1 rows (e.g. a composite's
    // Tanach→'Torah') so a parent never reads as fully-checked off a blanket
    // container mark — the row's true state must come from its real descendant
    // marks (rendered as indeterminate via [_isPartial]). Mirrors the read-time
    // guard in lifetime_knowledge_providers; independent of the v32 migration.
    final ledger = (ledgerAsync.asData?.value ?? const <LearningLedgerData>[])
        .where((e) {
          final scope = e.entryScope.startsWith('unmark_')
              ? e.entryScope.substring('unmark_'.length)
              : e.entryScope;
          if (scope != 'level1') return true;
          return !CompositeCurriculumStrategy.isSyntheticContainerLevel1(
            _curriculum.storageKey,
            e.unitIdentifier,
          );
        })
        .toList();
    // All leaves for the active curriculum — used to derive the indeterminate
    // (partial) parent state. Falls back to empty until the content asset loads
    // (rows then simply render non-partial, never wrongly fully-checked).
    final allLeaves =
        ref
            .watch(curriculumContentProvider(_curriculum))
            .asData
            ?.value
            .where((i) => i.isLeaf)
            .toList() ??
        const <ContentItem>[];
    final useHebrew = domainTermLabels(ref).isHebrew;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.colors.brandCreamCard,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: context.colors.brandInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _hasNavStack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: context.colors.brandBlueDeep,
                onPressed: () => _panelKey.currentState?.navigateBack(),
              )
            : null,
        title: AppBarTitle(
          text: curriculumLabelText(ref, curriculum: _curriculum),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.colors.brandCreamCard,
              context.colors.brandBlueSoft.withValues(alpha: 0.22),
              context.colors.brandCream,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.colors.surfaceE9),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x121D2939),
                          blurRadius: 16,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.playlist_add_check_outlined,
                              color: context.colors.brandBlue,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.lifetimeSelectScreenTitle,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: context.colors.brandInk,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.lifetimeSelectScreenSubtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: context.colors.brandInkMuted,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.brandBlueSoft.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.colors.surfaceE9),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.draw_outlined,
                                color: context.colors.brandBlue,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.lifetimeMarkAsLearnedTitle,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: context.colors.brandInk,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    // PP-3 fix: removed the "• level {N}"
                                    // token that leaked the internal folder
                                    // size as an opaque "level" number.
                                    Text(
                                      l10n.lifetimeMarkAsLearnedCount(
                                        _selections.length,
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: context.colors.brandInkMuted,
                                            height: 1.35,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // PP-10 fix: toggle between "Select all" and
                        // "Deselect all" depending on whether every item in
                        // the current panel is already session-selected.
                        OutlinedButton.icon(
                          onPressed: _currentDisplayItems.isEmpty
                              ? null
                              : _allCurrentSelected
                              ? _deselectAllCurrentLevel
                              : _markAllCurrentLevel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colors.brandBlue,
                            side: BorderSide(
                              color: context.colors.brandBlue.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                          icon: Icon(
                            _allCurrentSelected
                                ? Icons.deselect
                                : Icons.select_all,
                            size: 20,
                          ),
                          label: Text(
                            _allCurrentSelected
                                ? l10n.deselectAllInThisList
                                : l10n.selectAllInThisList,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: HierarchySelectionPanel(
                            key: _panelKey,
                            curriculumId: _curriculum,
                            autoAdvanceSingleOption: false,
                            onNavigationChanged: (path, _) => setState(() {
                              _hasNavStack = path.isNotEmpty;
                              // IL-LEVEL fix: track the real navigation depth so
                              // _effectiveLevel = depth + 1 matches the level the
                              // panel is displaying.
                              _navPathLength = path.length;
                            }),
                            onDisplayItemsChanged: (items) =>
                                // PP-10 fix: call setState so the select-all
                                // toggle re-evaluates _allCurrentSelected when
                                // the displayed item list changes (e.g. drilled
                                // into a folder).
                                setState(() => _currentDisplayItems = items),
                            tileBuilder: (item, currentPath, onDrill) {
                              final currentLevel = currentPath.length + 1;
                              final rawValue =
                                  levelValueAt(item, currentLevel) ?? '';
                              final persisted = _ledgerHasUnit(
                                ledger,
                                currentLevel,
                                rawValue,
                                currentPath,
                              );
                              final selected = _isSelected(
                                rawValue,
                                currentPath,
                              );
                              final directlySelected = _isDirectlySelected(
                                rawValue,
                                currentLevel,
                                currentPath,
                              );
                              // Indeterminate parent: a non-leaf row (has drill)
                              // that is not itself fully selected, but some of
                              // its descendant leaves are marked. Leaves and
                              // already-selected rows skip this check.
                              final partial =
                                  onDrill != null &&
                                  !persisted &&
                                  !selected &&
                                  _isPartial(
                                    allLeaves,
                                    rawValue,
                                    currentLevel,
                                    currentPath,
                                    ledger,
                                  );
                              return LifetimeMarkingScopeRow(
                                primary: itemDisplayName(
                                  item,
                                  useHebrew: useHebrew,
                                ),
                                secondary: useHebrew
                                    ? itemDisplayName(item, useHebrew: false)
                                    : null,
                                hasDrill: onDrill != null,
                                visual: persisted
                                    ? MarkingRowVisual.direct
                                    : selected && !directlySelected
                                    ? MarkingRowVisual.implicit
                                    : selected
                                    ? MarkingRowVisual.direct
                                    : partial
                                    ? MarkingRowVisual.partial
                                    : MarkingRowVisual.none,
                                isPersisted: persisted,
                                isImplicit:
                                    !persisted && selected && !directlySelected,
                                lightSurface: true,
                                onDrill: onDrill,
                                onToggle: () => _toggleSelection(
                                  rawValue,
                                  currentLevel,
                                  currentPath,
                                ),
                              );
                            },
                            bottomActions: (context) => Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _saving || _selections.isEmpty
                                          ? null
                                          : () {
                                              setState(_selections.clear);
                                            },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            context.colors.brandInkMuted,
                                        side: const BorderSide(
                                          color: Color(0xFFD7DEEA),
                                        ),
                                      ),
                                      child: Text(l10n.clearSelection),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            context.colors.brandBlue,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: _saving || _selections.isEmpty
                                          ? null
                                          : () => _markSelections(
                                              List.of(_selections),
                                            ),
                                      child: _saving
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(l10n.save),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
