import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_body.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTracksAsync = ref.watch(dashboardActiveTracksStreamProvider);
    final userModeAsync = ref.watch(dashboardUserModeProvider);
    final streakAsync = ref.watch(dashboardStreakProvider);
    final selectedProfileAsync = ref.watch(selectedProfileProvider);
    final profileName = selectedProfileAsync.asData?.value?.displayName;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.brandCreamCard,
              AppTheme.brandBlueSoft.withValues(alpha: 0.22),
              AppTheme.brandCream,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: activeTracksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) =>
                Center(child: Text(l10n.errorWithMessage(e.toString()))),
            data: (activeTracks) {
              final userMode =
                  userModeAsync.asData?.value ?? UserMode.adult;
              final streakData = streakAsync.asData?.value;
              final currentStreak = streakData?.currentStreak ?? 0;
              final profileId = ref.watch(activeProfileIdProvider);

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(dashboardActiveTracksStreamProvider);
                  ref.invalidate(dashboardUserModeProvider);
                  ref.invalidate(dashboardStreakProvider);
                  ref.invalidate(dashboardGlobalPointsProvider);
                  ref.invalidate(dashboardChildNextRewardProvider);
                  ref.invalidate(allDailyTasksProvider);
                  ref.invalidate(
                    lifetimeTotalsAcrossAllCurriculaProvider(profileId),
                  );
                  ref.invalidate(lifetimeSummariesProvider(profileId));
                  // ignore: deprecated_member_use
                  ref.invalidate(globalLifetimeCurriculaProvider(profileId));
                  for (final c in CurriculumId.values) {
                    ref.invalidate(
                      lifetimeDataProvider((
                        profileId: profileId,
                        curriculumId: c,
                      )),
                    );
                  }
                  ref.invalidate(trackDualProgressMetricsProvider(profileId));
                  for (final t in activeTracks) {
                    ref.invalidate(
                      dashboardTrackCompletionPercentageProvider(t.id),
                    );
                    final c = CurriculumId.values.firstWhere(
                      (cv) => cv.storageKey == t.curriculumId,
                      orElse: () => CurriculumId.mishnayos,
                    );
                    ref.invalidate(dashboardLastCompletionProvider(c));
                    ref.invalidate(dashboardPaceStatusProvider(c));
                  }
                },
                child: DashboardBody(
                  activeTracks: activeTracks,
                  userMode: userMode,
                  currentStreak: currentStreak,
                  profileName: profileName,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
