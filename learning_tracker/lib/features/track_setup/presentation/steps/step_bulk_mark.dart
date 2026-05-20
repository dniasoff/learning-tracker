import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/hierarchy_selection.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/features/content_browsing/presentation/widgets/hierarchy_selection_panel.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/add_track_result.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Step 7 of the Add Track flow (self-paced tracks only).
///
/// Presents a hierarchical content browser so the user can mark sections they
/// have already completed. The selected [HierarchySelection] set is forwarded
/// to [onMarkCompleted]; tapping Skip calls [onSkip].
class SelfPacedPriorProgressStep extends ConsumerWidget {
  const SelfPacedPriorProgressStep({
    required this.curriculumId,
    required this.onSkip,
    required this.onMarkCompleted,
    this.scopeSelections,
    super.key,
  });

  final CurriculumId curriculumId;
  final List<ScopeEntry>? scopeSelections;
  final VoidCallback onSkip;
  final ValueChanged<Set<HierarchySelection>> onMarkCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.priorLearningTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(l10n.priorLearningSubtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            l10n.priorLearningChooseSections(
              curriculumLabelText(ref, curriculum: curriculumId),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: HierarchySelectionPanel(
              curriculumId: curriculumId,
              scopeConstraints: scopeSelections,
              onSkip: onSkip,
              onConfirmed: onMarkCompleted,
              confirmLabel: l10n.actionMarkCompleted,
            ),
          ),
        ],
      ),
    );
  }
}
