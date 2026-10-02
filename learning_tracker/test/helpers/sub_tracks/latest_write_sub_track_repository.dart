/// A device's view of a shared in-memory "server" for the Story 2.7
/// (DNI-498) concurrent-append tests: a [SubTrackRepository] that also
/// implements [SubTrackLatestWrite], like `FirestoreSubTrackRepository`.
///
/// Every device wraps the same [InMemorySubTrackRepository] (the server).
/// [freezeCache] pins what this device's `watchAll` reports (its local
/// cache has not yet received the other device's write), while
/// [applyGovernedChangeToLatest] always derives from the server's current
/// row, as the Firestore transaction does. With [InMemorySubTrackRepository.
/// offline] set it throws [OnlineRequiredException] (a transaction needs
/// the server) and the command refuses the append as online-required.
library;

import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/oversized_governed_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_latest_write.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../learner_state/in_memory_ports.dart';

/// One device over the shared [server].
final class LatestWriteSubTrackRepository
    implements SubTrackRepository, SubTrackLatestWrite {
  /// Creates a device view of [server].
  LatestWriteSubTrackRepository(this.server);

  /// The shared store every device writes to.
  final InMemorySubTrackRepository server;

  List<SubTrack>? _frozen;

  /// How many times a latest-row build ran (a transaction re-run counts).
  int builds = 0;

  /// Pins this device's reads to the server's current rows of [scope].
  void freezeCache(LearnerScope scope) => _frozen = server.tracksOf(scope);

  @override
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope) {
    final frozen = _frozen;
    if (frozen == null) return server.watchAll(scope);
    return Stream.value(CompleteReadReady<SubTrack>(frozen));
  }

  @override
  Future<void> applyGovernedChange(LearnerScope scope, SubTrackChange change) =>
      server.applyGovernedChange(scope, change);

  @override
  Future<SubTrackChange?> applyGovernedChangeToLatest(
    LearnerScope scope,
    String subTrackId,
    SubTrackChange? Function(SubTrack latest) build,
  ) async {
    if (server.offline) throw const OnlineRequiredException();
    SubTrack? latest;
    for (final t in server.tracksOf(scope)) {
      if (t.id == subTrackId) latest = t;
    }
    if (latest == null) throw SubTrackNotFoundException(subTrackId);
    builds++;
    final change = build(latest);
    if (change == null) return null;
    await server.applyGovernedChange(scope, change);
    return change;
  }
}
