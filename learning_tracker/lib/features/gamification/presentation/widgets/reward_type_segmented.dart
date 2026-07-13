import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

const Color _kNavy = AppTheme.brandBlueDeep;
const Color _kFieldFill = AppColors.gamifFieldFillLight;
const Color _kMutedLabel = AppColors.gamifMutedLabelGrey;

/// Two-segment toggle for choosing between per-track and total-points reward
/// ladders.
class RewardTypeSegmented extends StatelessWidget {
  const RewardTypeSegmented({
    super.key,
    required this.perTrackLabel,
    required this.totalLabel,
    required this.perTrackEnabled,
    required this.isGlobal,
    required this.onChanged,
  });

  final String perTrackLabel;
  final String totalLabel;
  final bool perTrackEnabled;
  final bool isGlobal;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Seg(
              label: perTrackLabel,
              selected: !isGlobal,
              enabled: perTrackEnabled,
              onTap: perTrackEnabled ? () => onChanged(false) : null,
            ),
          ),
          Expanded(
            child: _Seg(
              label: totalLabel,
              selected: isGlobal,
              enabled: true,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const baseMuted = _kMutedLabel;
    final labelColor = !enabled
        ? baseMuted.withValues(alpha: 0.35)
        : (selected ? Colors.white : baseMuted);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
