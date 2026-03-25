import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/features/parent_mode/domain/services/parent_dashboard_aggregator.dart';
import 'package:learning_tracker/features/parent_mode/presentation/providers/parent_dashboard_providers.dart';
import 'package:learning_tracker/features/parent_mode/presentation/widgets/recent_completions_list.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

@RoutePage()
class ParentModeScreen extends ConsumerWidget {
  const ParentModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(parentDashboardDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const AppBarTitle(text: 'Parent Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Child',
            onPressed: () =>
                context.router.push(const ParentTrackManagementRoute()),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => context.router.push(const NotificationsRoute()),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
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
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final ParentDashboardData data;

  const _DashboardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const green = Color(0xFF4ADE80);

    return RefreshIndicator(
      onRefresh: () async {
        final container = ProviderScope.containerOf(context);
        container.invalidate(parentDashboardDataProvider);
        await container.read(parentDashboardDataProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Key stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: '${data.currentStreak}',
                  label: 'Day Streak',
                  icon: Icons.local_fire_department,
                  iconColor: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: '${data.globalPoints}',
                  label: 'Total Points',
                  icon: Icons.stars,
                  iconColor: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Engagement card
          _EngagementTile(engagement: data.engagement),
          const SizedBox(height: 16),

          // Progress Overview
          if (data.curricula.isNotEmpty) ...[
            Text(
              'Progress Overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...data.curricula.map(
              (summary) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ParentCurriculumCard(summary: summary),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Weekly goal progress
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flag, color: green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Weekly Goal: ${data.globalPoints} Pts',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep up the momentum!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (data.globalPoints / 500).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: green.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(green),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Rewards & Quick Actions
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.card_giftcard,
                  label: 'Rewards',
                  onTap: () => context.router.push(const RewardCatalogRoute()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionTile(
                  icon: Icons.tune,
                  label: 'Point Config',
                  onTap: () => context.router.push(const PointConfigRoute()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionTile(
                  icon: Icons.lock_outline,
                  label: 'Change PIN',
                  onTap: () => context.router.push(const PinChangeRoute()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // View child's learning journey
          _ViewChildJourneyTile(),
          const SizedBox(height: 16),

          // Recent Activity
          if (data.recentCompletions.isNotEmpty) ...[
            Text(
              'Recent Activity',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            RecentCompletionsList(completions: data.recentCompletions),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EngagementTile extends StatelessWidget {
  final EngagementMetrics engagement;

  const _EngagementTile({required this.engagement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${engagement.daysActiveThisWeek}/7',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Days Active',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      engagement.averageDailyCompletions.toStringAsFixed(1),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Avg/Day',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentCurriculumCard extends StatelessWidget {
  final CurriculumSummary summary;

  const _ParentCurriculumCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final curriculumColor = _getCurriculumColor(summary.curriculum);
    final pctDisplay = (summary.completionPercentage * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Circular progress indicator
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: summary.completionPercentage,
                    strokeWidth: 4,
                    backgroundColor: curriculumColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(curriculumColor),
                  ),
                  Text(
                    '$pctDisplay%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: curriculumColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.curriculum.displayNameEn,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.points} pts earned',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.amber.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            _PaceBadge(status: summary.paceStatus),
          ],
        ),
      ),
    );
  }

  Color _getCurriculumColor(CurriculumId id) {
    return switch (id) {
      CurriculumId.mishnayos => const Color(0xFF4A90E2),
      CurriculumId.bavli => const Color(0xFF8B4789),
      CurriculumId.yerushalmi => const Color(0xFF2ECC71),
      CurriculumId.mishnaBerurah => const Color(0xFFE67E22),
      CurriculumId.chumash => const Color(0xFFE74C3C),
      _ => const Color(0xFF4ADE80),
    };
  }
}

class _PaceBadge extends StatelessWidget {
  final PaceStatusType status;

  const _PaceBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PaceStatusType.ahead => ('Ahead', Colors.green),
      PaceStatusType.onPace => ('On Pace', Colors.blue),
      PaceStatusType.behind => ('Behind', Colors.orange),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewChildJourneyTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfileId = ref.watch(activeProfileIdProvider);

    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.auto_stories,
            color: Colors.deepPurple,
            size: 24,
          ),
        ),
        title: const Text("View Child's Learning Journey"),
        subtitle: const Text('See lifetime achievements'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.router.push(LearningJourneyRoute(profileId: activeProfileId));
        },
      ),
    );
  }
}
