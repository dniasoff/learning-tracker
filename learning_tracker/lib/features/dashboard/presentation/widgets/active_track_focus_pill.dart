import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';

/// Pill that surfaces a track's unit label (next task / today's unit).
///
/// Two visual weights:
///   * default (secondary) — muted grey pill used for the "NEXT TASK"
///     (oldest-overdue) unit;
///   * [prominent] — the primary call-to-action ("TODAY") rendered with the
///     brand accent background, white text and a calendar icon so it reads as
///     the thing the user should act on, clearly distinct from the secondary
///     pill.
class ActiveTrackFocusPill extends StatelessWidget {
  const ActiveTrackFocusPill({
    super.key,
    required this.label,
    required this.value,
    this.prominent = false,
    this.icon,
  });

  final String label;
  final String value;

  /// When true, render the primary accent treatment described above.
  final bool prominent;

  /// Optional leading icon shown beside the value (e.g. a calendar glyph for
  /// the Today pill). Only rendered when supplied.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = prominent
        ? Colors.white.withValues(alpha: 0.85)
        : kActiveTrackPrimaryBlue;
    final valueColor = prominent ? Colors.white : AppTheme.brandInk;
    final valueStyle =
        (prominent ? theme.textTheme.titleMedium : theme.textTheme.titleSmall)
            ?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.3,
              fontSize: prominent ? 17 : 14,
            );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: prominent ? kActiveTrackPrimaryBlue : kActiveTrackFocusPillBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: valueColor),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  // Day-level labels are short ("חולין דף כ״ה"); two lines is
                  // ample headroom and keeps the card height bounded.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: valueStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
