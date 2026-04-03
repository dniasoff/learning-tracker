import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';

/// Data model pairing a stage definition with its point config.
class _StagePointConfig {
  final StageDefinition stage;
  final PointConfig config;

  const _StagePointConfig({required this.stage, required this.config});
}

/// Data model for a curriculum's point configuration.
class _CurriculumPointData {
  final CurriculumId curriculum;
  final List<_StagePointConfig> stages;

  const _CurriculumPointData({required this.curriculum, required this.stages});
}

/// Provider for loading all active curricula with their stage point configs.
final _pointConfigDataProvider = FutureProvider<List<_CurriculumPointData>>((
  ref,
) async {
  final db = ref.watch(userDatabaseProvider);
  final activeCurricula = await db.activeCurriculumDao.getActiveCurricula();

  final result = <_CurriculumPointData>[];
  for (final activeId in activeCurricula) {
    final curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == activeId,
    );
    final stages = await db.stageDao.getStageDefinitionsByCurriculum(
      curriculum.storageKey,
    );
    final configs = await db.pointConfigDao.getConfigsByCurriculum(
      curriculum.storageKey,
    );

    final stageConfigs = <_StagePointConfig>[];
    for (final stage in stages) {
      final config = configs.cast<PointConfig?>().firstWhere(
        (c) => c!.stageOrder == stage.stageOrder,
        orElse: () => null,
      );
      if (config != null) {
        stageConfigs.add(_StagePointConfig(stage: stage, config: config));
      }
    }
    result.add(
      _CurriculumPointData(curriculum: curriculum, stages: stageConfigs),
    );
  }
  return result;
});

@RoutePage()
class PointConfigScreen extends ConsumerWidget {
  const PointConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_pointConfigDataProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Point Configuration')),
      body: SafeArea(
        top: false,
        child: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (data) => data.isEmpty
              ? const Center(child: Text('No active curricula'))
              : ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) =>
                      _CurriculumExpansionTile(data: data[index]),
                ),
        ),
      ),
    );
  }
}

class _CurriculumExpansionTile extends ConsumerWidget {
  final _CurriculumPointData data;

  const _CurriculumExpansionTile({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      title: Text(data.curriculum.displayNameHe),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to Defaults',
            onPressed: () => _confirmReset(context, ref),
          ),
          const Icon(Icons.expand_more),
        ],
      ),
      children: data.stages
          .map(
            (sp) => _StagePointRow(
              stagePoint: sp,
              curriculumId: data.curriculum.storageKey,
            ),
          )
          .toList(),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: Text(
          'Reset all point values for ${data.curriculum.displayNameHe} to defaults?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      final db = ref.read(userDatabaseProvider);
      final profileId = ref.read(activeProfileIdProvider);
      // Look up trackId for this curriculum
      final track = await (db.select(db.curriculumTracks)
            ..where((t) =>
                t.profileId.equals(profileId) &
                t.curriculumId.equals(data.curriculum.storageKey))
            ..limit(1))
          .getSingleOrNull();
      final trackId = track?.id ?? 0;
      await db.pointConfigDao.deleteAllForCurriculum(
        data.curriculum.storageKey,
      );
      await db.pointConfigDao.seedDefaults(data.curriculum.storageKey, trackId);
      ref.invalidate(_pointConfigDataProvider);
    }
  }
}

class _StagePointRow extends ConsumerWidget {
  final _StagePointConfig stagePoint;
  final String curriculumId;

  const _StagePointRow({required this.stagePoint, required this.curriculumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(stagePoint.stage.stageName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${stagePoint.config.points}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit points',
            onPressed: () => _showEditDialog(context, ref),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => _PointEditDialog(
        stageName: stagePoint.stage.stageName,
        currentPoints: stagePoint.config.points,
        onSave: (newPoints) async {
          final db = ref.read(userDatabaseProvider);
          await db.pointConfigDao.upsertConfig(
            PointConfigsCompanion(
              curriculumId: Value(curriculumId),
              stageOrder: Value(stagePoint.stage.stageOrder),
              points: Value(newPoints),
            ),
          );
          ref.invalidate(_pointConfigDataProvider);
        },
      ),
    );
  }
}

class _PointEditDialog extends StatefulWidget {
  final String stageName;
  final int currentPoints;
  final Future<void> Function(int) onSave;

  const _PointEditDialog({
    required this.stageName,
    required this.currentPoints,
    required this.onSave,
  });

  @override
  State<_PointEditDialog> createState() => _PointEditDialogState();
}

class _PointEditDialogState extends State<_PointEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPoints.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.stageName} Points'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          decoration: const InputDecoration(labelText: 'Point Value'),
          keyboardType: TextInputType.number,
          autofocus: true,
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Point value is required';
            }
            final n = int.tryParse(v.trim());
            if (n == null || n <= 0) {
              return 'Must be a positive integer';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final value = int.parse(_controller.text.trim());
    await widget.onSave(value);
    if (mounted) Navigator.of(context).pop();
  }
}
