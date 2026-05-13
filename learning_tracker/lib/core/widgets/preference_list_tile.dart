import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// A reusable list-tile for preference/settings screens.
///
/// Renders a leading icon in a coloured pill, a [title], an optional
/// [subtitle], and a trailing widget (defaults to a right-chevron).  Pass
/// `trailing: const SizedBox.shrink()` to suppress the chevron.
///
/// RTL-safe: paddings use [EdgeInsetsDirectional] and the leading icon
/// container is aligned with [AlignmentDirectional].
class PreferenceListTile extends StatelessWidget {
  const PreferenceListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  /// Primary label for the preference row.
  final String title;

  /// Optional secondary description displayed below [title].
  final String? subtitle;

  /// Optional leading widget.  When omitted the tile renders without a leading
  /// area (no padding is reserved).
  final Widget? leading;

  /// Optional trailing widget.  Defaults to a chevron-right icon when
  /// [onTap] is non-null and [trailing] is not provided.  Pass
  /// `const SizedBox.shrink()` to suppress the chevron entirely.
  final Widget? trailing;

  /// Tap handler.  When null the tile is non-interactive.
  final VoidCallback? onTap;

  /// Colour override for the [title] text.
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTrailing =
        trailing ??
        (onTap != null
            ? Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.55,
                ),
              )
            : null);

    return ListTile(
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: 14,
        vertical: 3,
      ),
      minLeadingWidth: 0,
      leading: leading,
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w600,
          fontSize: 19,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF929BAA),
                fontSize: 15,
              ),
            ),
      trailing: effectiveTrailing,
      onTap: onTap,
    );
  }

  /// Convenience factory: wraps a Material icon in the standard coloured pill
  /// used across the Settings screen.
  factory PreferenceListTile.withIcon({
    Key? key,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return PreferenceListTile(
      key: key,
      title: title,
      subtitle: subtitle,
      leading: _IconPill(
        icon: icon,
        iconColor: iconColor,
        iconBackground: iconBackground,
      ),
      trailing: trailing,
      onTap: onTap,
      titleColor: titleColor,
    );
  }
}

/// Circular coloured pill containing a single [icon], matching the style used
/// throughout the Settings and related screens.
class _IconPill extends StatelessWidget {
  const _IconPill({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: AlignmentDirectional.center,
      child: Icon(icon, color: iconColor, size: 16.5),
    );
  }
}

/// Reusable icon-pill widget exposed for callers that need to compose it
/// independently (e.g. inside [PreferenceSegmentedTile]).
class PreferenceIconPill extends StatelessWidget {
  const PreferenceIconPill({
    super.key,
    required this.icon,
    required this.iconColor,
    this.iconBackground = AppTheme.brandBlueSoft,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: iconBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: AlignmentDirectional.center,
      child: Icon(icon, color: iconColor, size: 16),
    );
  }
}
