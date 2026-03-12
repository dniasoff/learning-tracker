import 'package:flutter/material.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart';

/// A single row in the stage editor list.
///
/// Displays stage name and delay_days. The delete button is hidden for the
/// protected Learn stage (stageOrder == 1).
class StageRowWidget extends StatelessWidget {
  const StageRowWidget({
    super.key,
    required this.stage,
    required this.onEdit,
    required this.onDelete,
  });

  final StageDefinition stage;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final delayText = stage.delayDays == 0
        ? 'Day 0 (same day)'
        : '+${stage.delayDays} day${stage.delayDays == 1 ? '' : 's'}';

    return ListTile(
      key: ValueKey(stage.id),
      title: Text(stage.stageName),
      subtitle: Text(delayText),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit stage',
            onPressed: onEdit,
          ),
          if (stage.stageOrder != 1)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete stage',
              onPressed: onDelete,
            ),
          ReorderableDragStartListener(
            index: stage.stageOrder - 1,
            child: const Icon(Icons.drag_handle),
          ),
        ],
      ),
    );
  }
}
