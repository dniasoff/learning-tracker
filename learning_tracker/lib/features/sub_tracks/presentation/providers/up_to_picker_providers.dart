/// Riverpod state of the Up to… picker (Story 2.10, DNI-501).
///
/// * [activeSubTracksProvider] — the active learner's complete `sub_tracks`
///   read (live and ended); a read with rejected rows is an error, never
///   the valid rows alone.
/// * [onHomeSubTracksProvider] — those sub-tracks the engine marks
///   `onHome`, in hub order, joined with their [SubTrackState].
/// * [upToSliceProvider] — the rows of one picker ([UpToRequest]), sliced
///   from the engine's [LearnerState] and this device's pending captures.
///
/// The engine output is [activeLearnerStateProvider] (C0 DNI-524, filled by
/// DNI-474). While that is a stub the picker shows its inline error with
/// retry and Record stays disabled (AC-7); nothing is computed here that
/// the engine owns (AD-33).
///
/// Plain Riverpod providers (no codegen), matching the C0 provider style.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_capture_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/on_home_sub_tracks.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/up_to_selection_service.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_capture_providers.dart';

/// What one Up to… picker records.
sealed class UpToRequest {
  const UpToRequest({required this.curriculumId, required this.name});

  /// The curriculum storage key.
  final String curriculumId;

  /// The track name in the title ("School · up to…").
  final String name;

  /// `main` or the sub-track ULID.
  String get source;
}

/// Up to… on a sub-track row: `source` = the sub-track ULID, no `stage`.
final class SubTrackUpToRequest extends UpToRequest {
  /// Creates the request.
  const SubTrackUpToRequest({
    required this.subTrackId,
    required super.curriculumId,
    required super.name,
  });

  /// The sub-track ULID.
  final String subTrackId;

  @override
  String get source => subTrackId;

  @override
  bool operator ==(Object other) =>
      other is SubTrackUpToRequest &&
      other.subTrackId == subTrackId &&
      other.curriculumId == curriculumId &&
      other.name == name;

  @override
  int get hashCode => Object.hash(subTrackId, curriculumId, name);

  @override
  String toString() => 'SubTrackUpToRequest($subTrackId)';
}

/// Up to… on the main-track today list (AC-5): `source = main`, `stage` =
/// the first stage order of today's new-learning tasks.
final class MainTrackUpToRequest extends UpToRequest {
  /// Creates the request.
  MainTrackUpToRequest({
    required super.curriculumId,
    required super.name,
    required List<LeafRef> leadRefs,
    this.stage,
  }) : leadRefs = List.unmodifiable(leadRefs);

  /// Today's new-learning task refs, in task order; they lead the rows.
  final List<LeafRef> leadRefs;

  /// The `stage` written on every event (`firstStageOrder`).
  final int? stage;

  @override
  String get source => LearningEvent.sourceMain;

  @override
  bool operator ==(Object other) =>
      other is MainTrackUpToRequest &&
      other.curriculumId == curriculumId &&
      other.name == name &&
      other.stage == stage &&
      _sameRefs(other.leadRefs, leadRefs);

  @override
  int get hashCode =>
      Object.hash(curriculumId, name, stage, Object.hashAll(leadRefs));

  @override
  String toString() => 'MainTrackUpToRequest($curriculumId)';
}

