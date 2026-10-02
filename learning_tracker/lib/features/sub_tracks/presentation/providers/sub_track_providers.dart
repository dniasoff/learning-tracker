/// Riverpod access to the Learn-tab / Dashboard sub-track projection
/// (Story 2.9, DNI-500).
///
/// One projection feeds both surfaces: [homeSubTracksProvider] joins the
/// active learner's complete `sub_tracks` read with the engine's
/// [LearnerState] (AD-35) through [projectHomeSubTracks]. Widgets render it
/// and never recompute a position, a count or a fill.
///
/// Production wiring: [learnerStateProvider] is the C0 (DNI-524) seam that
/// DNI-474 fills. Until it does, a learner with sub-tracks gets the
/// section's `InlineAsyncError` (AC-6); the main tasks are unaffected.
/// DNI-500 adds no parallel data source (story open assumption). The stub
/// cannot ship: DNI-490 removes every `c0Stub` call before the cutover
/// release (`tool/retired_symbols/R15.json`). The no-override integration
/// test follows in bead learning-tracker-fyh.135.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';

/// Every sub-track of [LearnerScope] (live and tombstoned) once the complete
/// read is in; loading until then, never partial (AD-54). Empty while no
/// account is ready (the repository provider is null).
final subTracksForScopeProvider = StreamProvider.autoDispose
    .family<List<SubTrack>, LearnerScope>((ref, scope) async* {
      final repository = await ref.watch(subTrackRepositoryProvider.future);
      if (repository == null) {
        yield const <SubTrack>[];
        return;
      }
      await for (final read in repository.watchAll(scope)) {
        if (read case CompleteReadReady<SubTrack>(:final items)) yield items;
      }
    }, retry: (retryCount, error) => null);

/// The active learner's `onHome` sub-tracks in hub order (AC-1, AC-8).
///
/// * `AsyncData([])` while no learner is active, or when the learner has no
///   sub-track at all (the engine is not consulted, so the section is simply
///   absent).
/// * Loading while either input is still loading; the caller keeps that
///   local to its own section (AC-6).
/// * An error from either input is forwarded, for the section's
///   `InlineAsyncError` + retry ([retryHomeSubTracks]).
final homeSubTracksProvider =
    Provider.autoDispose<AsyncValue<List<SubTrackHomeItem>>>((ref) {
      final scopeAsync = ref.watch(activeLearnerScopeProvider);
      if (scopeAsync case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!scopeAsync.hasValue) return const AsyncLoading();
      final scope = scopeAsync.requireValue;
      if (scope == null) return const AsyncData([]);

      final tracksAsync = ref.watch(subTracksForScopeProvider(scope));
      if (tracksAsync case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!tracksAsync.hasValue) return const AsyncLoading();
      final tracks = tracksAsync.requireValue;
      if (tracks.isEmpty) return const AsyncData([]);

      final stateAsync = ref.watch(learnerStateProvider(scope));
      if (stateAsync case AsyncError(:final error, :final stackTrace)) {
        return AsyncError(error, stackTrace);
      }
      if (!stateAsync.hasValue) return const AsyncLoading();
      return AsyncData(
        projectHomeSubTracks(
          subTracks: tracks,
          learnerState: stateAsync.requireValue,
        ),
      );
    });

/// Retries the failed inputs of [homeSubTracksProvider] (the section's
/// retry action, AC-6). The shared scope is re-resolved only when it is the
/// input that failed, so a sub-track retry never churns the rest of the app.
void retryHomeSubTracks(WidgetRef ref) {
  if (ref.read(activeLearnerScopeProvider).hasError) {
    ref.invalidate(activeLearnerScopeProvider);
  }
  ref
    ..invalidate(subTracksForScopeProvider)
    ..invalidate(learnerStateProvider);
}
