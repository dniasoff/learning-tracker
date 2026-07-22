import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';

/// Mode card for the add-profile dialog (child vs adult).
///
/// Uses a public class name so `Foo(...)` inside [State] is not mistaken for a
/// private instance member (library-private `_Foo` types can mis-resolve there).
class AddProfileModePickCard extends StatelessWidget {
  const AddProfileModePickCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;

  static const _surfaceGrey = Color(0xFFF2F4F7);
  static const _iconCircleMuted = Color(0xFFE4E8EF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 148,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white : _surfaceGrey,
            borderRadius: BorderRadius.circular(20),
            border: selected
                ? Border.all(color: context.colors.brandBlue, width: 1.5)
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? context.colors.brandBlue
                          : _iconCircleMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: selected
                          ? Colors.white
                          : context.colors.brandInkMuted,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? context.colors.brandBlueDeep
                          : context.colors.brandInk,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? context.colors.brandBlue
                          : context.colors.brandInkMuted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: context.colors.brandBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
