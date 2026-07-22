import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';

class ArrowButton extends StatelessWidget {
  const ArrowButton({
    super.key,
    required this.icon,
    required this.isEnabled,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final bool isEnabled;
  final VoidCallback? onTap;

  /// AUD-dashboard-01 (AX-3): this control is icon-only, so it must carry
  /// an explicit, direction-specific label for TalkBack/VoiceOver. Callers
  /// pass the ARB-sourced string (e.g. `l10n.activeTracksPreviousTrack`).
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: isEnabled,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isEnabled
                ? context.colors.brandCreamSoft
                : context.colors.brandCreamSoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(
            icon,
            size: 32,
            color: isEnabled
                ? context.colors.brandInk
                : context.colors.brandInkMuted,
          ),
        ),
      ),
    );
  }
}
