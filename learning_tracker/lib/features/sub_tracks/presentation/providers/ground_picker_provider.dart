/// Riverpod access to the ground picker (Story 2.7 / DNI-498): its inputs
/// (the sub-track, the curriculum's ContentIndex corpus, the learner state
/// and every other holding sub-track) and the parent's pending draft.
///
/// Built against the C0 (DNI-524) seams — `corporaProvider`,
/// `learnerStateProvider`, `learningCommandsProvider` — never a parallel
/// source (ruling B4). Plain Riverpod providers (no codegen), matching the
/// DNI-464 provider style.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/ground_picker_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ground_selection.dart';

/// Why the picker cannot be used (AC-7, AC-8): it then shows no editable
/// control at all, whichever entry point or deep link reached it.
enum GroundPickerBlock {
  /// Not a parent session: a child without the parent PIN, a tutored
  /// session, or no active profile (FR-10, FR-11; ground is read-only).
  notParent,

  /// No active learner, or no sub-track with this id for it.
  notFound,

  /// The sub-track has ended or been deleted.
  ended,

  /// The curriculum's main track follows a calendar program, where
  /// sub-tracks cannot exist (AD-45, `prd-deviations` #12).
  calendarProgram,
}

/// The picker's access decision for one sub-track.
sealed class GroundPickerAccess {
  const GroundPickerAccess();
}

/// The picker is usable with [inputs].
final class GroundPickerReady extends GroundPickerAccess {
  /// Creates the decision.
  const GroundPickerReady(this.inputs);

  /// The picker's inputs.
  final GroundPickerInputs inputs;
}

/// The picker is blocked for [reason].
final class GroundPickerUnavailable extends GroundPickerAccess {
  /// Creates the decision.
  const GroundPickerUnavailable(this.reason);

  /// Why.
  final GroundPickerBlock reason;
}

/// Everything the picker draws from.
final class GroundPickerInputs {
  /// Creates the inputs.
  GroundPickerInputs({
    required this.scope,
    required this.track,
    required this.model,
    required this.curriculum,
    required this.index,
  });

  /// The learner.
  final LearnerScope scope;

  /// The sub-track receiving ground.
  final SubTrack track;

  /// The pure picker model (corpus, own ground, learnt, held).
  final GroundPickerModel model;

  /// The curriculum, when the app knows it (labels and level names).
  final CurriculumId? curriculum;

  /// ContentIndex lookups for display names.
  final ContentIndex index;
}

/// The learner's complete sub-track read (live and ended), as it changes.
final groundPickerSubTracksProvider = StreamProvider.autoDispose
    .family<List<SubTrack>, LearnerScope>((ref, scope) async* {
      final repo = await ref.watch(subTrackRepositoryProvider.future);
      if (repo == null) {
        throw StateError('ground picker: sub-track repository unavailable');
      }
      yield* repo
          .watchAll(scope)
          .where((read) => read is CompleteReadReady<SubTrack>)
          .map((read) => (read as CompleteReadReady<SubTrack>).items);
    }, retry: (retryCount, error) => null);

/// Whether the main track of a curriculum follows a live calendar program
/// (AD-45), from the learner's governed intent.
final groundPickerCalendarProgramProvider = StreamProvider.autoDispose
    .family<bool, ({LearnerScope scope, String curriculumId})>((
      ref,
      key,
    ) async* {
      final intent = await ref.watch(governedIntentRepositoryProvider.future);
      if (intent == null) {
        throw StateError('ground picker: governed intent unavailable');
      }
      yield* intent.watch(key.scope).map((i) {
        final program = i.mainTracks[key.curriculumId]?.program;
        return program != null && program.endedAt == null;
      });
    }, retry: (retryCount, error) => null);

