import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_model.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/reward_providers.dart';

@RoutePage()
class RewardCatalogScreen extends ConsumerWidget {
  const RewardCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(allRewardsProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Reward Catalog')),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
        child: FloatingActionButton(
          onPressed: () => _showAddEditDialog(context, ref),
          child: const Icon(Icons.add),
        ),
      ),
      body: rewardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (rewards) => rewards.isEmpty
            ? const Center(child: Text('No rewards configured yet'))
            : ListView.builder(
                itemCount: rewards.length,
                itemBuilder: (context, index) =>
                    _RewardTile(reward: rewards[index]),
              ),
      ),
    );
  }

  void _showAddEditDialog(
    BuildContext context,
    WidgetRef ref, {
    RewardModel? reward,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => _RewardFormDialog(existingReward: reward),
    );
  }
}

class _RewardTile extends ConsumerWidget {
  final RewardModel reward;

  const _RewardTile({required this.reward});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEarned = reward.isEarned;

    return ListTile(
      leading: Icon(
        isEarned ? Icons.emoji_events : Icons.card_giftcard,
        color: isEarned ? Colors.amber : null,
      ),
      title: Text(reward.title),
      subtitle: Text('${reward.description}\n${reward.pointsThreshold} points'),
      isThreeLine: true,
      trailing: isEarned
          ? (reward.isRevealed
                ? const Chip(label: Text('Revealed'))
                : FilledButton(
                    onPressed: () => _revealReward(context, ref),
                    child: const Text('Reveal'),
                  ))
          : PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editReward(context, ref);
                } else if (value == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
    );
  }

  Future<void> _revealReward(BuildContext context, WidgetRef ref) async {
    try {
      final service = ref.read(rewardServiceProvider);
      await service.revealReward(reward.id);
      ref.invalidate(allRewardsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to reveal reward: $e')));
      }
    }
  }

  void _editReward(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => _RewardFormDialog(existingReward: reward),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reward'),
        content: Text('Are you sure you want to delete "${reward.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      final service = ref.read(rewardServiceProvider);
      await service.deleteReward(reward.id);
      ref.invalidate(allRewardsProvider);
    }
  }
}

class _RewardFormDialog extends ConsumerStatefulWidget {
  final RewardModel? existingReward;

  const _RewardFormDialog({this.existingReward});

  @override
  ConsumerState<_RewardFormDialog> createState() => _RewardFormDialogState();
}

class _RewardFormDialogState extends ConsumerState<_RewardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _thresholdController;

  bool get isEditing => widget.existingReward != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingReward?.title.trim() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existingReward?.description.trim() ?? '',
    );
    _thresholdController = TextEditingController(
      text: widget.existingReward?.pointsThreshold.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit Reward' : 'Add Reward'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Description is required'
                  : null,
            ),
            TextFormField(
              controller: _thresholdController,
              decoration: const InputDecoration(labelText: 'Point Threshold'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Threshold is required';
                }
                final n = int.tryParse(v.trim());
                if (n == null || n <= 0) {
                  return 'Must be a positive number';
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
          onPressed: _submit,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final service = ref.read(rewardServiceProvider);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final threshold = int.parse(_thresholdController.text.trim());

    if (isEditing) {
      await service.updateReward(
        id: widget.existingReward!.id,
        title: title,
        description: description,
        pointsThreshold: threshold,
      );
    } else {
      await service.addReward(
        title: title,
        description: description,
        pointsThreshold: threshold,
      );
    }

    ref.invalidate(allRewardsProvider);
    if (mounted) Navigator.of(context).pop();
  }
}
