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
  /// Returns the action id, or null when nothing changed. Throws when the
  /// backend is not ready or the commands refuse the action (e.g. a goal on
  /// a calendar-program curriculum, or online-only while offline).
  Future<String?> applyAddTrack(AddTrackPlan plan);
}
