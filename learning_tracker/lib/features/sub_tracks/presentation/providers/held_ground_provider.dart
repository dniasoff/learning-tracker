/// The main track's held ground (Story 2.7 / DNI-498 AC-6, UX-DR-63,
/// UX-DR-93): which leaves of a curriculum a `holdsGround` sub-track holds,
/// and by whom, for the main-track browse view to grey and tag them.
///
/// Read-only and derived: the engine (`LearnerState`) decides who holds;
/// nothing here schedules or reconciles. A view that cannot resolve it
/// (no learner, no sub-track, the C0 seams not ready) treats every leaf as
/// unheld rather than failing.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/ground_picker_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ground_selection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ground_picker_provider.dart';

/// The holder names of each held leaf of [curriculumId] for the active
/// learner; empty when no non-ended sub-track of it exists.
final mainTrackHeldGroundProvider = FutureProvider.autoDispose
    .family<Map<LeafRef, List<String>>, String>((ref, curriculumId) async {
      final scope = await ref.watch(activeLearnerScopeProvider.future);
      if (scope == null) return const {};
      final tracks = await ref.watch(
        groundPickerSubTracksProvider(scope).future,
      );
      if (!tracks.any((t) => t.curriculumId == curriculumId && !t.isEnded)) {
        return const {};
      }
      final corpus = (await ref.watch(corporaProvider.future))[curriculumId];
      if (corpus == null) return const {};
      final state = await ref.watch(learnerStateProvider(scope).future);
      final curriculumState = state[curriculumId];
      return heldLeafNames(
        groundHolders(
          tracks,
          curriculumId: curriculumId,
          holds: (t) =>
              curriculumState?.subTracks[t.id]?.holdsGround ?? !t.isEnded,
        ),
        corpus,
      );
    }, retry: (retryCount, error) => null);
