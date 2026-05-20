import 'package:flutter/material.dart';
import 'package:learning_tracker/features/gamification/domain/reward_milestone_icons.dart';

const Color _kNavy = Color(0xFF00218D);
const Color _kFieldFill = Color(0xFFF2F4F8);
const Color _kMutedLabel = Color(0xFF6B7280);

/// Horizontal scrollable row of icon tiles used to select a reward icon.
class AvatarPickerRow extends StatelessWidget {
  const AvatarPickerRow({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: RewardMilestoneIcons.choices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          return SizedBox(
            width: 64,
            child: AvatarTile(
              icon: RewardMilestoneIcons.choices[i],
              selected: selectedIndex == i,
              onTap: () => onSelect(i),
            ),
          );
        },
      ),
    );
  }
}

/// Single icon tile inside [AvatarPickerRow].
class AvatarTile extends StatelessWidget {
  const AvatarTile({
    super.key,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _kFieldFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _kNavy : Colors.transparent,
              width: selected ? 3 : 0,
            ),
          ),
          child: Icon(
            icon,
            color: selected ? _kNavy : _kMutedLabel.withValues(alpha: 0.45),
            size: 32,
          ),
        ),
      ),
    );
  }
}
