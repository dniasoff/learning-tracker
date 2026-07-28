import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';

/// AUD-darkmode: brandBlueDeep is an ink-on-CARD role that LIGHTENS in dark
/// mode, but the selected segment paints it as a FILL with hardcoded white
/// text -- measured 1.63:1 in dark. chazaraSelectedGradientStart is pinned
/// to this exact brandBlueDeep light literal (0xFF0E3392) in both themes.
Color _kNavy(BuildContext context) =>
    context.colors.chazaraSelectedGradientStart;
Color _kFieldFill(BuildContext context) => context.colors.gamifFieldFillLight;
Color _kMutedLabel(BuildContext context) => context.colors.gamifMutedLabelGrey;

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
        color: _kFieldFill(context),
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
    final baseMuted = _kMutedLabel(context);
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
            color: selected ? _kNavy(context) : Colors.transparent,
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
