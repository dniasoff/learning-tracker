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
///   completions       — profile subcollection
///   bookmarks         — profile subcollection
///   settings          — profile subcollection
///   streak            — single-document stream
///   curriculum_tracks — profile subcollection
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
      'streak': gateway.listenToDocument(
        profileId: profileId,
        collection: 'streak',
        docId: 'data',
      ),
      'curriculum_tracks': gateway.listenToCollection(
        profileId: profileId,
        collection: 'curriculum_tracks',
      ),
    };
  }
}
