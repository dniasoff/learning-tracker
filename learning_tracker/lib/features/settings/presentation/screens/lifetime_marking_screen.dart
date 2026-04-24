import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';

@RoutePage()
class LifetimeMarkingScreen extends ConsumerWidget {
  const LifetimeMarkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(
      globalLifetimeCurriculaProvider(ref.watch(activeProfileIdProvider)),
    );

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Lifetime Learning')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: CurriculumId.values.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Mark what you already learned'),
                subtitle: Text(
                  'Choose a curriculum, then mark sections as lifetime learned.',
                ),
              ),
            );
          }

          final curriculum = CurriculumId.values[index - 1];
          final summary = summariesAsync.asData?.value.firstWhere(
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

          return Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text('${curriculum.displayNameHe} • ${curriculum.displayNameEn}'),
              subtitle: Text(
                '${(summary.percentage * 100).toStringAsFixed(2)}% • '
                '${summary.learnedLeafCount}/${summary.totalLeafCount}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LifetimeCurriculumMarkingScreen(
                    curriculumId: curriculum.storageKey,
                  ),
                ),
              ),
            ),
          );
        },
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

  int get _currentLevel => _breadcrumbs.isEmpty ? 1 : _breadcrumbs.last.level + 1;

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
      if (_selections.any((s) => s.level == crumb.level && s.value == crumb.value)) {
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

  Future<void> _markSelections(List<ScopeEntry> selections) async {
    if (_saving) return;
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
          content: Text('Marked ${unique.length} lifetime selection(s).'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save lifetime marks: $e')),
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
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(curriculumContentProvider(_curriculum));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text: '${_curriculum.displayNameHe} • ${_curriculum.displayNameEn}',
        ),
      ),
      body: contentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Unable to load curriculum content: $e'),
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
          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: ListTile(
                  leading: const Icon(Icons.history_edu_outlined),
                  title: const Text('Mark as lifetime learned'),
                  subtitle: Text(
                    'Selected: ${_selections.length} • Level $_currentLevel',
                  ),
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: values.isEmpty
                          ? null
                          : () => _markAllCurrentLevel(values),
                      icon: const Icon(Icons.select_all),
                      label: const Text('Mark all'),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              if (_breadcrumbs.isNotEmpty)
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _breadcrumbs.clear()),
                        child: const Text('Root'),
                      ),
                      for (var i = 0; i < _breadcrumbs.length; i++)
                        TextButton(
                          onPressed: i < _breadcrumbs.length - 1
                              ? () => setState(() {
                                  _breadcrumbs.removeRange(i + 1, _breadcrumbs.length);
                                })
                              : null,
                          child: Text(_breadcrumbs[i].value),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: values.length,
                  itemBuilder: (context, index) {
                    final value = values[index];
                    final selected = _isSelected(value);
                    final implicit = selected && !_isDirectlySelected(value);
                    return ListTile(
                      leading: Checkbox(
                        value: selected,
                        onChanged: implicit ? null : (_) => _toggleSelection(value),
                      ),
                      title: Text(
                        value,
                        style: implicit
                            ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
                            : null,
                      ),
                      subtitle: Text(
                        valueToEnglish[value] ?? value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: canDrill
                          ? IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => _drillInto(value),
                            )
                          : null,
                      onTap: () => _toggleSelection(value),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving || _selections.isEmpty
                            ? null
                            : () => setState(() => _selections.clear()),
                        child: const Text('Clear selection'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving || _selections.isEmpty
                            ? null
                            : () => _markSelections(List.of(_selections)),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save lifetime marks'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