/// The access decision and inputs of the picker for sub-track
/// [subTrackId] of the active learner. Recomputes whenever the session,
/// the sub-tracks, the learner state or the corpus changes, so a confirmed
/// assignment shows on the same screen without special-casing.
///
/// Loading failures surface as errors (shown with `AppErrorView` and a
/// retry, UX-DR-126); access refusals are [GroundPickerUnavailable].
final groundPickerAccessProvider = FutureProvider.autoDispose
    .family<GroundPickerAccess, String>((ref, subTrackId) async {
      final parent = await ref.watch(parentSessionProvider.future);
      if (!parent)
        return const GroundPickerUnavailable(GroundPickerBlock.notParent);
      final scope = await ref.watch(activeLearnerScopeProvider.future);
      if (scope == null) {
        return const GroundPickerUnavailable(GroundPickerBlock.notFound);
      }
      final tracks = await ref.watch(
        groundPickerSubTracksProvider(scope).future,
      );
      final track = tracks.where((t) => t.id == subTrackId).firstOrNull;
      if (track == null) {
        return const GroundPickerUnavailable(GroundPickerBlock.notFound);
      }
      if (track.isEnded) {
        return const GroundPickerUnavailable(GroundPickerBlock.ended);
      }
      final calendar = await ref.watch(
        groundPickerCalendarProgramProvider((
          scope: scope,
          curriculumId: track.curriculumId,
        )).future,
      );
      if (calendar) {
        return const GroundPickerUnavailable(GroundPickerBlock.calendarProgram);
      }
      final corpora = await ref.watch(corporaProvider.future);
      final corpus = corpora[track.curriculumId];
      if (corpus == null) {
        throw StateError('ground picker: no corpus for ${track.curriculumId}');
      }
      final state = await ref.watch(learnerStateProvider(scope).future);
      final curriculumState = state[track.curriculumId];
      final index = await ref.watch(contentIndexProvider.future);
      final holders = groundHolders(
        tracks,
        curriculumId: track.curriculumId,
        exceptId: track.id,
        holds: engineHoldsGround(curriculumState),
      );
      return GroundPickerReady(
        GroundPickerInputs(
          scope: scope,
          track: track,
          curriculum: CurriculumId.fromStorageKey(track.curriculumId),
          index: index,
          model: GroundPickerModel(
            corpus: corpus,
            ownGround: track.ground,
            learnt: curriculumState?.learntLeaves ?? const {},
            held: heldLeafNames(holders, corpus),
          ),
        ),
      );
    }, retry: (retryCount, error) => null);

/// The picker's pending view state for one sub-track: the parent's
/// [picks], the search [query], the *Available only* filter, the expanded
/// nodes, and the ground an in-flight confirm shows optimistically.
final class GroundPickerUiState {
  /// Creates the state.
  const GroundPickerUiState({
    this.picks = const {},
    this.query = '',
    this.availableOnly = false,
    this.expanded = const {},
    this.submitting = false,
    this.optimisticGround,
  });

  /// The parent's pending picks (see `GroundDraft`).
  final Set<NodeEntry> picks;

  /// The search text.
  final String query;

  /// The *Available only* view filter (UX-DR-125).
  final bool availableOnly;

  /// Expanded tree nodes.
  final Set<NodeEntry> expanded;

  /// A confirm is in flight.
  final bool submitting;

  /// The ground shown while a confirm is in flight; null otherwise. A
  /// rejection drops it again (UX-DR-127).
  final List<NodeEntry>? optimisticGround;

  /// A copy with the given fields replaced.
  GroundPickerUiState copyWith({
    Set<NodeEntry>? picks,
    String? query,
    bool? availableOnly,
    Set<NodeEntry>? expanded,
    bool? submitting,
    List<NodeEntry>? optimisticGround,
    bool clearOptimistic = false,
  }) => GroundPickerUiState(
    picks: picks ?? this.picks,
    query: query ?? this.query,
    availableOnly: availableOnly ?? this.availableOnly,
    expanded: expanded ?? this.expanded,
    submitting: submitting ?? this.submitting,
    optimisticGround: clearOptimistic
        ? null
        : optimisticGround ?? this.optimisticGround,
  );
}

/// The pending state of the picker for a sub-track id. Kept per sub-track
/// while a picker is open, so a phone/tablet layout change keeps the
/// selection; *Reset changes* clears only [GroundPickerUiState.picks].
final class GroundPickerController extends Notifier<GroundPickerUiState> {
  /// Creates the controller for sub-track [subTrackId].
  GroundPickerController(this.subTrackId);

  /// The sub-track.
  final String subTrackId;

  @override
  GroundPickerUiState build() => const GroundPickerUiState();

  /// Replaces the picks (a `GroundDraft` edit).
  void setPicks(Set<NodeEntry> picks) =>
      state = state.copyWith(picks: Set.unmodifiable(picks));

  /// *Reset changes*: clears only the pending picks (AC-3).
  void reset() => state = state.copyWith(picks: const {});

  /// Sets the search text.
  void setQuery(String query) => state = state.copyWith(query: query);

  /// Sets *Available only*.
  void setAvailableOnly(bool value) =>
      state = state.copyWith(availableOnly: value);

  /// Expands or collapses [node].
  void toggleExpanded(NodeEntry node) {
    final next = {...state.expanded};
    if (!next.remove(node)) next.add(node);
    state = state.copyWith(expanded: Set.unmodifiable(next));
  }

  /// A confirm started: the [ground] it will write shows at once.
  void submitting(List<NodeEntry> ground) => state = state.copyWith(
    submitting: true,
    optimisticGround: List.unmodifiable(ground),
  );

  /// The confirm was accepted: the draft is done.
  void accepted() => state = state.copyWith(
    picks: const {},
    submitting: false,
    clearOptimistic: true,
  );

  /// The confirm was refused: the optimistic ground is dropped and the
  /// picks are kept for another try.
  void rejected() =>
      state = state.copyWith(submitting: false, clearOptimistic: true);
}

/// The [GroundPickerController] of a sub-track id.
final groundPickerControllerProvider = NotifierProvider.autoDispose
    .family<GroundPickerController, GroundPickerUiState, String>(
      GroundPickerController.new,
    );
