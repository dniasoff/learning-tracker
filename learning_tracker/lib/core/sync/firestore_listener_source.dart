import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/listener_supervisor.dart';

/// [ListenerSource] implementation backed by [FirestoreGateway].
///
/// Opens one broadcast stream per logical collection channel and hands the
/// resulting map to [ListenerSupervisor]. Each call to [openChannels] creates
/// brand-new streams so that a `restart()` cancels old subscriptions before
/// attaching new ones — matching the correctness contract in DNI-335.
///
/// Both the active profile id and the [FirestoreGateway] are resolved lazily
/// on every [openChannels] call rather than captured at construction. This
/// means a `ListenerSupervisor.restart()` after a profile switch — or after
/// the gateway provider rebuilds — re-opens the channels bound to the CURRENT
/// profile and CURRENT gateway. The live listener set is never pinned to a
/// stale profile id (I3 / R1) or a dead gateway handle (I5).
///
/// Channels exposed (each must have a matching entry in
/// `SyncOrchestratorImpl._channelToKind` and an [EntityMerger]):
///   completions        — profile subcollection
///   bookmarks          — profile subcollection
///   settings           — profile subcollection
///   streak_events      — per-event collection (W3.37: replaces streak/data doc)
///   curriculum_tracks  — profile subcollection
///   stage_definitions  — profile subcollection (W2.29 — real-time listener)
///   study_day_configs  — profile subcollection (Phase 1 — closes the
///                        study-day sync gap; per-curriculum/per-track day
///                        pattern was previously local-only)
///
/// `learning_order` is intentionally absent — it has no [EntityMerger] yet
/// and is covered by `PullPipeline.pullLearningOrder()` on launch.
class FirestoreListenerSource implements ListenerSource {
  FirestoreListenerSource({
    required FirestoreGateway Function() resolveGateway,
    required int Function() resolveProfileId,
  }) : _resolveGateway = resolveGateway,
       _resolveProfileId = resolveProfileId;

  final FirestoreGateway Function() _resolveGateway;
  final int Function() _resolveProfileId;

  @override
  Map<String, Stream<Object?>> openChannels() {
    // Resolve once per openChannels() call so every channel in this set is
    // bound to the same (current) gateway and profile id.
    final gateway = _resolveGateway();
    final profileId = _resolveProfileId();
    return {
      'completions': gateway.listenToCollection(
        profileId: profileId,
        collection: 'completions',
      ),
      'bookmarks': gateway.listenToCollection(
        profileId: profileId,
        collection: 'bookmarks',
      ),
      'settings': gateway.listenToCollection(
        profileId: profileId,
        collection: 'settings',
      ),
      // W3.37: streak migrated from a single snapshot doc (streak/{id}/data)
      // to an append-only per-event collection (streak_events/{ulid}).
      // The old `streak/data` document no longer exists; subscribing to it
      // would emit null immediately and then never fire again.
      'streak_events': gateway.listenToCollection(
        profileId: profileId,
        collection: 'streak_events',
      ),
      'curriculum_tracks': gateway.listenToCollection(
        profileId: profileId,
        collection: 'curriculum_tracks',
      ),
      // W2.29 — wire the real-time listener for stage_definitions so that
      // changes pushed from another device propagate without a full pull.
      // Push + pull are already wired; this closes the listener gap.
      'stage_definitions': gateway.listenToCollection(
        profileId: profileId,
        collection: 'stage_definitions',
      ),
      // Phase 1 — listener for the new study_day_configs collection. The
      // per-curriculum/per-track day pattern was local-only before; the
      // merger now consumes pulled rows and reconciles them with the Drift
      // table.
      'study_day_configs': gateway.listenToCollection(
        profileId: profileId,
        collection: 'study_day_configs',
      ),
    };
  }
}
