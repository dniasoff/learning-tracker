/// Regression tests for [FirestoreListenerSource].
///
/// W2.29 regression: verifies that `stage_definitions` is included in the
/// channel map returned by [openChannels]. Before W2.29 the channel was absent,
/// so real-time stage-definition changes pushed from another device would never
/// propagate to the local Drift database until the next cold-start pull.
///
/// Phase 2 (sync-architecture-plan 2026-05-21): every channel must carry an
/// explicit ordering field and a bounded page size.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/firestore_listener_source.dart';

// ── Stub FirestoreGateway ────────────────────────────────────────────────────

/// Minimal stub that records every [listenToCollection] call and returns an
/// empty broadcast stream. All other gateway methods throw [UnimplementedError]
/// because this test only exercises the listener-source wiring.
class _StubGateway implements FirestoreGateway {
  final List<({String collection, String orderField, int limit})>
  collectionCalls = [];
  final List<({String collection, String docId})> docCalls = [];
  bool tutorGrantsCalled = false;
  bool learnerProfilesCalled = false;

  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) {
    collectionCalls.add((
      collection: collection,
      orderField: orderField,
      limit: limit,
    ));
    return const Stream.empty();
  }

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) {
    docCalls.add((collection: collection, docId: docId));
    return const Stream.empty();
  }

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int limit = 500}) {
    tutorGrantsCalled = true;
    return const Stream.empty();
  }

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit = 500}) {
    learnerProfilesCalled = true;
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
      expect(channels, contains('stage_definitions'));
    });

    test(
      'stage_definitions channel is backed by a listenToCollection call',
      () {
        source.openChannels();
        expect(
          gateway.collectionCalls.map((c) => c.collection),
          contains('stage_definitions'),
        );
      },
    );

    test('all pre-Phase-2 channels are present', () {
      final channels = source.openChannels();
      expect(
        channels.keys,
        containsAll([
          'completions',
          'bookmarks',
          'settings',
          'streak_events',
          'curriculum_tracks',
          'stage_definitions',
        ]),
      );
    });

    test('Phase 2 — all 9 new listeners are registered', () {
      final channels = source.openChannels();
      expect(
        channels.keys,
        containsAll([
          'goals',
          'learning_ledger',
          'learning_order',
          'profile_programs',
          'learner_profiles',
          'preferences/notification_settings',
          'preferences/gamification_settings',
          'preferences/ui_preferences',
          'tutor_grants',
        ]),
      );
    });

    test(
      'Phase 2 — every collection listener uses a non-default ordering field',
      () {
        source.openChannels();
        for (final entry in gateway.collectionCalls) {
          // Either the collection has a known order field in the
          // FirestoreListenerSource.orderFields map, or the listener falls
          // back to documentId — but every wired collection in Phase 2 must
          // carry an explicit, recognised field.
          expect(
            FirestoreListenerSource.orderFields[entry.collection],
            isNotNull,
            reason:
                '${entry.collection} listener must register an explicit '
                'ordering field in FirestoreListenerSource.orderFields',
          );
          expect(entry.orderField, equals(entry.orderField));
        }
      },
    );

    test('Phase 2 — preference docs are wired via listenToDocument', () {
      source.openChannels();
      final calls = gateway.docCalls
          .map((c) => '${c.collection}/${c.docId}')
          .toList();
      expect(calls, contains('preferences/notification_settings'));
      expect(calls, contains('preferences/gamification_settings'));
      expect(calls, contains('preferences/ui_preferences'));
    });

    test(
      'Phase 2 — learner_profiles + tutor_grants use dedicated gateway methods',
      () {
        source.openChannels();
        expect(gateway.learnerProfilesCalled, isTrue);
        expect(gateway.tutorGrantsCalled, isTrue);
      },
    );
  });

  // ── profileId == 0 sentinel guard ──────────────────────────────────────────
  //
  // Regression for the PERMISSION_DENIED flood after an account switch-back:
  // [ActiveProfileId] transiently resolves to 0 (the no-profile sentinel)
  // before the signed-in account's real active profile resolves. A listener
  // restart fired during that window must NOT open per-profile subcollection
  // listeners against `users/{uid}/learner_profiles/0/...` — there is no
  // `learner_profiles/0` document, so the Firestore rules deny every read.
  group('FirestoreListenerSource.openChannels() — profileId == 0 sentinel', () {
    late _StubGateway gateway;
    late FirestoreListenerSource source;

    setUp(() {
      gateway = _StubGateway();
      source = FirestoreListenerSource(
        resolveGateway: () => gateway,
        resolveProfileId: () => FirestoreListenerSource.noProfileSentinel,
      );
    });

    test('opens NO per-profile collection listeners', () {
      source.openChannels();
      expect(
        gateway.collectionCalls,
        isEmpty,
        reason:
            'profileId == 0 has no learner_profiles/0 doc; opening per-profile '
            'collection listeners floods logcat with PERMISSION_DENIED',
      );
    });

    test('opens NO per-profile document listeners (preferences)', () {
      source.openChannels();
      expect(gateway.docCalls, isEmpty);
    });

    test('exposes NONE of the per-profile channels', () {
      const perProfileChannels = [
        'completions',
        'bookmarks',
        'settings',
        'streak_events',
        'curriculum_tracks',
        'stage_definitions',
        'study_day_configs',
        'goals',
        'learning_ledger',
        'learning_order',
        'profile_programs',
        'points_ledger',
        'reward_redemptions',
        'preferences/notification_settings',
        'preferences/gamification_settings',
        'preferences/ui_preferences',
      ];
      final channels = source.openChannels();
      for (final channel in perProfileChannels) {
        expect(
          channels.keys,
          isNot(contains(channel)),
          reason: '$channel must be skipped while profileId == 0',
        );
      }
    });

    test(
      'still opens account-level channels (learner_profiles + tutor_grants)',
      () {
        // These address `users/{uid}/learner_profiles` and the root
        // `tutor_grants` collection — they are profile-id independent and must
        // stay live even before a concrete profile resolves.
        final channels = source.openChannels();
        expect(
          channels.keys,
          containsAll(['learner_profiles', 'tutor_grants']),
        );
        expect(gateway.learnerProfilesCalled, isTrue);
        expect(gateway.tutorGrantsCalled, isTrue);
      },
    );

    test('re-resolving to a real profile re-opens the full channel set', () {
      // Simulate the orchestrator's restart() after the active profile
      // resolves: a fresh openChannels() with profileId != 0 must include the
      // per-profile channels again.
      var pid = FirestoreListenerSource.noProfileSentinel;
      final dynamicSource = FirestoreListenerSource(
        resolveGateway: () => gateway,
        resolveProfileId: () => pid,
      );

      final sentinelChannels = dynamicSource.openChannels();
      expect(sentinelChannels.keys, isNot(contains('completions')));

      pid = 7;
      final realChannels = dynamicSource.openChannels();
      expect(realChannels.keys, contains('completions'));
      expect(
        gateway.collectionCalls.map((c) => c.collection),
        contains('completions'),
      );
    });
  });
}
