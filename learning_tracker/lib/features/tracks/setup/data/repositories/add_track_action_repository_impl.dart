/// Firestore-backed [AddTrackActionRepository] (Story 1.14, DNI-476 AC-5):
/// plans each governed entity of the Add track action with its owner
/// repository (`planActivateTrack`, `planReplaceStages`, `planReplaceAll`,
/// `planSetScopes`, `planSetProgram` / `planRemoveProgram`, `planSetGoal`)
/// and hands them, in action order, to `LearningCommands
/// .applyGovernedChange` as ONE action through the owner governed writer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/add_track_action_repository.dart';

/// Thrown when an Add track write finds no active account or profile.
final class AddTrackNotReadyException implements Exception {
  /// Creates the exception.
  const AddTrackNotReadyException();

  @override
  String toString() =>
      'AddTrackNotReadyException: no active account or learner profile yet';
}

/// See the library doc comment.
final class FirestoreAddTrackActionRepository
    implements AddTrackActionRepository {
  /// Creates the repository; [clock] stamps a new goal's `created_at`.
  FirestoreAddTrackActionRepository({
    required Ref ref,
    DateTime Function()? clock,
  }) : _ref = ref,
       _clock = clock ?? (() => DateTime.now().toUtc());

  final Ref _ref;
  final DateTime Function() _clock;

  @override
  Future<String?> applyAddTrack(AddTrackPlan plan) async {
    final tracks = await _ref.read(
      firestoreCurriculumTrackRepositoryProvider.future,
    );
    final stages = await _ref.read(
      firestoreStageDefinitionRepositoryProvider.future,
    );
    final studyDays = await _ref.read(
      firestoreStudyDayConfigRepositoryProvider.future,
    );
    final scopes = await _ref.read(
      firestoreCurriculumScopeRepositoryProvider.future,
    );
    final programs = await _ref.read(
      firestoreProfileProgramRepositoryProvider.future,
    );
    final goals = await _ref.read(firestoreGoalRepositoryProvider.future);
    if (tracks == null ||
        stages == null ||
        studyDays == null ||
        scopes == null ||
        programs == null ||
        goals == null) {
      throw const AddTrackNotReadyException();
    }

    final curriculumId = plan.curriculumId;
    final now = _clock();
    final program = plan.program;
    // AD-43 / AD-45: on a calendar-program curriculum the calendar sets the
    // pace, so the action ends any goal instead of writing one (a goal
    // there would be rejected by validation).
    final goal = program == null ? plan.goal : null;
    final changes = <GovernedEntityChange>[
      (await tracks.planActivateTrack(curriculumId)).$1,
      ?await stages.planReplaceStages(curriculumId, plan.stages),
      ?await studyDays.planReplaceAll(
        curriculumId: curriculumId,
        studyDays: plan.studyDays,
      ),
      ?await scopes.planSetScopes(
        curriculumId: curriculumId,
        scopes: plan.scopes,
      ),
      if (program == null)
        ?await programs.planRemoveProgram(curriculumId)
      else
        programs.planSetProgram(
          ProfileProgramEntity(
            curriculumId: curriculumId,
            programId: program.programId,
            trackingStartDate: program.trackingStartDate,
            trackingStartRef: program.trackingStartRef,
            updatedAt: now,
          ),
        ),
      ...await goals.planSetGoal(
        goal ??
            GoalEntity(
              curriculumId: curriculumId,
              goalType: 'none',
              createdAt: now,
              updatedAt: now,
            ),
      ),
    ];

    final writer = _ref.read(ownerGovernedWriterProvider);
    final success = await applyOwnerAction(writer, GovernedAction(changes));
    return success.actionId;
  }
}
