/// The sub-track lifecycle's reads (Story 2.8 / DNI-499, T4): the active
/// learner's sub-tracks split into active and ended on the learner's civil
/// today (AD-41), the viewer's role and the curriculum deadline that bounds
/// the academic-year picker.
///
/// Read-only: every lifecycle write goes through `LearningCommands`
/// (`createSubTrack` / `endSubTrack` / `deleteSubTrack`); a passed window
/// is ended here by derivation, never by a write (AD-33, AC-6).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_lifecycle_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_lifecycle.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// Every sub-track of the active learner, live and ended, from the
/// complete read (loading until it is complete, never partial). Empty
/// while no learner is active or the sub-track repository is not ready.
/// A read failure is an error, never an empty list; so is a complete read
/// with undecodable rows ([SubTrackReadRejectedException], AD-35).
final subTrackLifecycleTracksProvider =
    StreamProvider.autoDispose<List<SubTrack>>((ref) async* {
      final scope = await ref.watch(activeLearnerScopeProvider.future);
      final repository = await ref.watch(subTrackRepositoryProvider.future);
      if (scope == null || repository == null) {
        yield const [];
        return;
      }
      yield* repository
          .watchAll(scope)
          .where((read) => read is CompleteReadReady<SubTrack>)
          .map((read) {
            final ready = read as CompleteReadReady<SubTrack>;
            if (!ready.isClean) {
              throw SubTrackReadRejectedException(ready.rejected.length);
            }
            return ready.items;
          });
    });

/// The learner's civil today (AD-41): the current instant in the
/// `time_zone` in force per the learner's settings history, or the UTC date
/// while that history has not loaded (the AD-41 fallback; never the device
/// offset). Recomputed whenever a reader rebuilds, so a window that passes
/// at the learner's midnight moves its sub-track to Ended with no write.
final subTrackLifecycleTodayProvider = Provider.autoDispose<CivilDate>((ref) {
  final nowUtc = ref.watch(localDayClockProvider).nowUtc().toUtc();
  final scope = ref.watch(activeLearnerScopeProvider).value;
  final history = scope == null
      ? null
      : ref.watch(learnerLockSettingsProvider(scope)).value;
  return history == null
      ? formatCivilDay(DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day))
      : civilDate(nowUtc, history);
});

/// The active learner's sub-tracks split into the hub's active and ended
/// groups on [subTrackLifecycleTodayProvider] (AC-5, AC-6).
final subTrackLifecycleGroupsProvider =
    Provider.autoDispose<AsyncValue<SubTrackLifecycleGroups>>((ref) {
      final today = ref.watch(subTrackLifecycleTodayProvider);
      return ref
          .watch(subTrackLifecycleTracksProvider)
          .whenData((tracks) => groupSubTracksByLifecycle(tracks, today));
    });

/// The live deadline (`target_date`) of [curriculumId], or null without
/// one. It bounds the academic-year picker, and so *Add next year* (AC-2).
final subTrackCurriculumDeadlineProvider = StreamProvider.autoDispose
    .family<CivilDate?, String>((ref, curriculumId) async* {
      final scope = await ref.watch(activeLearnerScopeProvider.future);
      final intent = await ref.watch(governedIntentRepositoryProvider.future);
      if (scope == null || intent == null) {
        yield null;
        return;
      }
      yield* intent.watch(scope).map((learner) {
        final deadline = learner.goals[curriculumId]?.deadline;
        return deadline == null || deadline.endedAt != null
            ? null
            : deadline.targetDate;
      });
    });

/// Who is looking at the lifecycle surfaces.
enum SubTrackLifecycleViewer {
  /// The parent (or an adult learner): Add next year, End and Delete.
  parent,

  /// A child without a verified parent PIN, or a tutored session (tutor
  /// sub-track writes arrive in Epic 4): no lifecycle actions.
  readOnly,
}

/// The viewer of the active learner's sub-tracks. Fails closed: read-only
/// until the active profile is known. The commands enforce the same rule
/// (`CaptureResult.childLimit`).
final subTrackLifecycleViewerProvider =
    Provider.autoDispose<SubTrackLifecycleViewer>((ref) {
      if (ref.watch(activeTutoredProfileSelectionProvider) != null) {
        return SubTrackLifecycleViewer.readOnly;
      }
      final profile = ref.watch(activeProfileProvider).value;
      if (profile == null) return SubTrackLifecycleViewer.readOnly;
      final child =
          profile.mode == ProfileMode.child &&
          ref.watch(parentPinAuthenticatedProfileIdProvider) !=
              profile.profileId;
      return child
          ? SubTrackLifecycleViewer.readOnly
          : SubTrackLifecycleViewer.parent;
    });
