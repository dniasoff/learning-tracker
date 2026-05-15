import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/listener_supervisor.dart';

/// [ListenerSource] implementation backed by [FirestoreGateway].
///
/// Opens one broadcast stream per logical collection channel and hands the
/// resulting map to [ListenerSupervisor]. Each call to [openChannels] creates
/// brand-new streams so that a `restart()` cancels old subscriptions before
/// attaching new ones — matching the correctness contract in DNI-335.
///
/// Channels exposed:
///   completions       — profile subcollection
///   bookmarks         — profile subcollection
///   settings          — profile subcollection
///   streak            — single-document stream
///   curriculum_tracks — profile subcollection
///   learning_order    — profile subcollection
class FirestoreListenerSource implements ListenerSource {
  FirestoreListenerSource({
    required FirestoreGateway gateway,
    required int profileId,
  }) : _gateway = gateway,
       _profileId = profileId;

  final FirestoreGateway _gateway;
  final int _profileId;

  @override
  Map<String, Stream<Object?>> openChannels() {
    return {
      'completions': _gateway.listenToCollection(
        profileId: _profileId,
        collection: 'completions',
      ),
      'bookmarks': _gateway.listenToCollection(
        profileId: _profileId,
        collection: 'bookmarks',
      ),
      'settings': _gateway.listenToCollection(
        profileId: _profileId,
        collection: 'settings',
      ),
      'streak': _gateway.listenToDocument(
        profileId: _profileId,
        collection: 'streak',
        docId: 'data',
      ),
      'curriculum_tracks': _gateway.listenToCollection(
        profileId: _profileId,
        collection: 'curriculum_tracks',
      ),
      'learning_order': _gateway.listenToCollection(
        profileId: _profileId,
        collection: 'learning_order',
      ),
    };
  }
}
