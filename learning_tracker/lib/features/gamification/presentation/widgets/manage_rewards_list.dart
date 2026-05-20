import 'package:flutter/material.dart';
import 'package:learning_tracker/features/gamification/domain/models/reward_milestone.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Scrollable list of existing reward milestones shown in the "Manage rewards"
/// bottom sheet.
///
/// Loads its data asynchronously via the [load] callback so it can be
/// refreshed in-place after toggle/delete operations without closing the sheet.
class ManageRewardsList extends StatefulWidget {
  const ManageRewardsList({
    super.key,
    required this.load,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final Future<List<RewardMilestone>> Function() load;
  final void Function(RewardMilestone) onEdit;
  final Future<void> Function(RewardMilestone) onDelete;
  final Future<void> Function(RewardMilestone) onToggle;

  @override
  State<ManageRewardsList> createState() => _ManageRewardsListState();
}

class _ManageRewardsListState extends State<ManageRewardsList> {
  late Future<List<RewardMilestone>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<RewardMilestone>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = [...?snap.data]
          ..sort((a, b) => a.thresholdPoints.compareTo(b.thresholdPoints));
        if (list.isEmpty) {
          return Center(
            child: Text(
              l10n.rewardConfigEmptyMilestones,
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final m = list[i];
            return RewardCard(
              milestone: m,
              l10n: l10n,
              onEdit: () => widget.onEdit(m),
              onDelete: () => widget.onDelete(m),
              onToggle: () async {
                await widget.onToggle(m);
                await _refresh();
              },
            );
          },
        );
      },
    );
  }
}

/// A single milestone row inside [ManageRewardsList].
///
/// Shows the milestone name, threshold, enable/disable switch, and
/// edit/delete icon buttons.
class RewardCard extends StatelessWidget {
  const RewardCard({
    super.key,
    required this.milestone,
    required this.l10n,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final RewardMilestone milestone;
  final AppLocalizations l10n;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        milestone.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${l10n.rewardConfigPointsThresholdLabel}: ${milestone.thresholdPoints}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch.adaptive(
            value: milestone.isEnabled,
            onChanged: (_) => onToggle(),
          ),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
