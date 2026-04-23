import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

class _StagePointConfig {
  const _StagePointConfig({required this.stage, required this.config});

  final StageDefinition stage;
  final PointConfig config;
}

class _TrackPointData {
  const _TrackPointData({
    required this.curriculum,
    required this.profileId,
    required this.trackId,
    required this.trackType,
    required this.stages,
  });

  final CurriculumId curriculum;
  final int profileId;
  final int trackId;
  final String trackType;
  final List<_StagePointConfig> stages;
}

class _TrackRewardData {
  const _TrackRewardData({
    required this.curriculum,
    required this.trackId,
    required this.trackType,
    required this.pointsTotal,
    required this.milestones,
  });

  final CurriculumId curriculum;
  final int trackId;
  final String trackType;
  final int pointsTotal;
  final List<RewardMilestone> milestones;
}

final _pointConfigDataProvider = FutureProvider<List<_TrackPointData>>((
  ref,
) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final activeTracks = await db.trackDao.getActiveTracksForProfile(profileId);

  final result = <_TrackPointData>[];
  for (final track in activeTracks) {
    final curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == track.curriculumId,
    );
    final stages = await db.stageDao.getStageDefinitionsByCurriculum(
      curriculum.storageKey,
    );
    final configs = await db.pointConfigDao.getConfigsByCurriculum(
      curriculum.storageKey,
      profileId: profileId,
      trackId: track.id,
    );

    final stageConfigs = <_StagePointConfig>[];
    for (final stage in stages) {
      final config = configs.cast<PointConfig?>().firstWhere(
        (c) => c?.stageOrder == stage.stageOrder,
        orElse: () => null,
      );
      if (config != null) {
        stageConfigs.add(_StagePointConfig(stage: stage, config: config));
      }
    }

    result.add(
      _TrackPointData(
        curriculum: curriculum,
        profileId: profileId,
        trackId: track.id,
        trackType: track.trackType,
        stages: stageConfigs,
      ),
    );
  }
  return result;
});

final _rewardConfigDataProvider = FutureProvider<List<_TrackRewardData>>((
  ref,
) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final service = RewardMilestoneService(db, profileId: profileId);
  final activeTracks = await db.trackDao.getActiveTracksForProfile(profileId);
  final result = <_TrackRewardData>[];

  for (final track in activeTracks) {
    final curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == track.curriculumId,
    );
    await service.ensureDefaultsForTrack(track.id);
    final milestones = await service.getMilestonesForTrack(track.id);
    final pointsTotal = await service.getTrackPointsTotal(track.id);
    result.add(
      _TrackRewardData(
        curriculum: curriculum,
        trackId: track.id,
        trackType: track.trackType,
        pointsTotal: pointsTotal,
        milestones: milestones,
      ),
    );
  }
  return result;
});

@RoutePage()
class PointConfigScreen extends ConsumerWidget {
  const PointConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(_pointConfigDataProvider);
    final rewardsAsync = ref.watch(_rewardConfigDataProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Point Configuration')),
      body: SafeArea(
        top: false,
        child: pointsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
          data: (pointData) {
            return rewardsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
              data: (rewardData) {
                if (pointData.isEmpty) {
                  return const Center(child: Text('No active curricula'));
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    const ListTile(
                      title: Text('Points by Track & Stage'),
                      subtitle: Text(
                        'Set how many points each stage is worth per active track.',
                      ),
                    ),
                    ...pointData.map((data) => _TrackPointTile(data: data)),
                    const Divider(height: 24),
                    const ListTile(
                      title: Text('Reward Milestones'),
                      subtitle: Text(
                        'Unlock rewards when track points reach milestone thresholds.',
                      ),
                    ),
                    ...rewardData.map((data) => _RewardTrackTile(data: data)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TrackPointTile extends ConsumerWidget {
  const _TrackPointTile({required this.data});

  final _TrackPointData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      title: Text('${data.curriculum.displayNameHe} • ${data.trackType}'),
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
              profileId: data.profileId,
              trackId: data.trackId,
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
          'Reset all point values for ${data.curriculum.displayNameHe} (${data.trackType})?',
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

    if (confirmed != true) return;

    final db = ref.read(userDatabaseProvider);
    await db.pointConfigDao.deleteAllForCurriculum(
      data.curriculum.storageKey,
      profileId: data.profileId,
    );
    await db.pointConfigDao.seedDefaults(
      data.curriculum.storageKey,
      data.trackId,
      profileId: data.profileId,
    );
    await ref.read(syncEngineProvider)?.pushGamificationSettingsSnapshot();
    ref.invalidate(_pointConfigDataProvider);
    ref.invalidate(_rewardConfigDataProvider);
  }
}

class _StagePointRow extends ConsumerWidget {
  const _StagePointRow({
    required this.stagePoint,
    required this.profileId,
    required this.trackId,
    required this.curriculumId,
  });

  final _StagePointConfig stagePoint;
  final int profileId;
  final int trackId;
  final String curriculumId;

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
              profileId: Value(profileId),
              curriculumId: Value(curriculumId),
              trackId: Value(trackId),
              stageOrder: Value(stagePoint.stage.stageOrder),
              points: Value(newPoints),
            ),
          );
          await ref
              .read(syncEngineProvider)
              ?.pushGamificationSettingsSnapshot();
          ref.invalidate(_pointConfigDataProvider);
          ref.invalidate(_rewardConfigDataProvider);
        },
      ),
    );
  }
}

