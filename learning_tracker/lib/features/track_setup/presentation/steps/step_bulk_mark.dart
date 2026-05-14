import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/track_setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Selection result from the self-paced prior progress step.
class SelfPacedPriorCompletionSelection {
  const SelfPacedPriorCompletionSelection({
    required this.markAll,
    required this.selectedScopes,
  });

  final bool markAll;
  final List<ScopeEntry> selectedScopes;
}

class SelfPacedPriorProgressStep extends ConsumerWidget {
  const SelfPacedPriorProgressStep({
    required this.curriculumId,
    required this.scopeSelections,
    required this.onSkip,
    required this.onMarkCompleted,
    super.key,
  });

  final CurriculumId curriculumId;
  final List<ScopeEntry>? scopeSelections;
  final VoidCallback onSkip;
  final ValueChanged<SelfPacedPriorCompletionSelection> onMarkCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasExplicitScopes =
        scopeSelections != null && scopeSelections!.isNotEmpty;
    final generatedScopesAsync = hasExplicitScopes
        ? null
        : ref.watch(curriculumContentProvider(curriculumId));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.priorLearningTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Do you want to mark parts you already learned as completed?',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose which sections to mark in '
            '${curriculumLabelText(ref, curriculum: curriculumId)}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: hasExplicitScopes
                ? SelfPacedSelectionList(
                    scopeSelections: scopeSelections,
                    selectAllByDefault: false,
                    onSkip: onSkip,
                    onMarkCompleted: onMarkCompleted,
                  )
                : generatedScopesAsync!.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => SelfPacedSelectionList(
                      scopeSelections: const [],
                      selectAllByDefault: false,
                      onSkip: onSkip,
                      onMarkCompleted: onMarkCompleted,
                    ),
                    data: (items) {
                      final seen = <String>{};
                      final topLevelSelections = <ScopeEntry>[];
                      for (final item in items) {
                        final level1 = item.level1;
                        if (level1.isEmpty) continue;
                        if (!seen.add(level1)) continue;
                        topLevelSelections.add(
                          ScopeEntry(level: 1, value: level1),
                        );
                      }
                      return SelfPacedSelectionList(
                        scopeSelections: topLevelSelections,
                        selectAllByDefault: false,
                        onSkip: onSkip,
                        onMarkCompleted: onMarkCompleted,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class SelfPacedSelectionList extends StatefulWidget {
  const SelfPacedSelectionList({
    required this.scopeSelections,
    required this.selectAllByDefault,
    required this.onSkip,
    required this.onMarkCompleted,
    super.key,
  });

  final List<ScopeEntry>? scopeSelections;
  final bool selectAllByDefault;
  final VoidCallback onSkip;
  final ValueChanged<SelfPacedPriorCompletionSelection> onMarkCompleted;

  @override
  State<SelfPacedSelectionList> createState() => _SelfPacedSelectionListState();
}

class _SelfPacedSelectionListState extends State<SelfPacedSelectionList> {
  late final List<ScopeEntry> _entries;
  final _selectedIndexes = <int>{};
  bool _markAll = false;

  @override
  void initState() {
    super.initState();
    _entries = widget.scopeSelections ?? const <ScopeEntry>[];
    if (_entries.isNotEmpty && widget.selectAllByDefault) {
      _selectedIndexes.addAll(List<int>.generate(_entries.length, (i) => i));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final canMark = _markAll || _selectedIndexes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.priorLearningAlreadyCompleted,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        SelectionCard(
          title: l10n.priorLearningMarkEverything,
          subtitle: l10n.priorLearningMarkEverythingSubtitle,
          selected: _markAll,
          onChanged: (checked) {
            setState(() {
              _markAll = checked;
              _selectedIndexes
                ..clear()
                ..addAll(
                  checked
                      ? List<int>.generate(_entries.length, (index) => index)
                      : const <int>[],
                );
            });
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _entries.isEmpty
              ? Center(
                  child: Text(
                    l10n.priorLearningNoFolders,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final selected = _selectedIndexes.contains(index);
                    return SelectionCard(
                      title: entry.value,
                      subtitle: l10n.priorLearningSelectedFolder,
                      selected: selected,
                      onChanged: (checked) {
                        setState(() {
                          _markAll = false;
                          if (checked) {
                            _selectedIndexes.add(index);
                          } else {
                            _selectedIndexes.remove(index);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onSkip,
                child: Text(l10n.actionSkipForNow),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: canMark
                    ? () {
                        final selectedScopes = (_markAll && _entries.isNotEmpty)
                            ? _entries
                            : _selectedIndexes.map((i) => _entries[i]).toList();
                        widget.onMarkCompleted(
                          SelfPacedPriorCompletionSelection(
                            markAll: _markAll && _entries.isEmpty,
                            selectedScopes: selectedScopes,
                          ),
                        );
                      }
                    : null,
                child: Text(l10n.actionMarkCompleted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SelectionCard extends StatelessWidget {
  const SelectionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Checkbox(
                value: selected,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
