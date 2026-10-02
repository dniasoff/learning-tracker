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

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_for_scope_provider.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
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
/// null when nothing is pending.
final subTrackGroundOverrideProvider = Provider.autoDispose
    .family<List<NodeEntry>?, String>(
      (ref, id) => ref.watch(subTrackGroundEditorProvider(id)).pending,
    );

/// A queued (offline) ground edit the server later refused for good
/// (UX-DR-124): the order it sent and the last confirmed order before it.
final class SubTrackGroundRollback {
  /// Creates the rollback of [rejected] to [prior].
  const SubTrackGroundRollback({
    required this.rejected,
    required this.prior,
    required this.removal,
  });

  /// The order the refused edit wrote.
  final List<NodeEntry> rejected;

  /// The last confirmed order before it.
  final List<NodeEntry> prior;

  /// Whether the refused edit was a removal (else a reorder).
  final bool removal;
}

/// The state of [SubTrackGroundEditor].
final class SubTrackGroundEditState {
  /// Creates the state.
  const SubTrackGroundEditState({
    this.pending,
    this.rollback,
    this.lateRejections = 0,
  });

  /// The optimistic order of the edit in flight, or null.
  final List<NodeEntry>? pending;

  /// The latest queued edit the server refused after it was accepted
  /// locally, or null.
  final SubTrackGroundRollback? rollback;

  /// How many queued edits the server refused after they were accepted
  /// locally; the detail shows a rollback snackbar each time it grows.
  final int lateRejections;

  /// Whether an edit is in flight.
  bool get busy => pending != null;

  /// The order to render over the [stored] ground: the pending order;
  /// else, while the store still shows a refused edit's order (a cache
  /// that has not reverted it yet), the last confirmed order before it;
  /// else [stored].
  List<NodeEntry> groundOver(List<NodeEntry> stored) {
    final p = pending;
    if (p != null) return p;
    final r = rollback;
    if (r != null && _sameOrder(stored, r.rejected)) return r.prior;
    return stored;
  }

  static bool _sameOrder(List<NodeEntry> a, List<NodeEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Commits whole-`ground` edits of one sub-track (AC-5, AC-6).
///
/// [SubTrackGroundEditor.commit] shows the new order at once (the pending
/// order), sends the WHOLE new list through `LearningCommands.editSubTrack`
/// (one governed `subTrack` change and one `change_log` entry; learning
/// events untouched), then clears the pending order: on success the
/// stored ground (already applied to the local cache) takes over and the
/// engine recomputes position, held ground, forecast and today's tasks; on
/// rejection the last confirmed order is back. An edit queued offline is
/// tracked by its change id: when `LearningCommands.watchPendingFailures`
/// later reports it refused for good, the last confirmed order is shown
/// again and [SubTrackGroundEditState.lateRejections] grows (the detail's
/// rollback snackbar). No widget writes Firestore.
final subTrackGroundEditorProvider = NotifierProvider.autoDispose
    .family<SubTrackGroundEditor, SubTrackGroundEditState, String>(
      SubTrackGroundEditor.new,
    );

/// See [subTrackGroundEditorProvider].
class SubTrackGroundEditor extends Notifier<SubTrackGroundEditState> {
  /// Creates the editor of sub-track [subTrackId].
  SubTrackGroundEditor(this.subTrackId);

  /// The sub-track ULID.
  final String subTrackId;

  /// Queued edits awaiting the server, by change-log entry id.
  final Map<String, SubTrackGroundRollback> _queued = {};

  StreamSubscription<List<PendingFailure>>? _failures;

  @override
  SubTrackGroundEditState build() {
    ref.onDispose(() => unawaited(_failures?.cancel()));
    return const SubTrackGroundEditState();
  }

  /// Whether an edit is in flight.
  bool get busy => state.busy;

  /// Replaces the ground [prior] (the order shown, the last confirmed one)
  /// with [next]; [removal] names the edit for the late-rejection
  /// snackbar. Returns whether it was accepted (saved, or queued offline);
  /// false means it was rejected and rolled back.
  Future<bool> commit(
    List<NodeEntry> next, {
    required List<NodeEntry> prior,
    bool removal = false,
  }) async {
    if (busy) return false;
    final sent = List<NodeEntry>.unmodifiable(next);
    state = SubTrackGroundEditState(
      pending: sent,
      rollback: state.rollback,
      lateRejections: state.lateRejections,
    );
    CaptureResult? result;
    LearningCommands? commands;
    try {
      commands = await ref.read(learningCommandsProvider.future);
      if (commands != null) {
        result = await commands.editSubTrack(
          subTrackId,
          SubTrackEdit(ground: sent),
        );
      }
    } on Object {
      result = null;
    }
    if (!ref.mounted) return result is CaptureSuccess;
    final accepted = result is CaptureSuccess;
    if (result is CaptureSuccess && result.queued && commands != null) {
      final rollback = SubTrackGroundRollback(
        rejected: sent,
        prior: List.unmodifiable(prior),
        removal: removal,
      );
      for (final id in result.changeIds) {
        _queued[id] = rollback;
      }
      _watchFailures(commands);
    }
    state = SubTrackGroundEditState(
      // A newer accepted edit supersedes an earlier rollback.
      rollback: accepted ? null : state.rollback,
      lateRejections: state.lateRejections,
    );
    return accepted;
  }

  void _watchFailures(LearningCommands commands) {
    if (_failures != null) return;
    try {
      _failures = commands.watchPendingFailures().listen(
        _onPendingFailures,
        onError: (Object _) {},
      );
    } on Object {
      // No pending-failure feed: the store's own revert still restores
      // the confirmed order.
    }
  }

  void _onPendingFailures(List<PendingFailure> failures) {
    if (!ref.mounted || _queued.isEmpty) return;
    SubTrackGroundRollback? latest;
    var count = 0;
    for (final failure in failures) {
      for (final id in failure.changeIds) {
        final rollback = _queued.remove(id);
        if (rollback == null) continue;
        latest = rollback;
        count++;
      }
    }
    if (latest == null) return;
    state = SubTrackGroundEditState(
      pending: state.pending,
      rollback: latest,
      lateRejections: state.lateRejections + count,
    );
  }
}

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

      // A tutored session reads another owner's learner, so it goes through
      // the grant-gated read path (DNI-523, ruling B10), watched FIRST: until
      // an active grant authorizes the tutor, and as soon as it is revoked or
      // a read is permission-denied, the detail is a fresh error (or
      // loading) with no value, and the sub-track and event reads are not
      // watched at all, so their cached rows are disposed and never
      // rendered.
      final AsyncValue<LearnerState> state;
      if (ref.watch(activeTutoredProfileSelectionProvider) != null) {
        state = ref.watch(learnerStateForScopeProvider(active));
        if (state case AsyncError(:final error, :final stackTrace)) {
          return AsyncError(error, stackTrace);
        }
        if (!state.hasValue) return const AsyncLoading();
      } else {
        state = ref.watch(learnerStateProvider(active));
      }
      final tracks = ref.watch(subTrackDetailTracksProvider(active));
      final events = ref.watch(subTrackDetailEventsProvider(active));
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
          noDeadline: curriculum.dailyTarget == null,
          ground: SubTrackGroundProjection.project(
            track: track,
            ground:
                ref.watch(subTrackGroundOverrideProvider(id)) ??
                ref
                    .watch(subTrackGroundEditorProvider(id))
                    .groundOver(track.ground),
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
  if (ref.read(activeTutoredProfileSelectionProvider) != null) {
    ref.invalidate(tutorScopeGrantProvider(active));
  }
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
