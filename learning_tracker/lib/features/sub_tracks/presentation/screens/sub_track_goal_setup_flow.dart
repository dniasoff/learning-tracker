/// The goal setup a sub-track form's no-deadline link opens (Story 2.4 /
/// DNI-495 AC-6).
///
/// It reuses the existing [GoalSetupScreen] (no second goal screen) but
/// saves through the governed contract: the chosen goal becomes a
/// [GovernedAction] on the AD-43 fixed-id goal docs and goes through
/// `LearningCommands.applyGovernedChange` (C0 / DNI-524), which writes the
/// change-log entry with the doc. Nothing is written through the legacy
/// goal repository, whose writes the governed rules refuse.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/governed_goal_change.dart';
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart'
    show civilDateOf;

final _log = AppLogger.instance;

/// How long the flow waits for the complete governed-intent read before it
/// gives up (fail closed: no goal screen on unknown current goals).
const kGoalSetupIntentTimeout = Duration(seconds: 10);

/// What the goal setup flow did.
enum SubTrackGoalSetupOutcome {
  /// A goal change was applied (or queued offline), or nothing changed.
  saved,

  /// The parent closed the goal screen without saving.
  cancelled,

  /// Nothing was written: the goal could not be read or saved.
  failed,
}

/// Opens the existing [GoalSetupScreen] for [curriculum], prefilled from its
/// governed goals, and saves the result through
/// `LearningCommands.applyGovernedChange`. The caller reports the outcome.
///
/// Fails before the screen opens when the commands or the current goals are
/// unavailable, so the parent never fills a form that cannot be saved.
Future<SubTrackGoalSetupOutcome> openSubTrackGoalSetup(
  BuildContext context,
  WidgetRef ref,
  CurriculumId curriculum,
) async {
  final navigator = Navigator.of(context);
  final curriculumKey = curriculum.storageKey;

  final CurriculumGoals? current;
  final int? totalItems;
  try {
    final commands = await ref.read(learningCommandsProvider.future);
    if (commands == null) return SubTrackGoalSetupOutcome.failed;
    current = await _currentGoals(ref, curriculumKey);
    totalItems = await ref.read(scopedItemCountProvider(curriculum).future);
  } on Object catch (error, stack) {
    _log.error(
      event: 'sub_track_goal_setup_read_failed',
      fields: {'curriculum_id': curriculumKey},
      exception: error,
      stackTrace: stack,
    );
    return SubTrackGoalSetupOutcome.failed;
  }

  if (!context.mounted) return SubTrackGoalSetupOutcome.cancelled;
  final result = await navigator.push<GoalEntity>(
    MaterialPageRoute(
      builder: (_) => GoalSetupScreen(
        curriculumId: curriculum,
        existingGoal: goalEntityOf(curriculum, current),
        totalItems: totalItems,
      ),
    ),
  );
  if (result == null) return SubTrackGoalSetupOutcome.cancelled;

  final choice = goalChoiceOf(result);
  if (choice == null) return SubTrackGoalSetupOutcome.failed;
  final action = governedGoalAction(
    curriculumId: curriculumKey,
    choice: choice,
    current: current,
    nowUtc: DateTime.now().toUtc(),
  );
  if (action == null) return SubTrackGoalSetupOutcome.saved;

  try {
    final commands = await ref.read(learningCommandsProvider.future);
    if (commands == null) return SubTrackGoalSetupOutcome.failed;
    final saved = await commands.applyGovernedChange(action);
    if (saved is CaptureSuccess) return SubTrackGoalSetupOutcome.saved;
    _log.warning(
      event: 'sub_track_goal_setup_refused',
      fields: {
        'curriculum_id': curriculumKey,
        'result': saved.runtimeType.toString(),
      },
    );
    return SubTrackGoalSetupOutcome.failed;
  } on Object catch (error, stack) {
    _log.error(
      event: 'sub_track_goal_setup_save_failed',
      fields: {'curriculum_id': curriculumKey},
      exception: error,
      stackTrace: stack,
    );
    return SubTrackGoalSetupOutcome.failed;
  }
}

/// The curriculum's governed goals from the complete intent read, or null
/// when it has none. Throws when no learner or repository is available or
/// the read does not complete in time.
Future<CurriculumGoals?> _currentGoals(
  WidgetRef ref,
  String curriculumKey,
) async {
  final scope = await ref.read(activeLearnerScopeProvider.future);
  final repository = await ref.read(governedIntentRepositoryProvider.future);
  if (scope == null || repository == null) {
    throw StateError('No governed intent for the active learner');
  }
  final intent = await repository
      .watch(scope)
      .first
      .timeout(kGoalSetupIntentTimeout);
  return intent.goals[curriculumKey];
}

/// The goal screen's prefill for [goals]: the live deadline, else the live
/// pace goal, else none.
GoalEntity? goalEntityOf(CurriculumId curriculum, CurriculumGoals? goals) {
  final now = DateTime.now().toUtc();
  final deadline = goals?.deadline;
  if (deadline != null && deadline.endedAt == null) {
    final date = DateTime.parse(deadline.targetDate);
    return GoalEntity(
      curriculumId: curriculum,
      targetDate: DateTime(date.year, date.month, date.day),
      createdAt: now,
      updatedAt: now,
    );
  }
  final pace = goals?.pace;
  if (pace != null && pace.endedAt == null) {
    final granularity = PaceGranularity.fromStorageKey(pace.paceGranularity);
    return GoalEntity(
      curriculumId: curriculum,
      goalType: 'pace',
      paceValue: pace.paceValue.round(),
      pacePeriod: pace.paceUnit,
      paceGranularity: granularity,
      rawLearningUnit: granularity == null ? pace.paceGranularity : null,
      createdAt: now,
      updatedAt: now,
    );
  }
  return null;
}

/// The governed choice of the goal screen's [result], or null for an
/// incomplete result (a deadline without a date, a pace without a value).
/// A pace without a granularity counts in leaf units
/// ([kLeafPaceGranularity]).
GoalChoice? goalChoiceOf(GoalEntity result) => switch (result.goalType) {
  'deadline' => switch (result.targetDate) {
    final date? => DeadlineGoalChoice(
      civilDateOf(date.year, date.month, date.day),
    ),
    null => null,
  },
  'pace' => switch ((result.paceValue, result.pacePeriod)) {
    (final value?, final unit?) => PaceGoalChoice(
      value: value,
      unit: unit,
      // A curriculum without a unit picker (e.g. Mishnayos) returns no
      // granularity: it counts in leaf units, which a governed pace goal
      // must still name (AD-43).
      granularity: result.paceGranularityKey ?? kLeafPaceGranularity,
    ),
    _ => null,
  },
  _ => const NoGoalChoice(),
};
