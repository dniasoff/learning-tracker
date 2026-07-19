import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/step_starting_position_calendar.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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

class _StartingPositionStepState extends ConsumerState<StartingPositionStep> {
  List<ContentItem>? _allItems;
  bool _loading = true;

  // AUD-tracks-04 (EH-3): _loadContent's catch clause used to silently
  // fall through to an empty _containers/_leaves list with no error
  // affordance and a permanently-disabled Continue button. Track the
  // failure explicitly so build() can render AppErrorView with retry
  // instead of an indistinguishable blank list.
  Object? _loadError;
  StackTrace? _loadErrorStackTrace;

  // Drill-down state: level2 containers → leaf items within selected container.
  List<ContentItem> _containers = [];
  ContentItem? _selectedContainer;
  List<ContentItem> _leaves = [];
  ContentItem? _selectedLeaf;

  // 1-based level indices for container and leaf, resolved after content loads.
  // Used with CurriculumLabels.level() + inLanguage() so they respect the
  // Hebrew Terms toggle at render time rather than being baked in as English.
  int? _containerLevelIndex;
  int? _leafLevelIndex;

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

      // Compute 0-based container level index, then convert to 1-based for
      // CurriculumLabels.level(). Store indices rather than English strings so
      // the build method can apply the Hebrew Terms toggle at render time.
      final levelCount = config.levelLabels.length;
      final containerLvl0 = levelCount >= 3 ? 1 : 0; // 0-based
      final containerLvl1 = containerLvl0 + 1; // 1-based
      final leafLvl1 = containerLvl1 + 1; // 1-based

      final containers = <String, ContentItem>{};
      for (final item in items) {
        if (item.isLeaf) continue;
        final key = containerLvl0 == 0 ? item.level1 : item.level2;
        if (key != null && !containers.containsKey(key)) {
          containers[key] = item;
        }
      }

      if (!mounted) return;
      final containerList = containers.values.toList();
      final defaultContainer = containerList.isNotEmpty
          ? containerList.first
          : null;
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
        _containerLevelIndex = containerLvl1;
        _leafLevelIndex = leafLvl1;
        _loading = false;
        _loadError = null;
        _loadErrorStackTrace = null;
      });
    } on Exception catch (e, st) {
      AppLogger.instance.error(
        event: 'tracks_starting_position_load_failed',
        fields: {'curriculumId': widget.curriculumId.storageKey},
        exception: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
        _loadErrorStackTrace = st;
      });
    }
  }

  /// Retry affordance for [AppErrorView] — re-runs [_loadContent] after a
  /// load failure (AUD-tracks-04).
  void _retryLoadContent() {
    setState(() {
      _loading = true;
      _loadError = null;
      _loadErrorStackTrace = null;
    });
    unawaited(_loadContent());
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

    // AUD-tracks-04: a load failure must surface a distinct, actionable
    // error affordance — not fall through to an empty container list with
    // a permanently-disabled Continue button and no indication anything
    // went wrong.
    if (_loadError != null) {
      return AppErrorView(
        error: _loadError!,
        stackTrace: _loadErrorStackTrace,
        onRetry: _retryLoadContent,
      );
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final useHebrewTerms = domainTermLabels(ref).isHebrew;
    final variant = ref.watch(currentTransliterationVariantProvider);

    // Resolve level labels respecting the Hebrew Terms toggle + nusach.
    final containerLabel =
        _containerLevelIndex != null &&
            _containerLevelIndex! <= CurriculumLabels.depth(widget.curriculumId)
        ? CurriculumLabels.level(
            widget.curriculumId,
            _containerLevelIndex!,
          ).inLanguage(useHebrew: useHebrewTerms, variant: variant)
        : l10n.startingPositionSectionLabel;
    final leafLabel =
        _leafLevelIndex != null &&
            _leafLevelIndex! <= CurriculumLabels.depth(widget.curriculumId)
        ? CurriculumLabels.level(
            widget.curriculumId,
            _leafLevelIndex!,
          ).inLanguage(useHebrew: useHebrewTerms, variant: variant)
        : l10n.startingPositionItemFallbackLabel;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.startingPositionTitle,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.startingPositionWhereAreYou(widget.programName),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.startingPositionSelectInstruction(leafLabel),
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
                      // AX-3 / AUD-tracks-17: icon-only close button had no
                      // tooltip/semanticLabel. `tooltip:` alone does not
                      // populate `SemanticsData.label` on the current
                      // Flutter SDK (it only sets `.tooltip`), so the Icon
                      // also carries `semanticLabel`, which Flutter surfaces
                      // as `Semantics(label:)` — the field TalkBack/
                      // VoiceOver read. Reuses the existing `clearSelection`
                      // ARB key already used for the identical
                      // clear-current-selection affordance in
                      // lifetime_marking_screen.dart, rather than minting a
                      // near-duplicate key.
                      tooltip: l10n.clearSelection,
                      icon: Icon(
                        Icons.close,
                        semanticLabel: l10n.clearSelection,
                      ),
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
                    tooltip: l10n.startingPositionBackToListTooltip(
                      containerLabel,
                    ),
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
            child: Text(l10n.actionStartHere),
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
