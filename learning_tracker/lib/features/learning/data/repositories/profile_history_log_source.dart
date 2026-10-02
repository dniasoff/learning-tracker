/// The learning feature's repository-layer read of one profile's complete
/// event log plus its live and tombstoned sub-tracks (Story 1.13, DNI-475).
///
/// AD-23/AD-28: feature presentation may not import `lib/data/firestore/**`
/// directly, so the Story 1.2 (DNI-464) repository providers are reached
/// here, in the feature's `data/repositories/` layer, and exposed as one
/// domain value ([ProfileHistoryLog]). No Firestore type leaves this file.
///
/// Paging is owned by the Story 1.2 adapters (orchestrator ruling: DNI-464
/// is the sole creator of `firestore_learning_event_repository.dart`):
/// both `watchAll` reads page by document id at ≤ 500 rows until a short
/// page proves exhaustion and publish only complete lists. This source only
/// joins the two complete reads; it never publishes before BOTH are
/// complete, so a history can never be built from a partial log.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/models/profile_history_log.dart';

export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show activeLearnerScopeProvider;

/// Joins two complete reads into [ProfileHistoryLog]s.
///
/// Publishes only once [events] and [subTracks] have each delivered a
/// [CompleteReadReady], and again whenever either publishes a new complete
/// list. [CompleteReadLoading] is never published (the last complete list
/// stays current, per the `CompleteRead` contract). A stream-level error
/// from either source is forwarded, so the consumer can show a retryable
/// failure instead of silently relabelling a source.
Stream<ProfileHistoryLog> joinCompleteHistoryReads(
  Stream<CompleteRead<LearningEvent>> events,
  Stream<CompleteRead<SubTrack>> subTracks,
) {
  CompleteReadReady<LearningEvent>? latestEvents;
  CompleteReadReady<SubTrack>? latestTracks;
  StreamSubscription<CompleteRead<LearningEvent>>? eventsSub;
  StreamSubscription<CompleteRead<SubTrack>>? tracksSub;
  late final StreamController<ProfileHistoryLog> out;

  void publish() {
    final e = latestEvents;
    final s = latestTracks;
    if (e == null || s == null) return;
    out.add(
      ProfileHistoryLog(
        events: e.items,
        subTracks: s.items,
        rejected: [...e.rejected, ...s.rejected],
      ),
    );
  }

  out = StreamController<ProfileHistoryLog>(
    onListen: () {
      eventsSub = events.listen((read) {
        if (read is CompleteReadReady<LearningEvent>) {
          latestEvents = read;
          publish();
        }
      }, onError: out.addError);
      tracksSub = subTracks.listen((read) {
        if (read is CompleteReadReady<SubTrack>) {
          latestTracks = read;
          publish();
        }
      }, onError: out.addError);
    },
    onCancel: () async {
      await eventsSub?.cancel();
      await tracksSub?.cancel();
      await out.close();
    },
  );
  return out.stream;
}

/// The complete [ProfileHistoryLog] of [LearnerScope], live.
///
/// Stays loading while either repository is not ready (no active,
/// authenticated account — ruling B1) and until both complete reads have
/// arrived. A repository or listener failure surfaces as `AsyncError`.
final profileHistoryLogProvider = StreamProvider.autoDispose
    .family<ProfileHistoryLog, LearnerScope>((ref, scope) async* {
      final events = await ref.watch(learningEventRepositoryProvider.future);
      final tracks = await ref.watch(subTrackRepositoryProvider.future);
      if (events == null || tracks == null) {
        // Not ready: stay loading rather than publish an empty history.
        yield* Stream<ProfileHistoryLog>.fromFuture(
          Completer<ProfileHistoryLog>().future,
        );
        return;
      }
      yield* joinCompleteHistoryReads(
        events.watchAll(scope),
        tracks.watchAll(scope),
      );
    }, retry: (retryCount, error) => null);
