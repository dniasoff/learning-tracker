import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/track_setup/presentation/steps/step_starting_position_calendar.dart';

/// Starting position step for program tracks (Screen 8 program mode).
///
/// Delegates to [StartingPositionCalendarMode] for calendar-based programs.
/// For content-based programs shows a two-level drill-down (container → leaf).
class StartingPositionStep extends ConsumerStatefulWidget {
  const StartingPositionStep({
    required this.programName,
    required this.curriculumId,
    required this.selectedProgram,
    required this.onComplete,
    super.key,
  });

  final String programName;
  final CurriculumId curriculumId;
  final LearningProgramData? selectedProgram;
  final ValueChanged<String?> onComplete;

  @override
  ConsumerState<StartingPositionStep> createState() =>
      _StartingPositionStepState();
}

class _StartingPositionStepState
    extends ConsumerState<StartingPositionStep> {
  List<ContentItem>? _allItems;
  bool _loading = true;

  // Drill-down state: level2 containers → leaf items within selected container.
  List<ContentItem> _containers = [];
  ContentItem? _selectedContainer;
  List<ContentItem> _leaves = [];
  ContentItem? _selectedLeaf;

  String _containerLabel = 'Section';
  String _leafLabel = 'Item';

  bool get _isCalendarProgram =>
      widget.selectedProgram?.isCalendarProgram ?? false;

  @override
  void initState() {
    super.initState();
    if (!_isCalendarProgram) {
      _loadContent();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadContent() async {
    try {
      final repo = ref.read(contentRepositoryProvider);
      final config = await repo.getHierarchyConfig(widget.curriculumId);
      final items = await repo.getContentForCurriculum(widget.curriculumId);

      final labels = config.levelLabels;
      final containerLvl = labels.length >= 3 ? 1 : 0;
      final containerLevelLabel = containerLvl < labels.length
          ? labels[containerLvl]
          : 'Section';
      final leafLevelLabel = containerLvl + 1 < labels.length
          ? labels[containerLvl + 1]
          : 'Item';

      final containers = <String, ContentItem>{};
      for (final item in items) {
        if (item.isLeaf) continue;
        final key = containerLvl == 0 ? item.level1 : item.level2;
        if (key != null && !containers.containsKey(key)) {
          containers[key] = item;
        }
      }

      if (!mounted) return;
      final containerList = containers.values.toList();
      final defaultContainer =
          containerList.isNotEmpty ? containerList.first : null;
      final defaultLeaves = defaultContainer == null
          ? <ContentItem>[]
          : items.where((item) {
              if (!item.isLeaf) return false;
              if (defaultContainer.level2 != null) {
                return item.level2 == defaultContainer.level2;
              }
              return item.level1 == defaultContainer.level1;
            }).toList();
      setState(() {
        _allItems = items;
        _containers = containerList;
        _selectedContainer = defaultContainer;
        _leaves = defaultLeaves;
        _selectedLeaf = defaultLeaves.isNotEmpty ? defaultLeaves.first : null;
        _containerLabel = containerLevelLabel;
        _leafLabel = leafLevelLabel;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onContainerSelected(ContentItem container) {
    if (_allItems == null) return;
    final leaves = _allItems!.where((item) {
      if (!item.isLeaf) return false;
      if (container.level2 != null) return item.level2 == container.level2;
      return item.level1 == container.level1;
    }).toList();
    setState(() {
      _selectedContainer = container;
      _leaves = leaves;
      _selectedLeaf = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedContainer = null;
      _leaves = [];
      _selectedLeaf = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCalendarProgram && widget.selectedProgram != null) {
      return StartingPositionCalendarMode(
        selectedProgram: widget.selectedProgram!,
        onComplete: widget.onComplete,
      );
    }

    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Starting Position', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Where are you in ${widget.programName}?',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Select the $_leafLabel you are currently up to.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedLeaf != null)
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CurriculumLabel.item(
                        _selectedLeaf!,
                        mode: CurriculumLabelMode.breadcrumb,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearSelection,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (_selectedContainer != null && _selectedLeaf == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _clearSelection,
                    tooltip: 'Back to $_containerLabel list',
                  ),
                  CurriculumLabel.item(
                    _selectedContainer!,
                    style: theme.textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          if (_selectedLeaf == null)
            Expanded(
              child: _selectedContainer == null
                  ? _buildContainerList(theme)
                  : _buildLeafList(theme),
            )
          else
            const Spacer(),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _selectedLeaf != null
                ? () => widget.onComplete(_selectedLeaf!.sefariaRef)
                : null,
            child: const Text('Start here'),
          ),
        ],
      ),
    );
  }

  Widget _buildContainerList(ThemeData theme) {
    return ListView.builder(
      itemCount: _containers.length,
      itemBuilder: (context, index) {
        final container = _containers[index];
        return ListTile(
          title: CurriculumLabel.item(container),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _onContainerSelected(container),
        );
      },
    );
  }

  Widget _buildLeafList(ThemeData theme) {
    return ListView.builder(
      itemCount: _leaves.length,
      itemBuilder: (context, index) {
        final leaf = _leaves[index];
        final isSelected = _selectedLeaf?.sefariaRef == leaf.sefariaRef;
        return ListTile(
          title: CurriculumLabel.item(leaf),
          selected: isSelected,
          selectedTileColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.3,
          ),
          leading: isSelected
              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
              : const Icon(Icons.circle_outlined),
          onTap: () => setState(() => _selectedLeaf = leaf),
        );
      },
    );
  }
}
