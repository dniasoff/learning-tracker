import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/services/cross_curriculum_aggregator.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_providers.g.dart';

/// Provider for the CrossCurriculumAggregator instance.
@riverpod
CrossCurriculumAggregator crossCurriculumAggregator(Ref ref) {
  return CrossCurriculumAggregator();
}

/// Provider for the user mode, resolved from the database.
///
/// Defaults to [UserMode.adult] if no profile exists.
/// P6 compliant: uses only core database, no feature imports.
@riverpod
Future<UserMode> dashboardUserMode(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final profiles = await db.userProfileDao.getAllUserProfiles();
  if (profiles.isEmpty) return UserMode.adult;
  return UserMode.values.firstWhere(
    (m) => m.name == profiles.first.userMode,
    orElse: () => UserMode.adult,
  );
}

/// Provider for list of active curricula IDs, scoped to active profile.
@riverpod
Future<List<CurriculumId>> dashboardActiveCurricula(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final storageKeys =
      await db.activeCurriculumDao.getActiveCurriculaByProfile(profileId);
  return storageKeys
      .map<CurriculumId?>((key) {
        final matches = CurriculumId.values.where((c) => c.storageKey == key);
        return matches.isNotEmpty ? matches.first : null;
      })
      .whereType<CurriculumId>()
      .toList();
}

/// Stream provider for watching active curricula changes, scoped to active profile.
@riverpod
Stream<List<CurriculumId>> dashboardActiveCurriculaStream(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return db.activeCurriculumDao
      .watchActiveCurriculaByProfile(profileId)
      .map((storageKeys) {
    return storageKeys
        .map<CurriculumId?>((key) {
          final matches = CurriculumId.values.where((c) => c.storageKey == key);
          return matches.isNotEmpty ? matches.first : null;
        })
        .whereType<CurriculumId>()
        .toList();
  });
}

/// Per-curriculum completion percentage, scoped to active profile.
@riverpod
Future<double> dashboardCompletionPercentage(
  Ref ref,
  CurriculumId curriculum,
) async {
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final completions =
      await db.completionDao.getCompletionsByCurriculumAndProfile(
    curriculum.storageKey,
    profileId,
  );
  final stages = await db.stageDao.getStageDefinitionsByCurriculum(
    curriculum.storageKey,
  );
  if (stages.isEmpty) return 0.0;

  // Count unique content items that completed ALL stages
  final totalStages = stages.length;
  final completionsByRef = <String, Set<int>>{};
  for (final c in completions) {
    completionsByRef.putIfAbsent(c.sefariaRef, () => {}).add(c.stageId);
  }

  // We need total items count — use completions + content for now
  // For a proper count we'd need content items, but that's a feature import.
  // Instead, count items that have at least one completion vs items fully done.
  if (completionsByRef.isEmpty) return 0.0;

  var fullyCompleted = 0;
  for (final stages in completionsByRef.values) {
    if (stages.length >= totalStages) fullyCompleted++;
  }

  // This is a simplified metric: completed items / items touched
  // For the dashboard, we show progress of items that have been started
  return completionsByRef.isNotEmpty
      ? fullyCompleted / completionsByRef.length
      : 0.0;
}

/// Per-curriculum last completion timestamp, scoped to active profile.
@riverpod
Future<DateTime?> dashboardLastCompletion(
  Ref ref,
  CurriculumId curriculum,
) async {
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final completions =
      await db.completionDao.getCompletionsByCurriculumAndProfile(
    curriculum.storageKey,
    profileId,
  );
  if (completions.isEmpty) return null;
  // Completions are returned in insertion order; find the latest
  var latest = completions.first.completedAt;
  for (final c in completions) {
    if (c.completedAt.isAfter(latest)) latest = c.completedAt;
  }
  return latest;
}

/// Streak data provider (P6 compliant — uses core DB DAO).
@riverpod
Stream<({int currentStreak, int maxStreak})> dashboardStreak(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.streakDao.watchStreak().map((streak) {
    if (streak == null) return (currentStreak: 0, maxStreak: 0);
    return (currentStreak: streak.currentStreak, maxStreak: streak.maxStreak);
  });
}

/// Global points total, scoped to active profile.
@riverpod
Future<int> dashboardGlobalPoints(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final completions =
      await db.completionDao.getCompletionsByProfile(profileId);
  return completions.fold<int>(0, (sum, c) => sum + c.points);
}
