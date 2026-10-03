/// The goal setup a sub-track form's no-deadline link opens (Story 2.4 /
/// DNI-495 AC-6).
///
/// It reuses the existing [GoalSetupScreen] (no second goal screen) but
/// saves through the governed contract: the chosen goal becomes a
/// [GovernedAction] on the AD-43 fixed-id goal docs and goes through
/// `LearningCommands.applyGovernedChange` (C0 / DNI-524), which writes the
/// change-log entry with the doc. Nothing is written through the legacy
/// goal repository, whose writes the governed rules refuse.
///
/// A governed goal write needs a live parent session (AC-3): it is checked
/// before the goal screen opens and again just before the save, the goal
/// screen is hidden while the session is locked, and a save after the
/// session ended is refused with nothing written.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/governed_goal_change.dart';
import 'package:learning_tracker/features/sub_tracks/domain/school_year_sub_track_form_validation.dart'
    show civilDateOf;
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/widgets/sub_track_parent_session_hold.dart';

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

  /// Nothing was written: the goal could not be read or saved, or the
  /// parent session ended before the save.
  failed,
}

/// Opens the existing [GoalSetupScreen] for [curriculum], prefilled from its
/// governed goals, and saves the result through
/// `LearningCommands.applyGovernedChange`. The caller reports the outcome.
///
/// Fails before the screen opens when there is no parent session or the
/// commands or the current goals are unavailable, so the parent never fills
/// a form that cannot be saved. The goal screen shows only while the parent
/// session is live ([SubTrackParentSessionHold]), and the session is read
/// again just before the governed save: a session that ended in between
/// fails the save with nothing written.
Future<SubTrackGoalSetupOutcome> openSubTrackGoalSetup(
  BuildContext context,
  WidgetRef ref,
  CurriculumId curriculum,
) async {
  final navigator = Navigator.of(context);
  final curriculumKey = curriculum.storageKey;
  if (!await _parentSessionLive(ref, curriculumKey, 'open')) {
    return SubTrackGoalSetupOutcome.failed;
  }

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
      builder: (_) => SubTrackParentSessionHold(
        locked: Scaffold(
          appBar: AppBar(),
          body: const SizedBox.shrink(
            key: ValueKey('subTrackParentSessionLocked'),
          ),
        ),
        child: GoalSetupScreen(
          curriculumId: curriculum,
          existingGoal: goalEntityOf(curriculum, current),
          totalItems: totalItems,
        ),
      ),
    ),
  );
  if (result == null) return SubTrackGoalSetupOutcome.cancelled;

  final choice = goalChoiceOf(result, prefilledPace: prefilledPaceOf(current));
  if (choice == null) return SubTrackGoalSetupOutcome.failed;
  final action = governedGoalAction(
    curriculumId: curriculumKey,
    choice: choice,
    current: current,
    nowUtc: ref.read(localDayClockProvider).nowUtc(),
  );
  if (action == null) return SubTrackGoalSetupOutcome.saved;

  try {
    final commands = await ref.read(learningCommandsProvider.future);
    if (commands == null) return SubTrackGoalSetupOutcome.failed;
    // The command boundary: the session may have ended while the goal
    // screen was open.
    if (!await _parentSessionLive(ref, curriculumKey, 'save')) {
      return SubTrackGoalSetupOutcome.failed;
    }
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

/// Whether the parent session is live at [stage] (`open` / `save`); logs
/// the refusal.
Future<bool> _parentSessionLive(
  WidgetRef ref,
  String curriculumKey,
  String stage,
) async {
  if (await readSubTrackParentSession(ref)) return true;
  _log.warning(
    event: 'sub_track_goal_setup_no_parent_session',
    fields: {'curriculum_id': curriculumKey, 'stage': stage},
  );
  return false;
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

/// The live pace goal [goalEntityOf] prefills the goal screen with: the
/// live pace goal when there is no live deadline, else null.
PaceGoal? prefilledPaceOf(CurriculumGoals? goals) {
  final deadline = goals?.deadline;
  if (deadline != null && deadline.endedAt == null) return null;
  final pace = goals?.pace;
  return pace != null && pace.endedAt == null ? pace : null;
}

/// The goal screen's prefill for [goals]: the live deadline, else the live
/// pace goal, else none.
///
/// The goal screen edits whole numbers only, so a fractional stored pace
/// (e.g. 1.5) shows rounded; [goalChoiceOf] maps an untouched pace back to
/// the stored value, so the rounding never reaches a save.
GoalEntity? goalEntityOf(CurriculumId curriculum, CurriculumGoals? goals) {
  final now = DateTimeFactory.nowUtc();
  final deadline = goals?.deadline;
  if (deadline != null && deadline.endedAt == null) {
    final date = DateTime.parse(deadline.targetDate);
    return GoalEntity(
      curriculumId: curriculum,
      targetDate: DateTime(date.year, date.month, date.day),
      createdAt: now,
    );
  }
  final pace = prefilledPaceOf(goals);
  if (pace != null) {
    final granularity = PaceGranularity.fromStorageKey(pace.paceGranularity);
    return GoalEntity(
      curriculumId: curriculum,
      goalType: 'pace',
      paceValue: pace.paceValue.round(),
      pacePeriod: pace.paceUnit,
      paceGranularity: granularity,
      rawLearningUnit: granularity == null ? pace.paceGranularity : null,
      createdAt: now,
    );
  }
  return null;
}

/// The governed choice of the goal screen's [result], or null for an
/// incomplete result (a deadline without a date, a pace without a value).
/// A pace without a granularity counts in leaf units
/// ([kLeafPaceGranularity]).
///
/// [prefilledPace] is the live pace goal the screen was prefilled with
/// ([prefilledPaceOf]). When the result keeps its unit and granularity and
/// its value is the prefill's rounded value, the parent did not change the
/// pace: the stored value (e.g. 1.5) is kept exactly, so an unrelated save
/// never rewrites the learner's target.
GoalChoice? goalChoiceOf(GoalEntity result, {PaceGoal? prefilledPace}) =>
    switch (result.goalType) {
      'deadline' => switch (result.targetDate) {
        final date? => DeadlineGoalChoice(
          civilDateOf(date.year, date.month, date.day),
        ),
        null => null,
      },
      'pace' => switch ((result.paceValue, result.pacePeriod)) {
        (final value?, final unit?) => _paceChoice(
          value: value,
          unit: unit,
          // A curriculum without a unit picker (e.g. Mishnayos) returns no
          // granularity: it counts in leaf units, which a governed pace goal
          // must still name (AD-43).
          granularity: result.paceGranularityKey ?? kLeafPaceGranularity,
          prefilled: prefilledPace,
        ),
        _ => null,
      },
      _ => const NoGoalChoice(),
    };

PaceGoalChoice _paceChoice({
  required int value,
  required String unit,
  required String granularity,
  required PaceGoal? prefilled,
}) {
  final untouched =
      prefilled != null &&
      prefilled.paceUnit == unit &&
      prefilled.paceGranularity == granularity &&
      prefilled.paceValue.round() == value;
  return PaceGoalChoice(
    value: untouched ? prefilled.paceValue : value,
    unit: unit,
    granularity: granularity,
  );
}
