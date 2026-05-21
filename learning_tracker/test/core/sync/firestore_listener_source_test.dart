/// Regression tests for [FirestoreListenerSource].
///
/// W2.29 regression: verifies that `stage_definitions` is included in the
/// channel map returned by [openChannels]. Before W2.29 the channel was absent,
/// so real-time stage-definition changes pushed from another device would never
/// propagate to the local Drift database until the next cold-start pull.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/firestore_listener_source.dart';

// ── Stub FirestoreGateway ────────────────────────────────────────────────────

/// Minimal stub that records every [listenToCollection] call and returns an
/// empty broadcast stream. All other gateway methods throw [UnimplementedError]
/// because this test only exercises the listener-source wiring.
class _StubGateway implements FirestoreGateway {
  final List<String> collectionsCalled = [];

  @override
  Stream<List<Map<String, dynamic>>> listenToCollection({
    required int profileId,
    required String collection,
  }) {
    collectionsCalled.add(collection);
    return const Stream.empty();
  }

  // ── unsupported methods ───────────────────────────────────────────────────

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} not implemented in _StubGateway',
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('FirestoreListenerSource.openChannels()', () {
    late _StubGateway gateway;
    late FirestoreListenerSource source;

    setUp(() {
      gateway = _StubGateway();
      source = FirestoreListenerSource(
        resolveGateway: () => gateway,
        resolveProfileId: () => 1,
      );
    });

    test('includes stage_definitions channel (W2.29 regression)', () {
      final channels = source.openChannels();

      // The key must be present so that [ListenerSupervisor] attaches a
      // subscription and [SyncOrchestratorImpl._channelToKind] can route
      // incoming events to [StageDefinitionMerger].
      expect(channels, contains('stage_definitions'));
    });

    test(
      'stage_definitions channel is backed by a listenToCollection call',
      () {
        source.openChannels();

        expect(
          gateway.collectionsCalled,
          contains('stage_definitions'),
          reason:
              'gateway.listenToCollection must be called with '
              "collection: 'stage_definitions'",
        );
      },
    );

    test('all expected channels are present', () {
      final channels = source.openChannels();

      expect(
        channels.keys,
        containsAll([
          'completions',
          'bookmarks',
          'settings',
          'streak_events',
          'curriculum_tracks',
          'stage_definitions', // W2.29
        ]),
      );
    });
  });
}
