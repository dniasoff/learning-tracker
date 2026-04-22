import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/settings/presentation/utils/account_actions.dart';

/// Configuration hub shown to a parent when their child profile is active.
///
/// Surfaces parent-only controls — managing tracks for the child, tuning
/// reward points, and jumping to the parent dashboard for an overview.
@RoutePage()
class ParentSettingsScreen extends ConsumerWidget {
  const ParentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(firebaseAuthProvider).currentUser;

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Parent Mode')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.route,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Manage Tracks'),
                    subtitle: const Text(
                      "Add, edit, or archive your child's tracks",
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.pushRoute(const ParentTrackManagementRoute()),
                  ),
                  Divider(height: 1, indent: 56, color: theme.dividerColor),
                  ListTile(
                    leading: Icon(Icons.tune, color: theme.colorScheme.primary),
                    title: const Text('Point Configuration'),
                    subtitle: const Text(
                      'Set how many points activities are worth',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.pushRoute(const PointConfigRoute()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.dashboard_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Parent Dashboard'),
                subtitle: const Text(
                  "See your child's learning progress at a glance",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushRoute(const ParentModeRoute()),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Delete Account',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: const Text(
                  'Permanently remove this account and cloud data',
                ),
                onTap: () => showDeleteAccountFlow(context, ref, user),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
