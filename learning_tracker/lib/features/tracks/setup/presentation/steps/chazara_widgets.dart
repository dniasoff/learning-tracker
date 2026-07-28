import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class ReviewPresetCard extends StatelessWidget {
  const ReviewPresetCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedGradient = LinearGradient(
      colors: [context.colors.brandBlueDeep, context.colors.brandBlueBright],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isSelected ? selectedGradient : null,
        // AUD dark-mode sweep: this was a hardcoded Colors.white, which stays
        // white in dark mode while the card's own title text correctly reads
        // context.colors.brandInk (near-white in dark) — white-on-white,
        // measured 1.06:1 on device. brandCreamCard is the theme-aware card
        // surface token (white in light, matches the old literal exactly;
        // darkens to 0xFF151A26 in dark) so the card now darkens along with
        // its ink.
        color: isSelected ? null : context.colors.brandCreamCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected
              ? context.colors.brandBlueDeep
              : context.colors.surfaceE9,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isSelected
                      ? context.colors.scrimLight
                      : context.colors.surfaceE9,
                  child: Icon(
                    icon,
                    size: 17,
                    color: isSelected
                        ? Colors.white
                        : context.colors.brandBlueDeep,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isSelected ? Colors.white : context.colors.brandInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : context.colors.brandInkMuted,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomDayEditorChip extends StatelessWidget {
  const CustomDayEditorChip({
    required this.day,
    required this.accentColor,
    required this.onMinus,
    required this.onPlus,
    this.onRemove,
    super.key,
  });

  final int day;
  final Color accentColor;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accentColor, width: 5),
              color: Colors.white,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  // R1-(3): plural-correct unit word. count==1 → "DAY",
                  // otherwise "DAYS" (was always "DAYS", so "1 DAYS").
                  l10n.chazaraDayUnitLabel(day).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.colors.brandInkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TinyCircleButton(
                icon: Icons.remove,
                onTap: onMinus,
                semanticLabel: l10n.chazaraCustomDayDecrease,
              ),
              const SizedBox(width: 8),
              TinyCircleButton(
                icon: Icons.add,
                onTap: onPlus,
                semanticLabel: l10n.chazaraCustomDayIncrease,
              ),
            ],
          ),
          if (onRemove != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 24),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: Text(
                l10n.actionRemove,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AddRoundChip extends StatelessWidget {
  const AddRoundChip({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD1D5DE),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: context.colors.brandInkMuted),
                  Text(
                    l10n.chazaraAddNew,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.colors.brandInkMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TinyCircleButton extends StatelessWidget {
  const TinyCircleButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// AUD-tracks-10 (AX-3): this control is icon-only, so it must carry an
  /// explicit, action-specific label for TalkBack/VoiceOver. Callers pass
  /// the ARB-sourced string (e.g. `l10n.chazaraCustomDayDecrease`).
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF1F3F7),
            border: Border.all(color: const Color(0xFFDDE2EB)),
          ),
          child: Icon(icon, size: 14, color: context.colors.brandInkMuted),
        ),
      ),
    );
  }
}
