import 'dart:math';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/dashboard/domain/models/calendar_position.dart';
import 'package:learning_tracker/features/dashboard/domain/models/chazara_status.dart';
import 'package:learning_tracker/features/dashboard/domain/models/momentum_status.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_progress.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/program_calendar_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'track_progress_providers.g.dart';

/// Provides [TrackProgress] for a single track, with variant-specific data.
///
/// The variant is determined by the track's program enrollment and goal type:
///   programId != null → programCalendar
///   goalType == 'deadline' → deadlineGoal
///   goalType == 'pace' → velocityGoal
///   no goal → momentum
@riverpod
Future<TrackProgress> trackProgress(Ref ref, int trackId) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  // 1. Load track
  final track = await db.trackDao.getTrackById(trackId);
  if (track == null) throw StateError('Track $trackId not found');

  final curriculumId = CurriculumId.values.firstWhere(
    (c) => c.storageKey == track.curriculumId,
    orElse: () => CurriculumId.mishnayos,
  );

  // 2. Check for program enrollment
  final enrollment = await db.profileProgramDao
      .getProgramForProfileAndCurriculum(profileId, track.curriculumId);
  final programId = enrollment?.programId;

  // 3. Load goal for this track
  final goal = await db.goalDao.getGoalByTrack(trackId);
  final goalType = goal?.goalType;

  // 4. Determine variant
  final variant = resolveVariant(programId: programId, goalType: goalType);

  // 5. Load track-scoped completions
  final completions = await db.completionDao.getCompletionsByTrackAndProfile(
    trackId,
    profileId,
  );

  // 6. Count total items (from curriculum-scoped content count)
  final totalItems = await db.completionDao.getAggregateCountByProfile(
    track.curriculumId,
    profileId,
  );

  // 7. Build track label
  final trackLabel = '${curriculumId.displayNameHe} (${track.trackType})';

  // 8. Compute variant-specific fields
  final now = DateTime.now().toUtc();

  PaceStatus? paceStatus;
  CalendarPosition? calendarPos;
  MomentumStatus? momentumStatus;
  double? scopePercentage;

  switch (variant) {
    case TrackProgressVariant.programCalendar:
      try {
        calendarPos = await ref.read(
          programCalendarPositionProvider(trackId).future,
        );
      } catch (_) {
        calendarPos = const CalendarPosition(
          currentDay: 1,
          totalDays: 1,
          todayRef: '',
          todayDisplayHe: '',
          delta: 0,
          status: CalendarStatus.caughtUp,
        );
      }
    case TrackProgressVariant.deadlineGoal:
      if (goal != null && goal.targetDate != null) {
        final dailyCounts = _buildDailyCounts(completions);
        paceStatus = PaceCalculator.calculate(
          goalStartDate: goal.createdAt,
          goalDeadline: goal.targetDate!,
          totalItems: totalItems > 0 ? totalItems : 1,
          completedItems: completions.length,
          dailyCompletionCounts: dailyCounts,
          today: now,
        );
      }
      scopePercentage = totalItems > 0
          ? (completions.length / totalItems) * 100
          : 0;
    case TrackProgressVariant.velocityGoal:
      if (goal != null && goal.paceValue != null) {
        final dailyCounts = _buildDailyCounts(completions);
        paceStatus = PaceCalculator.calculateForPaceGoal(
          targetPacePerDay: PaceCalculator.paceToDaily(
            goal.paceValue!,
            goal.paceUnit!,
          ),
          totalItems: totalItems > 0 ? totalItems : 1,
          completedItems: completions.length,
          dailyCompletionCounts: dailyCounts,
          today: now,
        );
      }
      scopePercentage = totalItems > 0
          ? (completions.length / totalItems) * 100
          : 0;
    case TrackProgressVariant.momentum:
      momentumStatus = _calculateMomentum(completions, now);
      scopePercentage = totalItems > 0
          ? (completions.length / totalItems) * 100
          : 0;
  }

  // 9. Compute chazara status
  final stages = await db.stageDao.getStagesByTrack(trackId);
  final chazaraStatus = _computeChazaraStatus(stages, completions, now);

  return TrackProgress(
    trackId: trackId,
    trackLabel: trackLabel,
    curriculumId: curriculumId,
    variant: variant,
    scopePercentage: scopePercentage,
    completedItems: completions.length,
    totalItems: totalItems,
    paceStatus: paceStatus,
    calendarPos: calendarPos,
    momentum: momentumStatus,
    chazaraStatus: chazaraStatus,
    tasksToday: 0, // Computed by scheduler, not here
  );
}

