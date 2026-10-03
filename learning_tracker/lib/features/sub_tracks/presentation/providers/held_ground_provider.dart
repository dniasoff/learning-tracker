/// The main track's held ground (Story 2.7 / DNI-498 AC-6, UX-DR-63,
/// UX-DR-93): which leaves of a curriculum a `holdsGround` sub-track holds,
/// and by whom, for the main-track browse view to grey and tag them.
///
/// Read-only and derived: the engine (`LearnerState`) decides who holds;
/// nothing here schedules or reconciles. A view that cannot resolve it
/// (no learner, no sub-track, the C0 seams not ready) treats every leaf as
/// unheld rather than failing.
///
/// A tutored session reads another owner's learner, so it is gated on the
/// grant-checked read path (DNI-523, ruling B10) first: until an active
/// grant authorizes the tutor, and as soon as it is revoked or a read is
/// permission-denied, the held ground is a fresh loading or error with no
/// value, and the sub-track, corpus and learner-state reads behind it are
/// not watched, so their cached holders are disposed and never shown.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_for_scope_provider.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/ground_picker_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ground_selection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/ground_picker_provider.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

/// The holder names of each held leaf of [curriculumId] for the active
/// learner; empty when no non-ended sub-track of it exists.
///
/// In a tutored session the grant-gated read is watched first; a missing,
/// inactive or revoked grant is an error (or loading) with no previous
/// value. See the library doc.
final mainTrackHeldGroundProvider = Provider.autoDispose
    .family<AsyncValue<Map<LeafRef, List<String>>>, String>((
      ref,
      curriculumId,
    ) {
      if (ref.watch(activeTutoredProfileSelectionProvider) != null) {
        final scope = ref.watch(activeLearnerScopeProvider);
        if (scope case AsyncError(:final error, :final stackTrace)) {
          return AsyncError(error, stackTrace);
        }
        if (!scope.hasValue) return const AsyncLoading();
        final active = scope.requireValue;
        if (active == null) return const AsyncData({});
        final granted = ref.watch(learnerStateForScopeProvider(active));
        if (granted case AsyncError(:final error, :final stackTrace)) {
          return AsyncError(error, stackTrace);
        }
        if (!granted.hasValue) return const AsyncLoading();
      }
      return ref.watch(mainTrackHeldGroundReadProvider(curriculumId));
    });

/// The ungated read behind [mainTrackHeldGroundProvider]. Watch that
/// provider instead: in a tutored session only it applies the grant gate.
final mainTrackHeldGroundReadProvider = FutureProvider.autoDispose
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
          holds: engineHoldsGround(curriculumState),
        ),
        corpus,
      );
    }, retry: (retryCount, error) => null);
