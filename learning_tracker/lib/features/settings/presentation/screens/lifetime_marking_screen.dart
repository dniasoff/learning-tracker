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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: LifetimeFolderGradients.settingsAppBar,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: AppBarTitle(text: l10n.lifetimeLearning),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LifetimeFolderGradients.settingsPageBackground,
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          LifetimeFolderSurface(
            gradient: LifetimeFolderGradients.settingsCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LifetimeFolderPageHeader(
                  title: l10n.lifetimeAddHeaderTitle,
                  subtitle: l10n.lifetimeAddHeaderSubtitle,
                ),
                const SizedBox(height: 12),
                LifetimeFolderFrostedHint(
                  leading: const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                  title: l10n.lifetimeHowItWorksTitle,
                  subtitle: l10n.lifetimeHowItWorksBody,
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < CurriculumId.values.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  _curriculumEntry(
                    context,
                    CurriculumId.values[i],
                    summariesAsync,
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _curriculumEntry(
    BuildContext context,
    CurriculumId curriculum,
    AsyncValue<List<CurriculumLifetimeSummary>> summariesAsync,
  ) {
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

    return LifetimeCurriculumFolderRow(
      titleEn: curriculum.displayNameEn,
      titleHe: curriculum.displayNameHe,
      trailingPercent: percentTextForCurriculum(summary) ?? '—',
      showLearnedBadge: summary.learnedLeafCount > 0,
      isExpandableListStyle: false,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LifetimeCurriculumMarkingScreen(
              curriculumId: curriculum.storageKey,
            ),
          ),
        );
      },
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

  bool _ledgerHasUnit(List<LearningLedgerData> ledger, int level, String value) {
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
      for (final selection in selections) {
        final key = '${selection.level}:${selection.value}';
        if (!unique.add(key)) continue;
        await repo.recordCompletion(
          curriculumId: _curriculum.storageKey,
          unitType: 'level${selection.level}',
          unitIdentifier: selection.value,
          unitDisplayNameHe: selection.value,
          unitDisplayNameEn: selection.value,
          trackType: 'personal',
          trackId: null,
          markedBy: profileId,
          isManual: true,
        );
      }

      _invalidateComputedViews();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.lifetimeMarkSavedCount(unique.length)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.lifetimeMarkSaveError(e.toString())),
        ),
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
    final ledgerAsync = ref.watch(curriculumLedgerProvider(widget.curriculumId));
    final ledger = ledgerAsync.asData?.value ?? const <LearningLedgerData>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: LifetimeFolderGradients.settingsAppBar,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: AppBarTitle(
          text: '${_curriculum.displayNameHe} • ${_curriculum.displayNameEn}',
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LifetimeFolderGradients.settingsPageBackground,
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: [
                  Expanded(
                    child: LifetimeFolderSurface(
                      gradient: LifetimeFolderGradients.settingsCard,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LifetimeFolderPageHeader(
                            title: l10n.lifetimeSelectScreenTitle,
                            subtitle: l10n.lifetimeSelectScreenSubtitle,
                            icon: Icons.playlist_add_check_outlined,
                          ),
                          const SizedBox(height: 10),
                          LifetimeFolderFrostedHint(
                            leading: Icon(
                              Icons.draw_outlined,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            title: l10n.lifetimeMarkAsLearnedTitle,
                            subtitle: l10n.lifetimeMarkAsLearnedLine(
                              _selections.length,
                              _currentLevel,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: values.isEmpty
                                ? null
                                : () => _markAllCurrentLevel(values),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
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
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  for (var i = 0; i < _breadcrumbs.length; i++)
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
                                        style: const TextStyle(
                                          color: Colors.white,
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
                              child: values.isEmpty
                                  ? Center(
                                      child: Text(
                                        l10n.noItemsAtThisLevel,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.75,
                                          ),
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
                                          isImplicit: !persisted &&
                                              _isSelected(value) &&
                                              !_isDirectlySelected(value),
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
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white38,
                                    ),
                                  ),
                                  child: Text(l10n.clearSelection),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppTheme.brandGoldDeep,
                                  ),
                                  onPressed: _saving || _selections.isEmpty
                                      ? null
                                      : () {
                                          _markSelections(List.of(_selections));
                                        },
                                  child: _saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.brandGoldDeep,
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
