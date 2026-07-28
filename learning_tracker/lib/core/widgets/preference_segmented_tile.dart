import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/widgets/preference_list_tile.dart';

/// A preference tile that combines a header row (icon pill + title + subtitle)
/// with a Material 3 [SegmentedButton] below it.
///
/// Generic over [T] so any value type (bool, enum, …) can be used.
///
/// RTL-safe: paddings use [EdgeInsetsDirectional].
class PreferenceSegmentedTile<T> extends StatelessWidget {
  const PreferenceSegmentedTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.iconBackground,
    required this.options,
    required this.value,
    required this.onChanged,
  }) : assert(
         options.length >= 2,
         'PreferenceSegmentedTile requires at least 2 options',
       );

  /// Primary label for the preference row.
  final String title;

  /// Optional secondary description displayed below [title].
  final String? subtitle;

  /// Optional icon for the leading pill.  When null no pill is rendered.
  final IconData? icon;

  /// Colour of the icon glyph inside the pill.
  final Color? iconColor;

  /// Background colour of the icon pill.
  final Color? iconBackground;

  /// Ordered list of (value, label) pairs that become [SegmentedButton] segments.
  final List<({T value, String label})> options;

  /// Currently selected value.
  final T value;

  /// Called when the user taps a segment.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header row ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                PreferenceIconPill(
                  icon: icon!,
                  iconColor: effectiveIconColor,
                  iconBackground: iconBackground,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 19,
                        color: context.colors.preferenceTitleInk,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.colors.preferenceSubtitleGrey,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Segmented button ────────────────────────────────────
          SegmentedButton<T>(
            showSelectedIcon: false,
            segments: options
                .map(
                  (o) => ButtonSegment<T>(value: o.value, label: Text(o.label)),
                )
                .toList(),
            selected: {value},
            onSelectionChanged: (selected) {
              if (selected.isEmpty) return;
              onChanged(selected.first);
            },
            style: SegmentedButton.styleFrom(
              // preferenceSegmentedSelectedFill (not brandBlueBright): this is
              // a solid FILL under the hardcoded white label below.
              // brandBlueBright lightens in dark mode for its normal
              // ink-on-card role, which drops that white label to 1.85:1 —
              // see the token's doc comment (AppPalette).
              selectedBackgroundColor:
                  context.colors.preferenceSegmentedSelectedFill,
              selectedForegroundColor: Colors.white,
              side: BorderSide(color: context.colors.preferenceSegmentedBorder),
            ),
          ),
        ],
      ),
    );
  }
}
