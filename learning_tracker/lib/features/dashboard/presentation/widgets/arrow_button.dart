import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

class ArrowButton extends StatelessWidget {
  const ArrowButton({
    super.key,
    required this.icon,
    required this.isEnabled,
    required this.onTap,
  });

  final IconData icon;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isEnabled
              ? AppTheme.brandCreamSoft
              : AppTheme.brandCreamSoft.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          icon,
          size: 32,
          color: isEnabled ? AppTheme.brandInk : AppTheme.brandInkMuted,
        ),
      ),
    );
  }
}
