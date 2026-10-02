/// The governed "Add track" action (Story 1.14, DNI-476 AC-5): everything
/// the Add track flow configures is written as ONE named owner action whose
/// entities share one `action_id` in the change log.
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

/// The calendar-program enrolment of an added track.
final class AddTrackProgram {
  /// Creates the enrolment.
  const AddTrackProgram({
    required this.programId,
    this.trackingStartDate,
    this.trackingStartRef,
  });

  /// The `learningProgramSeeds` catalog id.
  final int programId;

  /// Start of the tracking window, if any.
  final DateTime? trackingStartDate;

  /// sefariaRef the learner starts tracking from, if any.
  final String? trackingStartRef;
}

/// Everything one Add track action writes for [curriculumId].
final class AddTrackPlan {
  /// Creates the plan.
  const AddTrackPlan({
    required this.curriculumId,
    required this.stages,
    required this.studyDays,
    this.scopes = const [],
    this.program,
    this.goal,
  });

  /// The curriculum (= track, AD-25).
  final CurriculumId curriculumId;

  /// The full stage set (1..N); stages beyond it are ended.
  final List<StageDefinition> stages;

  /// The full study-day set; days absent from it are ended.
  final Map<int, DayType> studyDays;

  /// The full scope selection; empty = the entire curriculum.
  final List<({int level, String value})> scopes;

  /// The calendar-program enrolment, or null for a self-paced track (any
  /// live enrolment is ended).
  final AddTrackProgram? program;

  /// The goal, or null for none (any live goal is ended).
  final GoalEntity? goal;
}

/// What one Add track action did.
final class AddTrackOutcome {
  /// Creates the outcome. A [queued] outcome must carry [confirmation].
  const AddTrackOutcome({
    required this.actionId,
    this.reAdded = false,
    this.queued = false,
    Future<bool> Function()? confirmation,
  }) : _confirmation = confirmation;

  /// The governed action id, or null when nothing changed.
  final String? actionId;

  /// Whether the curriculum's track had been removed and the action
  /// re-added it (AD-38, ruling B13): its prior config was restored and
  /// the plan's config was NOT applied (only entities the removed track
  /// never had — stages, study days — are seeded from the plan).
  final bool reAdded;

  /// Whether the action is only queued offline (AD-54): the device shows
  /// it, but the server has not confirmed it yet and may still refuse it
  /// (it then surfaces as a pending failure and the device rolls it back).
  final bool queued;

  final Future<bool> Function()? _confirmation;

  /// Resolves once the server has settled the track: true when it holds
  /// the added track live, false when the action was refused (or cannot be
  /// confirmed). Immediately true for an action that was not [queued].
  Future<bool> whenConfirmed() async {
    if (!queued) return true;
    final confirmation = _confirmation;
    if (confirmation == null) return false;
    try {
      return await confirmation();
    } on Object {
      return false;
    }
  }
}

/// Writes the Add track action.
abstract interface class AddTrackActionRepository {
  /// Writes [plan] as ONE governed action: the `mainTrack` (activated, or
  /// re-added when it was removed), then its stages, study days, scope,
  /// program and goal entities, in that order — one change-log entry per
  /// entity, all carrying the first entry's id as `action_id`, each
  /// entity's docs and entry in one self-contained batch of at most 10
  /// governed docs (AD-54; an entity over that budget sends the whole
  /// action through the online-only path).
  ///
  /// **Re-add (AD-38, ruling B13).** When [AddTrackPlan.curriculumId]'s
  /// track was removed (`ended_at` set), the action is a re-add: the
  /// `mainTrack` change only clears `ended_at` (keeping its lifecycle
  /// stamps), the removed track's stages, study days, scope, program and
  /// goal are kept as they were, and only a config entity the track never
  /// had (no live stages / no live study days) is seeded from [plan].
  /// Sub-tracks ended by the removal stay ended.
  ///
  /// An action queued offline returns a [AddTrackOutcome.queued] outcome
  /// whose [AddTrackOutcome.whenConfirmed] reports whether the server
  /// accepted the track.
  ///
  /// Throws when the backend is not ready or the commands refuse the
  /// action (e.g. a goal on a calendar-program curriculum, or online-only
  /// while offline).
  Future<AddTrackOutcome> applyAddTrack(AddTrackPlan plan);
}