class _RewardTrackTile extends ConsumerWidget {
  const _RewardTrackTile({required this.data});

  final _TrackRewardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestones = [...data.milestones]
      ..sort((a, b) => a.thresholdPoints.compareTo(b.thresholdPoints));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: Text('${data.curriculum.displayNameHe} • ${data.trackType}'),
        subtitle: Text('Current points: ${data.pointsTotal}'),
        children: [
          for (final milestone in milestones)
            ListTile(
              title: Text(milestone.title),
              subtitle: Text('Unlock at ${milestone.thresholdPoints} points'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showMilestoneDialog(
                  context: context,
                  ref: ref,
                  trackId: data.trackId,
                  milestone: milestone,
                ),
              ),
              onLongPress: () async {
                final db = ref.read(userDatabaseProvider);
                final profileId = ref.read(activeProfileIdProvider);
                final service = RewardMilestoneService(
                  db,
                  profileId: profileId,
                );
                await service.removeMilestone(milestone.id);
                await ref
                    .read(syncEngineProvider)
                    ?.pushGamificationSettingsSnapshot();
                ref.invalidate(_rewardConfigDataProvider);
              },
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add reward milestone'),
            onTap: () => _showMilestoneDialog(
              context: context,
              ref: ref,
              trackId: data.trackId,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMilestoneDialog({
    required BuildContext context,
    required WidgetRef ref,
    required int trackId,
    RewardMilestone? milestone,
  }) async {
    final titleController = TextEditingController(text: milestone?.title ?? '');
    final pointsController = TextEditingController(
      text: milestone?.thresholdPoints.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(milestone == null ? 'Add Milestone' : 'Edit Milestone'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Threshold points',
                ),
                validator: (value) {
                  final n = int.tryParse(value?.trim() ?? '');
                  if (n == null || n <= 0) {
                    return 'Enter a positive number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final db = ref.read(userDatabaseProvider);
              final profileId = ref.read(activeProfileIdProvider);
              final service = RewardMilestoneService(db, profileId: profileId);
              await service.upsertMilestone(
                trackId: trackId,
                title: titleController.text.trim(),
                thresholdPoints: int.parse(pointsController.text.trim()),
                milestoneId: milestone?.id,
                isEnabled: milestone?.isEnabled ?? true,
              );
              await ref
                  .read(syncEngineProvider)
                  ?.pushGamificationSettingsSnapshot();
              ref.invalidate(_rewardConfigDataProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    titleController.dispose();
    pointsController.dispose();
  }
}

class _PointEditDialog extends StatefulWidget {
  const _PointEditDialog({
    required this.stageName,
    required this.currentPoints,
    required this.onSave,
  });

  final String stageName;
  final int currentPoints;
  final Future<void> Function(int) onSave;

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
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Point value is required';
            }
            final n = int.tryParse(value.trim());
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
