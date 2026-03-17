import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Result returned from [RewardsSetupScreen] containing the rewards to create.
class RewardSetupResult {
  final List<RewardEntry> rewards;

  const RewardSetupResult({required this.rewards});
}

/// A single reward entry from the setup screen.
class RewardEntry {
  final String title;
  final String description;
  final int pointsThreshold;

  const RewardEntry({
    required this.title,
    required this.description,
    required this.pointsThreshold,
  });
}

/// Screen for setting up initial mystery rewards during child-mode onboarding.
///
/// Returns [RewardSetupResult] with the configured rewards, or null if skipped.
class RewardsSetupScreen extends StatefulWidget {
  const RewardsSetupScreen({
    super.key,
    this.suggestedThresholds = const [100, 500, 1000],
  });

  /// Suggested point thresholds based on curriculum size and daily pace.
  final List<int> suggestedThresholds;

  @override
  State<RewardsSetupScreen> createState() => _RewardsSetupScreenState();
}

class _RewardsSetupScreenState extends State<RewardsSetupScreen> {
  final _rewards = <RewardEntry>[];
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _thresholdController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _addReward() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _rewards.add(
        RewardEntry(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          pointsThreshold: int.parse(_thresholdController.text.trim()),
        ),
      );
      _titleController.clear();
      _descriptionController.clear();
      _thresholdController.clear();
    });
  }

  void _removeReward(int index) {
    setState(() => _rewards.removeAt(index));
  }

  void _save() {
    Navigator.of(context).pop(RewardSetupResult(rewards: _rewards));
  }

  void _skip() {
    Navigator.of(context).pop<RewardSetupResult>(null);
  }

  void _useSuggested(int threshold) {
    _thresholdController.text = threshold.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Rewards')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add mystery rewards for your child to earn!',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'You can add more later from Parent Mode.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_rewards.isNotEmpty) ...[
              for (var i = 0; i < _rewards.length; i++)
                Card(
                  child: ListTile(
                    title: Text(_rewards[i].title),
                    subtitle: Text(
                      '${_rewards[i].description} — ${_rewards[i].pointsThreshold} pts',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeReward(i),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            _buildAddRewardForm(theme),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _rewards.isNotEmpty ? _save : null,
              child: Text(
                'Save ${_rewards.length} Reward${_rewards.length == 1 ? '' : 's'}',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _skip, child: const Text('Skip')),
          ],
        ),
      ),
    );
  }

  Widget _buildAddRewardForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a Reward', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Ice cream trip',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Title is required' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'e.g. A special outing for reaching your goal',
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Description is required'
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _thresholdController,
            decoration: const InputDecoration(
              labelText: 'Point Threshold',
              hintText: 'e.g. 500',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Threshold is required';
              final n = int.tryParse(v.trim());
              if (n == null || n <= 0) return 'Must be a positive number';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final threshold in widget.suggestedThresholds)
                ActionChip(
                  label: Text('$threshold pts'),
                  onPressed: () => _useSuggested(threshold),
                ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addReward,
            icon: const Icon(Icons.add),
            label: const Text('Add Reward'),
          ),
        ],
      ),
    );
  }
}
