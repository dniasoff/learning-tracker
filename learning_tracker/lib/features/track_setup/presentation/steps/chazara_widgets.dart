import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
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
    const selectedGradient = LinearGradient(
      colors: [AppTheme.brandBlueDeep, AppTheme.brandBlueBright],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isSelected ? selectedGradient : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected ? AppTheme.brandBlueDeep : AppColors.surfaceE9,
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
                      ? AppColors.scrimLight
                      : AppColors.surfaceE9,
                  child: Icon(
                    icon,
                    size: 17,
                    color: isSelected ? Colors.white : AppTheme.brandBlueDeep,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isSelected ? Colors.white : AppTheme.brandInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppTheme.brandInkMuted,
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
                  l10n.schedulerDaysLabel.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.brandInkMuted,
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
              TinyCircleButton(icon: Icons.remove, onTap: onMinus),
              const SizedBox(width: 8),
              TinyCircleButton(icon: Icons.add, onTap: onPlus),
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
                  const Icon(Icons.add, color: AppTheme.brandInkMuted),
                  Text(
                    l10n.chazaraAddNew,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.brandInkMuted,
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
  const TinyCircleButton({required this.icon, required this.onTap, super.key});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
        child: Icon(icon, size: 14, color: AppTheme.brandInkMuted),
      ),
    );
  }
}
