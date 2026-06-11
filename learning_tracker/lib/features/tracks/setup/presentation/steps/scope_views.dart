import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/steps/scope_tiles.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Shared callback types used by both views
// ---------------------------------------------------------------------------

typedef ScopeToggleCallback = void Function(ContentItem item);
typedef ScopeDrillCallback = void Function(ContentItem item);
typedef ScopeSelectAllCallback = void Function();

// ---------------------------------------------------------------------------
// Top-level view (no breadcrumbs)
// ---------------------------------------------------------------------------

/// Shows the "Learn All" hero + list of level-1 items for the first drill step.
///
/// [items] must be pre-rendered via [groupItemsByNextLevel] — callers must not
/// pass raw [ContentItem]s with Sefaria data strings as display names.
class ScopeTopLevelView extends ConsumerWidget {
  const ScopeTopLevelView({
    required this.curriculumId,
    required this.items,
    required this.useHebrew,
    required this.selections,
    required this.allDirectlySelected,
    required this.currentLevel,
    required this.maxSelectableLevel,
    required this.labelForLevel,
    required this.scopeDescription,
    required this.scopeIcon,
    required this.childCountForItem,
    required this.isDirectlySelected,
    required this.onLearnAll,
    required this.onToggle,
    required this.onDrill,
    required this.onToggleAll,
    required this.onDone,
    super.key,
  });

  final CurriculumId curriculumId;

  /// Pre-rendered content items at the current level.
  final List<ContentItem> items;

  /// Whether to show Hebrew display names.
  final bool useHebrew;

  final List<ScopeEntry> selections;
  final bool allDirectlySelected;
  final int currentLevel;
  final int maxSelectableLevel;
  final String Function(int level) labelForLevel;
  final String Function(String rawValue) scopeDescription;
  final IconData Function(String rawValue) scopeIcon;
  final int Function(ContentItem item) childCountForItem;
  final bool Function(ContentItem item) isDirectlySelected;
  final VoidCallback onLearnAll;
  final ScopeToggleCallback onToggle;
  final ScopeDrillCallback onDrill;
  final ScopeSelectAllCallback onToggleAll;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final canDrillDeeper = currentLevel < maxSelectableLevel;

