import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/domain/models/calendar_position.dart';
import 'package:learning_tracker/features/dashboard/domain/models/chazara_status.dart';
import 'package:learning_tracker/features/dashboard/domain/models/momentum_status.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

part 'track_progress.freezed.dart';

/// Determines which card variant the UI renders for a track.
///
/// Selection logic (from permutation matrix in redesign analysis):
///   programId != null          --> programCalendar (P1-P4)
///   goalType == 'deadline'     --> deadlineGoal (S1)
///   goalType == 'pace'         --> velocityGoal (S2, S5)
///   otherwise                  --> momentum (S3, S4)
enum TrackProgressVariant {
  programCalendar,
  deadlineGoal,
  velocityGoal,
  momentum,
}

/// Resolves the correct [TrackProgressVariant] from track properties.
///
/// Program tracks always get [TrackProgressVariant.programCalendar],
/// regardless of any goal settings. Self-paced tracks are routed by
/// their [goalType].
///
/// See: docs/dashboard-progress-redesign-analysis.md "The Permutation Matrix"
TrackProgressVariant resolveVariant({
  required int? programId,
  required String? goalType,
}) {
  if (programId != null) return TrackProgressVariant.programCalendar;
  if (goalType == 'deadline') return TrackProgressVariant.deadlineGoal;
  if (goalType == 'pace') return TrackProgressVariant.velocityGoal;
  return TrackProgressVariant.momentum;
}

/// Unified progress model for a single track.
///
/// The [variant] field determines which optional fields are populated:
///   - [programCalendar]: [calendarPos] is non-null
///   - [deadlineGoal]: [paceStatus] is non-null, [scopePercentage] is non-null
///   - [velocityGoal]: [paceStatus] is non-null, [scopePercentage] is non-null
///   - [momentum]: [momentum] field is non-null, [scopePercentage] is non-null
///
/// [chazaraStatus] is populated for any variant when chazara is configured.
@freezed
abstract class TrackProgress with _$TrackProgress {
  const factory TrackProgress({
    required int trackId,
    required String trackLabel,
    required CurriculumId curriculumId,
    required TrackProgressVariant variant,
    double? scopePercentage,
    required int completedItems,
    required int totalItems,
    PaceStatus? paceStatus,
    CalendarPosition? calendarPos,
    MomentumStatus? momentum,
    ChazaraStatus? chazaraStatus,
    required int tasksToday,
  }) = _TrackProgress;
}
