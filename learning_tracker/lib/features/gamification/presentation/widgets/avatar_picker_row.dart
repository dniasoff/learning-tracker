import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/gamification/domain/reward_milestone_icons.dart';

const Color _kNavy = AppTheme.brandBlueDeep;
const Color _kFieldFill = AppColors.gamifFieldFillLight;
const Color _kMutedLabel = AppColors.gamifMutedLabelGrey;

/// Horizontal scrollable row of icon tiles used to select a reward icon.
///
/// Auto-scrolls so the [selectedIndex] tile is visible. This matters in edit
/// mode: when an existing reward's icon lives past the first few visible tiles
/// (e.g. index 6+ in the 17-icon list), the highlighted tile would otherwise
/// sit off-screen and the picker would look as if nothing is selected.
class AvatarPickerRow extends StatefulWidget {
  const AvatarPickerRow({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int selectedIndex;
  final void Function(int index) onSelect;

  @override
  State<AvatarPickerRow> createState() => _AvatarPickerRowState();
}

class _AvatarPickerRowState extends State<AvatarPickerRow> {
  static const double _tileWidth = 64;
  static const double _tileGap = 10;

  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  @override
  void didUpdateWidget(AvatarPickerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls so the selected tile sits within the visible viewport.
  void _revealSelected() {
    if (!_controller.hasClients) return;
    final index = widget.selectedIndex;
    if (index <= 0) {
      _controller.jumpTo(0);
      return;
    }
    const stride = _tileWidth + _tileGap;
    final tileStart = index * stride;
    final tileEnd = tileStart + _tileWidth;
    final viewportEnd =
        _controller.offset + _controller.position.viewportDimension;
    if (tileEnd > viewportEnd || tileStart < _controller.offset) {
      final target = tileStart.clamp(0.0, _controller.position.maxScrollExtent);
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: RewardMilestoneIcons.choices.length,
        separatorBuilder: (_, __) => const SizedBox(width: _tileGap),
        itemBuilder: (context, i) {
          return SizedBox(
            width: _tileWidth,
            child: AvatarTile(
              icon: RewardMilestoneIcons.choices[i],
              selected: widget.selectedIndex == i,
              onTap: () => widget.onSelect(i),
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
