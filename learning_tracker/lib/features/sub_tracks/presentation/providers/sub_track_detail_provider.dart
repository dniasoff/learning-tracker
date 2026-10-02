/// Riverpod state of the sub-track detail (Story 2.6 / DNI-497, T1).
///
/// [subTrackDetailProvider] joins the selected sub-track's complete read,
/// the learner's complete [LearnerState], its corpus and its counted
/// events, and publishes a [SubTrackDetail] only once every input is
/// complete (`AsyncLoading` until then; the first error wins). It reads
/// the engine's values and never computes position, progress, capacity,
/// shortfall or return itself.
///
/// Plain Riverpod providers (no codegen), matching the DNI-464 / DNI-469
/// provider style.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_detail_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_detail.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_ground_projection.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

/// The detail cannot load: no learner is active, a repository is not
/// ready, or the sub-track is missing or undecodable. Rendered through
/// `AppErrorView` with retry (UX-DR-123).
final class SubTrackDetailUnavailable implements Exception {
  /// Creates the error for [reason].
  const SubTrackDetailUnavailable(this.reason);

  /// Why, for logs only (never shown).
  final String reason;

  @override
  String toString() => 'SubTrackDetailUnavailable($reason)';
}

/// Every sub-track of [LearnerScope] (live and ended) from the complete
/// read; loading until the read is complete, never partial.
final subTrackDetailTracksProvider = StreamProvider.autoDispose
    .family<CompleteReadReady<SubTrack>, LearnerScope>((ref, scope) async* {
      final repository = await ref.watch(subTrackRepositoryProvider.future);
      if (repository == null) {
        throw const SubTrackDetailUnavailable('sub_track_repository');
      }
      yield* repository
          .watchAll(scope)
          .where((r) => r is CompleteReadReady<SubTrack>)
          .cast<CompleteReadReady<SubTrack>>();
    }, retry: (retryCount, error) => null);

/// Every learning event of [LearnerScope] from the complete read (for the
/// learnt-at source labels); loading until complete.
final subTrackDetailEventsProvider = StreamProvider.autoDispose
    .family<List<LearningEvent>, LearnerScope>((ref, scope) async* {
      final repository = await ref.watch(
        learningEventRepositoryProvider.future,
      );
      if (repository == null) {
        throw const SubTrackDetailUnavailable('learning_event_repository');
      }
      yield* repository
          .watchAll(scope)
          .where((r) => r is CompleteReadReady<LearningEvent>)
          .map((r) => (r as CompleteReadReady<LearningEvent>).items);
    }, retry: (retryCount, error) => null);

/// The viewer role of the detail.
///
/// A tutored session is [SubTrackDetailRole.tutor]. A child-mode profile is
/// [SubTrackDetailRole.child] unless its parent PIN is verified this
/// session (the same rule as the session actor, AD-46). While the profile
/// is loading the role is child, the most limited one (fail closed);
/// `LearningCommands` enforces the real limits whatever this returns.
final subTrackDetailRoleProvider = Provider.autoDispose<SubTrackDetailRole>((
  ref,
) {
  if (ref.watch(activeTutoredProfileSelectionProvider) != null) {
    return SubTrackDetailRole.tutor;
  }
  final profile = ref.watch(activeProfileProvider);
  if (!profile.hasValue) return SubTrackDetailRole.child;
  final active = profile.value;
  if (active == null || active.mode != ProfileMode.child) {
    return SubTrackDetailRole.parent;
  }
  return ref.watch(parentPinAuthenticatedProfileIdProvider) == active.profileId
      ? SubTrackDetailRole.parent
      : SubTrackDetailRole.child;
});

/// The order the detail renders instead of the stored `ground` while a
/// reorder or removal of sub-track `id` is in flight (optimistic, AC-5);
/// null when nothing is pending. Story 2.6 T5 fills it.
final subTrackGroundOverrideProvider = Provider.autoDispose
    .family<List<NodeEntry>?, String>((ref, id) => null);

