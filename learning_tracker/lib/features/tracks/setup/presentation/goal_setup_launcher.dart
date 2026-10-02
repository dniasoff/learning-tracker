import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart'
    show goalRepositoryProvider;
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/after_track_change_invalidation.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// The curriculum's current goal: the most recently created one, which
/// defends against a stale row from an earlier track setup outliving a
/// re-add (same rule as `dashboard_providers.dart`'s pace status).
Future<GoalEntity?> latestCurriculumGoal(
  WidgetRef ref,
  CurriculumId curriculum,
) async {
  final goals = await ref.read(goalRepositoryProvider).getGoals(curriculum);
  if (goals.isEmpty) return null;
  return goals.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
}

/// Opens the existing [GoalSetupScreen] to add or edit the goal of
/// [curriculum], then persists the result through [goalRepositoryProvider],
/// runs [onTrackChanged] and shows the "goal saved" snackbar.
///
/// The same flow as `TrackDetailScreen._openGoalEdit` (the existing route
/// flow for a curriculum's goal), lifted out so the sub-track forms'
/// no-deadline link opens it without a second goal screen (Story 2.4 /
/// DNI-495 AC-6). Returns whether a goal was saved.
Future<bool> openCurriculumGoalSetup(
  BuildContext context,
  WidgetRef ref,
  CurriculumId curriculum,
) async {
  final l10n = AppLocalizations.of(context)!;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final existingEntity = await latestCurriculumGoal(ref, curriculum);
  final totalItems = await ref.read(scopedItemCountProvider(curriculum).future);

  if (!context.mounted) return false;

  final result = await navigator.push<GoalEntity>(
    MaterialPageRoute(
      builder: (_) => GoalSetupScreen(
        curriculumId: curriculum,
        existingGoal: existingEntity,
        totalItems: totalItems,
      ),
    ),
  );

  if (result == null || !context.mounted) return false;

  final repo = ref.read(goalRepositoryProvider);
  final paceTarget = result.paceTarget;

  if (existingEntity == null) {
    await repo.createGoal(
      curriculumId: curriculum,
      targetPercent: result.targetPercent,
      paceTarget: paceTarget,
      description: result.description,
      dateType: result.dateType,
      paceGranularity: result.paceGranularityKey,
    );
  } else {
    await repo.updateGoal(
      goal: existingEntity,
      targetPercent: result.targetPercent,
      paceTarget: paceTarget,
      // 'none' goals clear the pace target entirely.
      clearPaceTarget: paceTarget == null,
      description: result.description,
      paceGranularity: result.paceGranularity,
      clearLearningUnit: result.paceGranularityKey == null,
    );
  }

  await onTrackChanged(ref);

  if (context.mounted) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.goalSavedSnack)));
  }
  return true;
}
