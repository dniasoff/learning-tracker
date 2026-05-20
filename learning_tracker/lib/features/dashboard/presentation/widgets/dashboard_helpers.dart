import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

/// Color constants shared across dashboard widgets.

/// Primary blue for active-track CTA (design spec).
const Color kActiveTrackPrimaryBlue = Color(0xFF122FA0);

/// Green completion bar (self-paced card).
const Color kActiveTrackCompletionGreen = AppColors.statusSuccess;

/// Grey pill behind next-task / current-focus content.
const Color kActiveTrackFocusPillBg = Color(0xFFF1F2F5);

/// Lifetime bar on the "all caught up" dashboard stats card (design spec).
const Color kAllCaughtUpProgressFill = Color(0xFFFFB775);

/// Child dashboard — points & rewards hero (design spec).
const Color kChildRewardsCardBlueTop = Color(0xFF1E52D4);
const Color kChildRewardsCardBlueDeep = Color(0xFF0E266F);
const Color kChildRewardsProgressTrack = Color(0xFF0A1F55);
const Color kChildRewardsProgressFill = AppColors.statusSuccess;

class DashboardTaskGroups {
  const DashboardTaskGroups({
    required this.todayTasks,
    required this.overdueTasks,
    required this.reviewTasks,
  });

  final List<DailyTask> todayTasks;
  final List<DailyTask> overdueTasks;
  final List<DailyTask> reviewTasks;
}

DashboardTaskGroups groupTasks(List<DailyTask> tasks) {
  final todayTasks = <DailyTask>[];
  final overdueTasks = <DailyTask>[];
  final reviewTasks = <DailyTask>[];

  bool isReview(DailyTask task) =>
      task.priority == DailyTaskPriority.overdueChazara ||
      task.priority == DailyTaskPriority.scheduledChazara;

  for (final task in tasks) {
    if (isReview(task)) {
      reviewTasks.add(task);
      continue;
    }

    if (task.isOverdue) {
      overdueTasks.add(task);
      continue;
    }

    todayTasks.add(task);
  }

  return DashboardTaskGroups(
    todayTasks: todayTasks,
    overdueTasks: overdueTasks,
    reviewTasks: reviewTasks,
  );
}

class TrackTaskBuckets {
  const TrackTaskBuckets({
    required this.missedProgram,
    required this.dueTodayLane,
    required this.review,
  });

  /// Missed program days (non-review overdue), aligned with dashboard lanes.
  final List<DailyTask> missedProgram;

  /// On-time program + new learning (not chazara).
  final List<DailyTask> dueTodayLane;

  /// All chazara / review tasks for this track.
  final List<DailyTask> review;

  int get total => missedProgram.length + dueTodayLane.length + review.length;
}

TrackTaskBuckets bucketTrackTasks(List<DailyTask> tasks) {
  final missedProgram = <DailyTask>[];
  final dueTodayLane = <DailyTask>[];
  final review = <DailyTask>[];

  bool isReview(DailyTask t) =>
      t.priority == DailyTaskPriority.overdueChazara ||
      t.priority == DailyTaskPriority.scheduledChazara;

  for (final t in tasks) {
    if (isReview(t)) {
      review.add(t);
    } else if (t.isOverdue) {
      missedProgram.add(t);
    } else {
      dueTodayLane.add(t);
    }
  }

  return TrackTaskBuckets(
    missedProgram: missedProgram,
    dueTodayLane: dueTodayLane,
    review: review,
  );
}

/// Task to highlight on the active-track card for calendar-linked programs.
///
/// [allTasks] is sorted with [DailyTaskPriority.overdueProgram] before
/// [DailyTaskPriority.todayProgram], so the first row is backlog — not
/// "today's" assignment. Prefer an explicit today row when present.
DailyTask? programTrackFocusTask(List<DailyTask> tasks) {
  if (tasks.isEmpty) return null;
  for (final t in tasks) {
    if (t.priority == DailyTaskPriority.todayProgram) return t;
  }
  return tasks.first;
}
