import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
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
  static const Color _muted = Color(0xFF708090);

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
Future<void> navigateParentPortalTab(
  BuildContext context,
  int index, {
  required int currentTabIndex,
}) async {
  if (index == currentTabIndex) return;
  final router = context.router;
  switch (index) {
    case 0:
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
