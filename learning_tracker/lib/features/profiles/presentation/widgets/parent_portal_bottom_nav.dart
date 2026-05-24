import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Parent portal bottom bar (Dashboard · Tracks · Rewards · Parent settings).
///
/// Selected tab uses a navy pill matching the reward-configuration mock
/// (`#00218D`); unselected items use muted grey labels.
class ParentPortalBottomNav extends StatelessWidget {
  const ParentPortalBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  /// `0` Dashboard, `1` Tracks, `2` Rewards, `3` Parent settings.
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const Color _navy = Color(0xFF00218D);
  static const Color _muted = AppTheme.brandCoral;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <({IconData icon, String label})>[
      (icon: Icons.space_dashboard_rounded, label: l10n.dashboard),
      (icon: Icons.menu_book_rounded, label: l10n.bottomNavTracks),
      (icon: Icons.emoji_events_rounded, label: l10n.bottomNavRewards),
      (icon: Icons.settings_rounded, label: l10n.bottomNavParent),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1400218D),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavPillItem(
                    icon: items[i].icon,
                    label: items[i].label,
                    selected: i == selectedIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavPillItem extends StatelessWidget {
  const _NavPillItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : ParentPortalBottomNav._muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: selected
                  ? ParentPortalBottomNav._navy
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x3300218D),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 9,
                    letterSpacing: 0.4,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Switches between parent-portal destinations without stacking duplicate routes.
///
/// WS4.boundary (DEC-4): Tab 0 (Dashboard) switches the user into the child's
/// full experience. This requires an explicit confirmation so the switch is
/// intentional — not a silent drop into the child's view.
///
/// [ref] is required to read the active profile name for the confirmation copy.
Future<void> navigateParentPortalTab(
  BuildContext context,
  int index, {
  required int currentTabIndex,
  required WidgetRef ref,
}) async {
  if (index == currentTabIndex) return;
  final router = context.router;
  switch (index) {
    case 0:
      // WS4.boundary (DEC-4): Switching into the child's full experience is an
      // explicit action, not a silent navigation. Show a confirmation dialog so
      // the parent consciously chooses to enter the child's view.
      final confirmed = await _confirmSwitchIntoChild(context, ref);
      if (!confirmed || !context.mounted) return;
      await router.replaceAll([
        const AppShellRoute(children: [DashboardRoute()]),
      ]);
      return;
    case 1:
      await router.replace(const ParentTrackManagementRoute());
      return;
    case 2:
      await router.replace(const RewardConfigurationRoute());
      return;
    case 3:
      await router.replace(const ParentSettingsRoute());
      return;
    default:
      return;
  }
}

/// Shows a confirmation dialog before a parent switches into a child's full
/// experience (child mode / child dashboard).
///
/// Returns [true] when the user confirms, [false] when they cancel.
Future<bool> _confirmSwitchIntoChild(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context)!;
  final activeProfileId = ref.read(activeProfileIdProvider);
  final profiles =
      await ref.read(profileListStreamProvider.future).timeout(
        const Duration(seconds: 1),
        onTimeout: () => [],
      );
  final activeProfile =
      profiles.where((p) => p.id == activeProfileId).firstOrNull;
  final childName = activeProfile?.displayName ?? l10n.child;

  if (!context.mounted) return false;

  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.switchIntoChildTitle),
          content: Text(l10n.switchIntoChildMessage(childName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.switchIntoChildConfirm),
            ),
          ],
        ),
      ) ??
      false;
}