bool _sameRefs(List<LeafRef> a, List<LeafRef> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Thrown into the picker state when no learner is active, or the engine
/// has no state for the requested curriculum or sub-track.
final class UpToUnavailableException implements Exception {
  /// Creates the exception.
  const UpToUnavailableException(this.reason);

  /// What was missing.
  final String reason;

  @override
  String toString() => 'UpToUnavailableException($reason)';
}

/// A complete `sub_tracks` read holding rows the codec rejected: an error,
/// so no surface treats the valid rows alone as the whole list.
final class SubTrackReadRejectedException implements Exception {
  /// Creates the exception.
  SubTrackReadRejectedException(List<RejectedRow> rejected)
    : rejected = List.unmodifiable(rejected);

  /// The rejected rows.
  final List<RejectedRow> rejected;

  @override
  String toString() => 'SubTrackReadRejectedException(${rejected.length})';
}

/// Every sub-track of the active learner (live and ended), once the
/// complete read is in; empty while no learner or repository is ready.
final activeSubTracksProvider = StreamProvider.autoDispose<List<SubTrack>>((
  ref,
) async* {
  final scope = await ref.watch(activeLearnerScopeProvider.future);
  final repository = await ref.watch(subTrackRepositoryProvider.future);
  if (scope == null || repository == null) {
    yield const <SubTrack>[];
    return;
  }
  await for (final read in repository.watchAll(scope)) {
    switch (read) {
      case CompleteReadLoading<SubTrack>():
        break;
      case CompleteReadReady<SubTrack>(:final items, isClean: true):
        yield items;
      case CompleteReadReady<SubTrack>(:final rejected):
        throw SubTrackReadRejectedException(rejected);
    }
  }
}, retry: (retryCount, error) => null);

/// The active learner's `onHome` sub-tracks in hub order; `[]` with no
/// learner or no sub-track. Loading or an error of either input is
/// forwarded.
final onHomeSubTracksProvider =
    Provider.autoDispose<AsyncValue<List<OnHomeSubTrack>>>((ref) {
      final tracks = ref.watch(activeSubTracksProvider);
      if (tracks case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!tracks.hasValue) return const AsyncLoading();
      final list = tracks.requireValue;
      if (list.isEmpty) return const AsyncData([]);
      final state = ref.watch(activeLearnerStateProvider);
      if (state case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!state.hasValue) return const AsyncLoading();
      final value = state.requireValue;
      if (value == null) return const AsyncData([]);
      return AsyncData(onHomeSubTracks(list, value));
    });

/// The rows of the picker for [UpToRequest], with this device's pending
/// captures read as recorded.
final upToSliceProvider = Provider.autoDispose
    .family<AsyncValue<UpToSlice>, UpToRequest>((ref, request) {
      final state = ref.watch(activeLearnerStateProvider);
      if (state case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!state.hasValue) return const AsyncLoading();
      final learner = state.requireValue;
      if (learner == null) {
        return AsyncError(
          const UpToUnavailableException('no active learner'),
          StackTrace.current,
        );
      }
      final curriculum = learner.curricula[request.curriculumId];
      if (curriculum == null) {
        return AsyncError(
          UpToUnavailableException('no state for ${request.curriculumId}'),
          StackTrace.current,
        );
      }
      final pending = ref.watch(
        pendingCapturesProvider.select(
          (p) => p.refsOf(request.curriculumId, request.source),
        ),
      );
      switch (request) {
        case SubTrackUpToRequest(:final subTrackId):
          final sub = curriculum.subTracks[subTrackId];
          if (sub == null) {
            return AsyncError(
              UpToUnavailableException('no state for sub-track $subTrackId'),
              StackTrace.current,
            );
          }
          return AsyncData(
            subTrackUpToSlice(
              curriculumId: request.curriculumId,
              state: sub,
              pending: pending,
            ),
          );
        case MainTrackUpToRequest(:final leadRefs):
          return AsyncData(
            mainTrackUpToSlice(
              state: curriculum,
              leadRefs: leadRefs,
              pending: pending,
            ),
          );
      }
    });

/// Retries the picker's failed inputs (AC-7): the engine state and the
/// sub-track read; the shared scope only when it is what failed.
void retryUpToInputs(WidgetRef ref) {
  if (ref.read(activeLearnerScopeProvider).hasError) {
    ref.invalidate(activeLearnerScopeProvider);
  }
  ref
    ..invalidate(activeSubTracksProvider)
    ..invalidate(learnerStateProvider);
}
