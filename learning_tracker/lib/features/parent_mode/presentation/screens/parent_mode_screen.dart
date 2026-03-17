import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/parent_mode/domain/services/parent_dashboard_aggregator.dart';
import 'package:learning_tracker/features/parent_mode/presentation/providers/parent_dashboard_providers.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/curriculum_card.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/engagement_card.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/key_stats_row.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/recent_completions_list.dart';

@RoutePage()
class ParentModeScreen extends ConsumerWidget {
  const ParentModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(parentDashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            tooltip: 'Manage Rewards',
            onPressed: () => context.router.push(const RewardCatalogRoute()),
          ),
          IconButton(
            icon: const Icon(Icons.stars),
            tooltip: 'Point Configuration',
            onPressed: () => context.router.push(const PointConfigRoute()),
          ),
          IconButton(
            icon: const Icon(Icons.lock),
            tooltip: 'Change PIN',
            onPressed: () => context.router.push(const PinChangeRoute()),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('Error loading dashboard: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(parentDashboardDataProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) => _DashboardBody(data: data),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final ParentDashboardData data;

  const _DashboardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final container = ProviderScope.containerOf(context);
        container.invalidate(parentDashboardDataProvider);
        // Wait for the provider to reload so the refresh indicator
        // stays visible until new data is ready.
        await container.read(parentDashboardDataProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick glance: key stats visible without scrolling
          KeyStatsRow(
            currentStreak: data.currentStreak,
            maxStreak: data.maxStreak,
            globalPoints: data.globalPoints,
          ),
          const SizedBox(height: 16),

          // Engagement metrics
          EngagementCard(engagement: data.engagement),
          const SizedBox(height: 16),

          // Per-curriculum cards
          if (data.curricula.isNotEmpty) ...[
            Text('Curricula', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...data.curricula.map(
              (summary) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CurriculumCard(summary: summary),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Recent completions
          if (data.recentCompletions.isNotEmpty) ...[
            Text(
              'Recent Activity (Last 7 Days)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            RecentCompletionsList(completions: data.recentCompletions),
          ],
        ],
      ),
    );
  }
}