/// Provides [TrackProgress] for all active tracks.
@riverpod
Future<List<TrackProgress>> activeTrackProgressList(Ref ref) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  final tracks = await db.trackDao.getActiveTracksForProfile(profileId);

  final progressList = <TrackProgress>[];
  for (final track in tracks) {
    final progress = await ref.read(trackProgressProvider(track.id).future);
    progressList.add(progress);
  }
  return progressList;
}

// ── Helpers ──

/// Build date -> count map from completions list.
Map<DateTime, int> _buildDailyCounts(List<Completion> completions) {
  final counts = <DateTime, int>{};
  for (final c in completions) {
    final date = DateTime.utc(
      c.completedAt.year,
      c.completedAt.month,
      c.completedAt.day,
    );
    counts[date] = (counts[date] ?? 0) + 1;
  }
  return counts;
}

/// Count completions in the last 7 days.
int _countLast7Days(List<Completion> completions, DateTime now) {
  final cutoff = now.subtract(const Duration(days: 7));
  return completions.where((c) => c.completedAt.isAfter(cutoff)).length;
}

/// Calculate momentum status for a track with no goal.
MomentumStatus _calculateMomentum(List<Completion> completions, DateTime now) {
  final totalCompletions = completions.length;
  final recentCount = _countLast7Days(completions, now);

  if (totalCompletions < 3) {
    return MomentumStatus(
      recentCount: recentCount,
      personalAverage: 0.0,
      level: MomentumLevel.gettingStarted,
      daysSinceLastCompletion: _daysSinceLastCompletion(completions, now),
    );
  }

  final daysSince = _daysSinceLastCompletion(completions, now);
  final personalAvg = _computePersonalAverage(completions, now);

  MomentumLevel level;
  if (recentCount == 0 && (daysSince ?? 0) >= 3) {
    level = MomentumLevel.paused;
  } else if (recentCount >= personalAvg * 0.8) {
    level = MomentumLevel.active;
  } else {
    level = MomentumLevel.slowing;
  }

  return MomentumStatus(
    recentCount: recentCount,
    personalAverage: personalAvg,
    level: level,
    daysSinceLastCompletion: daysSince,
  );
}

/// Compute average completions per 7-day window over last 30 days.
double _computePersonalAverage(List<Completion> completions, DateTime now) {
  if (completions.isEmpty) return 0.0;

  final earliest = completions
      .map((c) => c.completedAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final trackAge = now.difference(earliest).inDays;
  final windowDays = max(trackAge < 14 ? trackAge : 30, 7);

  final cutoff = now.subtract(Duration(days: windowDays));
  final inWindow = completions
      .where((c) => c.completedAt.isAfter(cutoff))
      .length;

  return (inWindow / windowDays) * 7;
}

/// Days since the most recent completion, or null if completed today.
int? _daysSinceLastCompletion(List<Completion> completions, DateTime now) {
  if (completions.isEmpty) return null;

  final latest = completions
      .map((c) => c.completedAt)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  final days = now.difference(latest).inDays;
  return days == 0 ? null : days;
}

/// Compute chazara (review) status for a track.
///
/// Returns null if the track has 0 or 1 stages (no review stages).
ChazaraStatus? _computeChazaraStatus(
  List<StageDefinition> stages,
  List<Completion> completions,
  DateTime now,
) {
  if (stages.length <= 1) return null;

  // Group completions by sefariaRef + stageId
  final byRef = <String, Map<int, DateTime>>{};
  for (final c in completions) {
    byRef.putIfAbsent(c.sefariaRef, () => {});
    final existing = byRef[c.sefariaRef]![c.stageId];
    if (existing == null || c.completedAt.isAfter(existing)) {
      byRef[c.sefariaRef]![c.stageId] = c.completedAt;
    }
  }

  var dueToday = 0;
  var overdue = 0;

  for (final entry in byRef.entries) {
    final completedStages = entry.value;
    for (var i = 1; i < stages.length; i++) {
      final stage = stages[i];
      if (completedStages.containsKey(stage.id)) continue;

      final prevStage = stages[i - 1];
      final prevStageDate = completedStages[prevStage.id];
      if (prevStageDate == null) break;

      final dueDate = prevStageDate.add(Duration(days: stage.delayDays));
      final isSameDay =
          now.year == dueDate.year &&
          now.month == dueDate.month &&
          now.day == dueDate.day;

      if (now.isAfter(dueDate) && !isSameDay) {
        overdue++;
      } else if (isSameDay) {
        dueToday++;
      }
    }
  }

  return ChazaraStatus(
    dueToday: dueToday,
    overdue: overdue,
    isCaughtUp: dueToday == 0 && overdue == 0,
    source: ChazaraSource.userConfigured,
  );
}
