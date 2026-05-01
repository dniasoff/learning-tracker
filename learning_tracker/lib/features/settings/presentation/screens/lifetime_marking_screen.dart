import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_folder_styled_widgets.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class LifetimeMarkingScreen extends ConsumerWidget {
  const LifetimeMarkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final summariesAsync = ref.watch(
      globalLifetimeCurriculaProvider(ref.watch(activeProfileIdProvider)),
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
        // Balance default leading (56px) so the title is visually centered on screen.
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

class _LifetimeLibraryCategoryCard extends StatelessWidget {
  const _LifetimeLibraryCategoryCard({
    required this.curriculum,
    required this.summariesAsync,
    required this.onTap,
  });

  final CurriculumId curriculum;
  final AsyncValue<List<CurriculumLifetimeSummary>> summariesAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
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
            border: Border.all(color: const Color(0xFFE9ECF2)),
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
                        Text(
                          curriculum.displayNameEn,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          curriculum.displayNameHe,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.brandInkMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
  final List<ScopeEntry> _breadcrumbs = [];
  final List<ScopeEntry> _selections = [];
  bool _saving = false;

  CurriculumId get _curriculum => CurriculumId.values.firstWhere(
    (c) => c.storageKey == widget.curriculumId,
    orElse: () => CurriculumId.mishnayos,
  );

  int get _currentLevel =>
      _breadcrumbs.isEmpty ? 1 : _breadcrumbs.last.level + 1;

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
      if (value != null && value.isNotEmpty && seen.add(value)) {
        result.add(value);
      }
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
      final idx = _selections.indexWhere(
        (s) => s.level == _currentLevel && s.value == value,
      );
      if (idx >= 0) {
        _selections.removeAt(idx);
      } else {
        _selections.removeWhere((s) => s.level > _currentLevel);
        _selections.add(ScopeEntry(level: _currentLevel, value: value));
      }
    });
  }

  void _drillInto(String value) {
    if (_currentLevel >= 4) return;
    setState(() {
      _breadcrumbs.add(ScopeEntry(level: _currentLevel, value: value));
    });
  }

  void _markAllCurrentLevel(List<String> values) {
    setState(() {
      _selections.removeWhere((s) => s.level == _currentLevel);
      for (final value in values) {
        _selections.add(ScopeEntry(level: _currentLevel, value: value));
      }
    });
  }

  bool _ledgerHasUnit(
    List<LearningLedgerData> ledger,
    int level,
    String value,
  ) {
    return ledger.any(
      (e) => e.unitType == 'level$level' && e.unitIdentifier == value,
    );
  }

  MarkingRowVisual _visualFor(String value, List<LearningLedgerData> ledger) {
    if (_ledgerHasUnit(ledger, _currentLevel, value)) {
      return MarkingRowVisual.direct;
    }
    final selected = _isSelected(value);
    final implicit = selected && !_isDirectlySelected(value);
    if (implicit) return MarkingRowVisual.implicit;
    if (selected) return MarkingRowVisual.direct;
    return MarkingRowVisual.none;
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
            unitType: 'level${selection.level}',
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
    ref.invalidate(globalLifetimeCurriculaProvider(profileId));
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
    final contentAsync = ref.watch(curriculumContentProvider(_curriculum));
    final ledgerAsync = ref.watch(
      curriculumLedgerProvider(widget.curriculumId),
    );
    final ledger = ledgerAsync.asData?.value ?? const <LearningLedgerData>[];

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.brandCreamCard,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.brandInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: AppBarTitle(
          text: '${_curriculum.displayNameHe} • ${_curriculum.displayNameEn}',
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
        child: contentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.contentLoadError(e.toString())),
            ),
          ),
          data: (allItems) {
            final values = _valuesAtCurrentLevel(allItems);
            final canDrill = _currentLevel < 4;
            final valueToEnglish = <String, String>{};
            for (final item in allItems) {
              final key = _getItemLevel(item, _currentLevel);
              if (key == null || key.isEmpty) continue;
              valueToEnglish.putIfAbsent(key, () => item.displayNameEn);
            }
            return SafeArea(
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
                          border: Border.all(color: const Color(0xFFE9ECF2)),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.lifetimeSelectScreenTitle,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.brandInk,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.lifetimeSelectScreenSubtitle,
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
                                border: Border.all(
                                  color: const Color(0xFFE9ECF2),
                                ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        Text(
                                          l10n.lifetimeMarkAsLearnedLine(
                                            _selections.length,
                                            _currentLevel,
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
                            OutlinedButton.icon(
                              onPressed: values.isEmpty
                                  ? null
                                  : () => _markAllCurrentLevel(values),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.brandBlue,
                                side: BorderSide(
                                  color: AppTheme.brandBlue.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.select_all, size: 20),
                              label: Text(l10n.selectAllInThisList),
                            ),
                            if (_breadcrumbs.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 40,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(_breadcrumbs.clear);
                                      },
                                      child: Text(
                                        l10n.breadcrumbsRoot,
                                        style: const TextStyle(
                                          color: AppTheme.brandBlue,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    for (
                                      var i = 0;
                                      i < _breadcrumbs.length;
                                      i++
                                    )
                                      TextButton(
                                        onPressed: i < _breadcrumbs.length - 1
                                            ? () {
                                                setState(() {
                                                  _breadcrumbs.removeRange(
                                                    i + 1,
                                                    _breadcrumbs.length,
                                                  );
                                                });
                                              }
                                            : null,
                                        child: Text(
                                          _breadcrumbs[i].value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: i < _breadcrumbs.length - 1
                                                ? AppTheme.brandBlue
                                                : AppTheme.brandInkMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Expanded(
                              child: LifetimeFolderListPanel(
                                insetBackground: false,
                                child: values.isEmpty
                                    ? Center(
                                        child: Text(
                                          l10n.noItemsAtThisLevel,
                                          style: const TextStyle(
                                            color: AppTheme.brandInkMuted,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: EdgeInsets.zero,
                                        itemCount: values.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox.shrink(),
                                        itemBuilder: (context, index) {
                                          final value = values[index];
                                          final persisted = _ledgerHasUnit(
                                            ledger,
                                            _currentLevel,
                                            value,
                                          );
                                          return LifetimeMarkingScopeRow(
                                            primary: value,
                                            secondary: valueToEnglish[value],
                                            hasDrill: canDrill,
                                            visual: _visualFor(value, ledger),
                                            isPersisted: persisted,
                                            isImplicit:
                                                !persisted &&
                                                _isSelected(value) &&
                                                !_isDirectlySelected(value),
                                            lightSurface: true,
                                            onDrill: canDrill
                                                ? () => _drillInto(value)
                                                : null,
                                            onToggle: () =>
                                                _toggleSelection(value),
                                          );
                                        },
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
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
                                        : () {
                                            _markSelections(
                                              List.of(_selections),
                                            );
                                          },
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
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