    // The level-1 prompt wraps a domain-term level word ([labelForLevel] is
    // resolved with the Hebrew-Terms toggle, the same toggle the curriculum
    // chip to its left honours). Select the prompt TEMPLATE by that same
    // toggle ([useHebrew]) so the whole segment is script-consistent: when
    // Hebrew Terms is ON the connective chrome is Hebrew ("בחרו ספר") even in
    // the English UI locale — no leftover Latin "Choose a" wrapping a Hebrew
    // word — and when OFF it stays fully English ("Choose a Sefer").
    final promptL10n = useHebrew
        ? lookupAppLocalizations(const Locale('he'))
        : lookupAppLocalizations(const Locale('en'));
    final chooseLevelPrompt = promptL10n.scopeChooseLevelPrompt(
      labelForLevel(1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Learn All" hero card
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.brandBlueDeep, AppTheme.brandBlueBright],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26084BB8),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onLearnAll,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.learnEntireCurriculumCta,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.learnEntireCurriculumSubtitle(
                              curriculumLabelText(
                                ref,
                                curriculum: curriculumId,
                              ),
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const CircleAvatar(
                      radius: 21,
                      backgroundColor: Color(0x40FFFFFF),
                      child: Icon(Icons.auto_awesome, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Sub-section breadcrumb header
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.surfaceE9),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            // R1-(5): each segment is Flexible + ellipsis so the breadcrumb
            // never RenderFlex-overflows at large text scales (was "RIGHT
            // OVERFLOWED BY 11 PIXELS" at 1.3).
            child: Row(
              children: [
                Flexible(
                  child: CurriculumLabel.curriculum(
                    curriculumId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.brandBlueDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppTheme.brandInkMuted,
                ),
                const SizedBox(width: 8),
                // R1-(6): show only the level prompt (e.g. "Choose a Sefer").
                // The old level1Selection re-embedded the curriculum name,
                // duplicating the chip to its left ("Chumash › Chumash → …").
                // R1v2: the template language now follows the Hebrew-Terms
                // toggle (see [chooseLevelPrompt]) so the prompt never mixes a
                // Latin "Choose a" with a Hebrew level word.
                Flexible(
                  child: Text(
                    chooseLevelPrompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: useHebrew
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.brandInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: onToggleAll,
              icon: Icon(
                allDirectlySelected ? Icons.remove_done : Icons.select_all,
                size: 20,
              ),
              label: Text(
                allDirectlySelected
                    ? l10n.deselectAllInThisList
                    : l10n.selectAllInThisList,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final rawValue = levelValueAt(item, currentLevel) ?? '';
              final title = itemDisplayName(item, useHebrew: useHebrew);
              final selected = isDirectlySelected(item);
              final count = childCountForItem(item);
              return ScopeLevelTile(
                title: title,
                subtitle:
                    '$count ${labelForLevel(currentLevel + 1)} • ${scopeDescription(rawValue)}',
                icon: scopeIcon(rawValue),
                selected: selected,
                badgeText: selected ? l10n.scopeSelectedBadge : null,
                onCheck: () => onToggle(item),
                canDrill: canDrillDeeper,
                onDrill: canDrillDeeper ? () => onDrill(item) : null,
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: selections.isNotEmpty ? onDone : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text(
            selections.isEmpty
                ? l10n.selectAtLeastOne
                : l10n.continueWithSelectionCount(selections.length),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hierarchy (drill-down) view — breadcrumbs + item list
// ---------------------------------------------------------------------------

/// Shows breadcrumb trail, selection chips, select-all button and item list
/// during a drill-down session.
///
/// [items] must be pre-rendered via [groupItemsByNextLevel].
class ScopeHierarchyView extends StatelessWidget {
  const ScopeHierarchyView({
    required this.curriculumId,
    required this.breadcrumbs,
    required this.breadcrumbLabels,
    required this.items,
    required this.useHebrew,
    required this.selections,
    required this.selectionLabels,
    required this.allDirectlySelected,
    required this.currentLevel,
    required this.maxSelectableLevel,
    required this.labelForLevel,
    required this.isSelected,
    required this.isDirectlySelected,
    required this.onToggle,
    required this.onDrill,
    required this.onToggleAll,
    required this.onBack,
    required this.onClearBreadcrumbs,
    required this.onTrimBreadcrumbs,
    required this.onRemoveSelection,
    required this.onDone,
    super.key,
  });

  final CurriculumId curriculumId;
  final List<ScopeEntry> breadcrumbs;

  /// Rendered display label for each breadcrumb (parallel to [breadcrumbs]).
  final List<String> breadcrumbLabels;

  /// Pre-rendered content items at the current level.
  final List<ContentItem> items;

  /// Whether to show Hebrew display names.
  final bool useHebrew;

  final List<ScopeEntry> selections;

  /// Rendered display label for each selection, keyed by raw value.
  final Map<String, String> selectionLabels;

  final bool allDirectlySelected;
  final int currentLevel;
  final int maxSelectableLevel;
  final String Function(int level) labelForLevel;
  final bool Function(ContentItem item) isSelected;
  final bool Function(ContentItem item) isDirectlySelected;
  final ScopeToggleCallback onToggle;
  final ScopeDrillCallback onDrill;
  final ScopeSelectAllCallback onToggleAll;
  final VoidCallback onBack;
  final VoidCallback onClearBreadcrumbs;
  final void Function(int upToIndex) onTrimBreadcrumbs;
  final void Function(ScopeEntry entry) onRemoveSelection;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final canDrillDeeper = currentLevel < maxSelectableLevel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Breadcrumb trail
        _buildBreadcrumbs(context, theme, l10n),
        const SizedBox(height: 8),
        // Selection chips
        if (selections.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: selections
                  .map(
                    (s) => Chip(
                      label: Text(
                        '${labelForLevel(s.level)}: ${selectionLabels[s.value] ?? s.value}',
                        style: theme.textTheme.labelSmall,
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => onRemoveSelection(s),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: onToggleAll,
              icon: Icon(
                allDirectlySelected ? Icons.remove_done : Icons.select_all,
                size: 20,
              ),
              label: Text(
                allDirectlySelected
                    ? l10n.deselectAllInThisList
                    : l10n.selectAllInThisList,
              ),
            ),
          ),
        ],
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final title = itemDisplayName(item, useHebrew: useHebrew);
              return HierarchyTile(
                title: title,
                isSelected: isSelected(item),
                isImplicit: isSelected(item) && !isDirectlySelected(item),
                canDrill: canDrillDeeper,
                onCheck: () => onToggle(item),
                onDrill: canDrillDeeper ? () => onDrill(item) : null,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: selections.isNotEmpty ? onDone : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            selections.isEmpty
                ? l10n.selectAtLeastOne
                : l10n.continueWithSelectionCount(selections.length),
          ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumbs(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
          // R1v2: was a hardcoded 'Back' literal — now localized so the
          // tooltip is not English chrome in the he locale.
          tooltip: l10n.actionBack,
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                InkWell(
                  onTap: onClearBreadcrumbs,
                  child: CurriculumLabel.curriculum(
                    curriculumId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                for (var i = 0; i < breadcrumbs.length; i++) ...[
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  InkWell(
                    onTap: i < breadcrumbs.length - 1
                        ? () => onTrimBreadcrumbs(i + 1)
                        : null,
                    child: Text(
                      breadcrumbLabels[i],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: i < breadcrumbs.length - 1
                            ? theme.colorScheme.primary
                            : null,
                        fontWeight: i == breadcrumbs.length - 1
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
