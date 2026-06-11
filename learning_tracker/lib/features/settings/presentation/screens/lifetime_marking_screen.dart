import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
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
      backgroundColor: AppTheme.brandCreamCard,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.brandInk,
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
              color: AppTheme.brandInk,
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
              AppTheme.brandCreamCard,
              AppTheme.brandBlueSoft.withValues(alpha: 0.22),
              AppTheme.brandCream,
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
                    color: AppTheme.brandInkMuted,
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
    final useHebrew = ref.watch(useHebrewTermsProvider);
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

    final color = AppTheme.getCurriculumColor(curriculum);
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
            border: Border.all(color: AppColors.surfaceE9),
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
                            color: AppTheme.brandInk,
                          ),
                        ),
                        if (!useHebrew) ...[
                          const SizedBox(height: 2),
                          Text(
                            curriculumHebrewName(curriculum),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.brandInkMuted,
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
                        color: AppTheme.brandInk,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 34,
                    color: AppTheme.brandInkMuted,
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
                        color: AppTheme.brandInkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '—',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.brandInkMuted,
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
  final _panelKey = GlobalKey<HierarchySelectionPanelState>();

  CurriculumId get _curriculum => CurriculumId.values.firstWhere(
    (c) => c.storageKey == widget.curriculumId,
    orElse: () => CurriculumId.mishnayos,
  );

  int get _currentLevel => ((_panelKey.currentState?.canGoBack ?? false)
      ? _currentDisplayItems.isNotEmpty
            ? _currentDisplayItems.length
            : 1
      : 1);

  bool _isSelected(String value, List<String> currentPath) {
    final currentLevel = currentPath.length + 1;
    if (_selections.any((s) => s.level == currentLevel && s.value == value)) {
      return true;
    }
    for (var i = 0; i < currentPath.length; i++) {
      final ancestorLevel = i + 1;
      final ancestorValue = currentPath[i];
      if (_selections.any(
        (s) => s.level == ancestorLevel && s.value == ancestorValue,
      )) {
        return true;
      }
    }
    return false;
  }

  bool _isDirectlySelected(String value, int currentLevel) {
    return _selections.any((s) => s.level == currentLevel && s.value == value);
  }

  void _toggleSelection(String value, int level) {
    setState(() {
      final idx = _selections.indexWhere(
        (s) => s.level == level && s.value == value,
      );
      if (idx >= 0) {
        _selections.removeAt(idx);
      } else {
        _selections.removeWhere((s) => s.level > level);
        _selections.add(ScopeEntry(level: level, value: value));
      }
    });
  }

  // PP-10 fix: returns the hierarchy level the current panel is displaying so
  // both _markAllCurrentLevel and _deselectAllCurrentLevel use the same value.
  int get _effectiveLevel {
    if (_currentDisplayItems.isEmpty) return 1;
    return _currentDisplayItems.first.level1.isEmpty ? 1 : _currentLevel;
  }

  // PP-10 fix: true when every item in the current panel is already selected.
  bool get _allCurrentSelected {
    if (_currentDisplayItems.isEmpty) return false;
    final level = _effectiveLevel;
    for (final item in _currentDisplayItems) {
      final rawValue = levelValueAt(item, level) ?? '';
      if (rawValue.isNotEmpty &&
          !_selections.any((s) => s.level == level && s.value == rawValue)) {
        return false;
      }
    }
    return true;
  }

  void _markAllCurrentLevel() {
    final level = _effectiveLevel;
    setState(() {
      _selections.removeWhere((s) => s.level == level);
      for (final item in _currentDisplayItems) {
        final rawValue = levelValueAt(item, level) ?? '';
        if (rawValue.isNotEmpty) {
          _selections.add(ScopeEntry(level: level, value: rawValue));
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
  ) {
    return ledger.any(
      (e) => e.entryScope == 'level$level' && e.unitIdentifier == value,
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lifetimeMarkSaveError(e.toString()))),
      );
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ledgerAsync = ref.watch(
      curriculumLedgerProvider(widget.curriculumId),
    );
    final ledger = ledgerAsync.asData?.value ?? const <LearningLedgerData>[];
    final useHebrew = ref.watch(useHebrewTermsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.brandCreamCard,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.brandInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _hasNavStack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: AppTheme.brandBlueDeep,
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
              AppTheme.brandCreamCard,
              AppTheme.brandBlueSoft.withValues(alpha: 0.22),
              AppTheme.brandCream,
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
                      border: Border.all(color: AppColors.surfaceE9),
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
                            const Icon(
                              Icons.playlist_add_check_outlined,
                              color: AppTheme.brandBlue,
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
                                      color: AppTheme.brandInk,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.lifetimeSelectScreenSubtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppTheme.brandInkMuted,
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
                            color: AppTheme.brandBlueSoft.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.surfaceE9),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.draw_outlined,
                                color: AppTheme.brandBlue,
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
                                            color: AppTheme.brandInk,
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
                                            color: AppTheme.brandInkMuted,
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
                            foregroundColor: AppTheme.brandBlue,
                            side: BorderSide(
                              color: AppTheme.brandBlue.withValues(alpha: 0.45),
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
                            onNavigationChanged: (path, _) =>
                                setState(() => _hasNavStack = path.isNotEmpty),
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
                              );
                              final selected = _isSelected(
                                rawValue,
                                currentPath,
                              );
                              final directlySelected = _isDirectlySelected(
                                rawValue,
                                currentLevel,
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
                                    : MarkingRowVisual.none,
                                isPersisted: persisted,
                                isImplicit:
                                    !persisted && selected && !directlySelected,
                                lightSurface: true,
                                onDrill: onDrill,
                                onToggle: () =>
                                    _toggleSelection(rawValue, currentLevel),
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
                                        foregroundColor: AppTheme.brandInkMuted,
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
                                        backgroundColor: AppTheme.brandBlue,
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
