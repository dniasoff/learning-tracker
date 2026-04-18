import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/auth/presentation/widgets/offline_top_banner.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class AppShellScreen extends StatelessWidget {
  const AppShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsScaffold(
      routes: const [
        DashboardRoute(),
        LearningRoute(),
        ProgressRoute(),
        SettingsRoute(),
      ],
      // Epic 20.8: top offline banner — cloud-born only, tier-gated
      // inside the widget so local-born users never see it.
      appBarBuilder: (_, __) => const PreferredSize(
        preferredSize: Size.fromHeight(32),
        child: OfflineTopBanner(),
      ),
      bottomNavigationBuilder: (context, tabsRouter) {
        final l10n = AppLocalizations.of(context)!;
        return NavigationBar(
          selectedIndex: tabsRouter.activeIndex,
          onDestinationSelected: tabsRouter.setActiveIndex,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l10n.dashboard,
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: l10n.learn,
            ),
            NavigationDestination(
              icon: const Icon(Icons.trending_up_outlined),
              selectedIcon: const Icon(Icons.trending_up),
              label: l10n.progress,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: l10n.settings,
            ),
          ],
        );
      },
    );
  }
}