/// The [SubTrackDetail] of sub-track `id` for the active learner.
final subTrackDetailProvider = Provider.autoDispose
    .family<AsyncValue<SubTrackDetail>, String>((ref, id) {
      final scope = ref.watch(activeLearnerScopeProvider);
      if (scope case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!scope.hasValue) return const AsyncLoading();
      final active = scope.requireValue;
      if (active == null) {
        return AsyncError(
          const SubTrackDetailUnavailable('no_active_learner'),
          StackTrace.current,
        );
      }

      final tracks = ref.watch(subTrackDetailTracksProvider(active));
      final events = ref.watch(subTrackDetailEventsProvider(active));
      final state = ref.watch(learnerStateProvider(active));
      final corpora = ref.watch(corporaProvider);
      for (final input in <AsyncValue<Object?>>[
        tracks,
        events,
        state,
        corpora,
      ]) {
        if (input case AsyncError(:final error, :final stackTrace)) {
          return AsyncError(error, stackTrace);
        }
      }
      if (!tracks.hasValue ||
          !events.hasValue ||
          !state.hasValue ||
          !corpora.hasValue) {
        return const AsyncLoading();
      }

      final read = tracks.requireValue;
      if (read.rejected.any((r) => r.docId == id)) {
        return AsyncError(
          const SubTrackDetailUnavailable('undecodable_sub_track'),
          StackTrace.current,
        );
      }
      final track = read.items.where((t) => t.id == id).firstOrNull;
      if (track == null) {
        return AsyncError(
          const SubTrackDetailUnavailable('sub_track_not_found'),
          StackTrace.current,
        );
      }
      final learner = state.requireValue;
      final curriculum = learner[track.curriculumId];
      final corpus = corpora.requireValue[track.curriculumId];
      final engine = curriculum?.subTracks[id];
      if (curriculum == null || corpus == null || engine == null) {
        return AsyncError(
          const SubTrackDetailUnavailable('curriculum_not_evaluated'),
          StackTrace.current,
        );
      }

      return AsyncData(
        SubTrackDetail(
          track: track,
          state: engine,
          role: ref.watch(subTrackDetailRoleProvider),
          ground: SubTrackGroundProjection.project(
            track: track,
            ground:
                ref.watch(subTrackGroundOverrideProvider(id)) ?? track.ground,
            corpus: corpus,
            learntLeaves: curriculum.learntLeaves,
            countedLearns: _countedLearns(
              events.requireValue,
              learner,
              track.curriculumId,
            ),
            subTracks: read.items,
            holdsGround: (other) =>
                curriculum.subTracks[other]?.holdsGround ?? false,
          ),
        ),
      );
    });

/// The counted `learn` events of [curriculumId] (engine verdict:
/// `LearnerState.countedEventIds`).
List<LearningEvent> _countedLearns(
  List<LearningEvent> events,
  LearnerState state,
  String curriculumId,
) => [
  for (final e in events)
    if (e.isLearn &&
        e.curriculumId == curriculumId &&
        state.countedEventIds.contains(e.id))
      e,
];

/// Retries a failed detail load (UX-DR-123): re-subscribes every complete
/// read the detail joins for the active learner.
void retrySubTrackDetail(WidgetRef ref) {
  final scope = ref.read(activeLearnerScopeProvider);
  if (scope.hasError) {
    ref.invalidate(activeLearnerScopeProvider);
    return;
  }
  final active = scope.value;
  if (active == null) return;
  ref
    ..invalidate(subTrackDetailTracksProvider(active))
    ..invalidate(subTrackDetailEventsProvider(active))
    ..invalidate(learnerStateProvider(active));
  if (ref.read(corporaProvider).hasError) ref.invalidate(corporaProvider);
}

/// The rendered label of a ground entry or position [sefariaRef]: the
/// ContentIndex breadcrumb with its leading top-level segment dropped (the
/// rule the main-track task card and the Learn-tab sub-track row use),
/// falling back to the raw ref while the label loads.
final subTrackRefLabelProvider = Provider.autoDispose.family<String, String>((
  ref,
  sefariaRef,
) {
  final rendered = ref
      .watch(renderedDisplayForRefProvider(sefariaRef))
      .asData
      ?.value;
  if (rendered == null) return sefariaRef.replaceAll('_', ' ');
  const separator = ' › ';
  final cut = rendered.indexOf(separator);
  return cut == -1 ? rendered : rendered.substring(cut + separator.length);
});

/// The node's own ContentIndex name (e.g. "משנה א") for a row nested under
/// an entry, falling back to the raw ref while it loads.
final subTrackNodeNameProvider = Provider.autoDispose.family<String, String>(
  (ref, sefariaRef) =>
      ref.watch(renderedLeafForRefProvider(sefariaRef)).asData?.value ??
      sefariaRef.replaceAll('_', ' '),
);
