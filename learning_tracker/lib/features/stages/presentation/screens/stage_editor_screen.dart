import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/protected_stage_exception.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/stage_limit_exceeded_exception.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/features/stages/presentation/widgets/stage_row_widget.dart';

@RoutePage()
class StageEditorScreen extends ConsumerStatefulWidget {
  const StageEditorScreen({
    super.key,
    @PathParam('curriculumId') required this.curriculumId,
  });

  final String curriculumId;

  @override
  ConsumerState<StageEditorScreen> createState() => _StageEditorScreenState();
}

class _StageEditorScreenState extends ConsumerState<StageEditorScreen> {
  late CurriculumId _curriculum;

  @override
  void initState() {
    super.initState();
    _curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == widget.curriculumId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stagesAsync = ref.watch(stageEditorProvider(_curriculum));

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(text: 'Manage Stages — ${_curriculum.displayNameEn}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to Defaults',
            onPressed: () => _confirmResetToDefaults(context),
          ),
        ],
      ),
      body: stagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stages) => _buildList(context, stages),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        tooltip: 'Add Stage',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<StageDefinition> stages) {
    if (stages.isEmpty) {
      return const Center(child: Text('No stages defined.'));
    }

    return ReorderableListView.builder(
      itemCount: stages.length,
      onReorder: (oldIndex, newIndex) => _onReorder(stages, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final stage = stages[index];
        return StageRowWidget(
          key: ValueKey(stage.id),
          stage: stage,
          onEdit: () => _showEditDialog(context, stage),
          onDelete: stage.stageOrder == 1
              ? null
              : () => _confirmDelete(context, stage),
        );
      },
    );
  }

  void _onReorder(List<StageDefinition> stages, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final reordered = List<StageDefinition>.from(stages);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final orderedIds = reordered.map((s) => s.id).toList();

    unawaited(
      ref
          .read(stageEditorProvider(_curriculum).notifier)
          .reorderStages(orderedIds),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final result = await _showStageFormDialog(context, title: 'Add Stage');
    if (result == null) return;

    try {
      await ref
          .read(stageEditorProvider(_curriculum).notifier)
          .addStage(result.name, result.delayDays);
      if (context.mounted) _showSnack(context, 'Stage added');
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    StageDefinition stage,
  ) async {
    final result = await _showStageFormDialog(
      context,
      title: 'Edit Stage',
      initialName: stage.stageName,
      initialDelayDays: stage.delayDays,
    );
    if (result == null) return;

    try {
      await ref
          .read(stageEditorProvider(_curriculum).notifier)
          .updateStage(
            stage.id,
            name: result.name,
            delayDays: result.delayDays,
          );
      if (context.mounted) _showSnack(context, 'Stage updated');
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    StageDefinition stage,
  ) async {
    final repository = ref.read(stageDefinitionRepositoryProvider(_curriculum));
    final hasCompletions = await repository.hasCompletionsForStage(stage.id);

    if (!context.mounted) return;

    if (hasCompletions) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Stage'),
          content: const Text(
            'This stage has existing completions. Deleting it will not remove them, '
            'but the stage will no longer appear in the scheduler. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await ref
          .read(stageEditorProvider(_curriculum).notifier)
          .deleteStage(stage.id);
      if (context.mounted) _showSnack(context, 'Stage deleted');
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _confirmResetToDefaults(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will remove all custom stages and restore Learn, Chazara 1, and Chazara 2. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(stageEditorProvider(_curriculum).notifier)
          .resetToDefaults();
      if (context.mounted) _showSnack(context, 'Stages reset to defaults');
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<({String name, int delayDays})?> _showStageFormDialog(
    BuildContext context, {
    required String title,
    String initialName = '',
    int initialDelayDays = 0,
  }) {
    final nameController = TextEditingController(text: initialName);
    final delayController = TextEditingController(
      text: initialDelayDays.toString(),
    );
    final formKey = GlobalKey<FormState>();

    return showDialog<({String name, int delayDays})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Stage name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: delayController,
                decoration: const InputDecoration(labelText: 'Delay (days)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 0) return 'Enter a non-negative number';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx, (
                name: nameController.text.trim(),
                delayDays: int.parse(delayController.text),
              ));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(BuildContext context, Object error) {
    String message;
    if (error is ProtectedStageException) {
      message = error.userMessage;
    } else if (error is StageLimitExceededException) {
      message = error.userMessage;
    } else {
      message = error.toString();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
