/// D3/D5 — TutoredListenerSupervisor lifecycle tests.
///
/// Tests:
///   (A) attach() creates N subscriptions; detach() cancels all.
///   (B) A fake Firestore stream emitting a doc → MergeRouter is invoked with
///       the synthetic localProfileId.
///   (C) Isolation: the supervisor ONLY calls child-scoped gateway methods;
///       own-data gateway methods throw StateError if invoked.
///   (D) Lifecycle: enter → exit fires detach → re-enter fires re-attach.
///   (E) Cross-session: signing in as a different uid (via detach + re-attach)
///       has no leftover subscriptions from the old session.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:learning_tracker/core/sync/tutored_listener_supervisor.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// Records every dispatch call.
class _RecordingDispatcher implements MergeDispatcher {
  final dispatched =
      <({int profileId, String kind, int rowCount})>[];

  @override
  Future<MergeOutcome> dispatch({
    required int profileId,
    required String kind,
    required List<Map<String, dynamic>> rows,
  }) async {
    dispatched.add((profileId: profileId, kind: kind, rowCount: rows.length));
    return MergeOutcome.continueNext;
  }
}

/// A gateway that records how many child-collection listeners were opened
/// and allows tests to push payloads through them.
class _DrivenChildGateway implements FirestoreGateway {
  final Map<String, StreamController<Object?>> controllers = {};
  int childCollectionListenerCount = 0;
  int childDocumentListenerCount = 0;

  StreamController<Object?> _ctrl(String key) =>
      controllers.putIfAbsent(key, () => StreamController<Object?>.broadcast());

  void emitCollection(String collection, List<Map<String, dynamic>> rows) {
    _ctrl(collection).add(ListenerSnapshot(rows: rows, isAtLimit: false));
  }

  void emitDocument(String collection, String docId, Map<String, dynamic> row) {
    _ctrl('$collection/$docId').add(row);
  }

  @override
  Stream<ListenerSnapshot> listenToChildCollection({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) {
    childCollectionListenerCount++;
    return _ctrl(collection).stream.cast<ListenerSnapshot>();
  }

  @override
  Stream<Map<String, dynamic>?> listenToChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String docId,
  }) {
    childDocumentListenerCount++;
    return _ctrl('$collection/$docId').stream.cast<Map<String, dynamic>?>();
  }

  // ── Own-data methods MUST NEVER be called by TutoredListenerSupervisor ───

  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => throw StateError(
    'listenToCollection must not be called by TutoredListenerSupervisor',
  );

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int limit = 500}) =>
      throw StateError(
        'listenToTutorGrants must not be called by TutoredListenerSupervisor',
      );

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit = 500}) =>
      throw StateError(
        'listenToLearnerProfiles must not be called by TutoredListenerSupervisor',
      );

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => throw StateError(
    'listenToDocument must not be called by TutoredListenerSupervisor',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    '${invocation.memberName} must not be called by TutoredListenerSupervisor',
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('TutoredListenerSupervisor', () {
    late _RecordingDispatcher dispatcher;
    late TutoredListenerSupervisor supervisor;

    setUp(() {
      dispatcher = _RecordingDispatcher();
      supervisor = TutoredListenerSupervisor(dispatcher: dispatcher);
    });

    // (A) ─────────────────────────────────────────────────────────────────────
    test('(A) attach opens subscriptions; detach cancels all', () async {
      final gateway = _DrivenChildGateway();
      await supervisor.attach(
        localProfileId: 1,
        gateway: gateway,
        parentUid: 'parent-uid',
        remoteProfileId: 'child-1',
      );

      expect(supervisor.isAttached, isTrue);
      // 12 collection channels + 3 preference document channels = 15 total.
      // Collection channels: completions, bookmarks, settings, streak_events,
      //   curriculum_tracks, stage_definitions, study_day_configs, goals,
      //   learning_ledger, profile_programs, points_ledger, reward_redemptions.
      // Document channels: preferences/notification_settings,
      //   preferences/gamification_settings, preferences/ui_preferences.
      expect(
        gateway.childCollectionListenerCount,
        12,
        reason: '12 collection listeners opened',
      );
      expect(
        gateway.childDocumentListenerCount,
        3,
        reason: '3 preference document listeners opened',
      );

      await supervisor.detach();
      expect(supervisor.isAttached, isFalse);
    });

    // (B) ─────────────────────────────────────────────────────────────────────
    test(
      '(B) stream emitting a doc → dispatcher invoked with synthetic localProfileId',
      () async {
        final gateway = _DrivenChildGateway();
        await supervisor.attach(
          localProfileId: 42,
          gateway: gateway,
          parentUid: 'parent-uid',
          remoteProfileId: 'child-1',
        );

        // Emit a fake track row on the curriculum_tracks channel.
        gateway.emitCollection('curriculum_tracks', [
          {
            'firestore_id': 'track-1',
            'curriculum_id': 'dafYomi',
            'updated_at': DateTime.now().toIso8601String(),
          },
        ]);

        // Allow the stream event to propagate.
        await Future<void>.delayed(Duration.zero);

        final trackDispatches = dispatcher.dispatched.where(
          (d) => d.kind == 'track_config',
        );
        expect(trackDispatches, isNotEmpty);
        for (final d in trackDispatches) {
          expect(
            d.profileId,
            42,
            reason: 'Merger must receive synthetic local id (42)',
          );
        }

        await supervisor.detach();
      },
    );

    // (C) ─────────────────────────────────────────────────────────────────────
    test(
      '(C) supervisor only calls child-scoped gateway methods (isolation)',
      () async {
        // _DrivenChildGateway throws StateError if any own-data method is
        // called. This test verifies attach() completes without triggering any.
        final gateway = _DrivenChildGateway();
        await expectLater(
          () => supervisor.attach(
            localProfileId: 1,
            gateway: gateway,
            parentUid: 'parent-uid',
            remoteProfileId: 'child-1',
          ),
          returnsNormally,
        );
        await supervisor.detach();
      },
    );

    // (D) ─────────────────────────────────────────────────────────────────────
    test('(D) enter → exit → re-enter lifecycle', () async {
      final gateway = _DrivenChildGateway();

      // First entry.
      await supervisor.attach(
        localProfileId: 1,
        gateway: gateway,
        parentUid: 'parent-uid',
        remoteProfileId: 'child-1',
      );
      expect(supervisor.isAttached, isTrue);
      final countAfterFirstAttach = gateway.childCollectionListenerCount;

      // Exit.
      await supervisor.detach();
      expect(supervisor.isAttached, isFalse);

      // Re-entry (same child).
      await supervisor.attach(
        localProfileId: 1,
        gateway: gateway,
        parentUid: 'parent-uid',
        remoteProfileId: 'child-1',
      );
      expect(supervisor.isAttached, isTrue);
      // New subscriptions were opened (old set was detached and new set opened).
      expect(
        gateway.childCollectionListenerCount,
        greaterThan(countAfterFirstAttach),
      );

      await supervisor.detach();
    });

    // (E) ─────────────────────────────────────────────────────────────────────
    test(
      '(E) cross-session: switching accounts leaves no leftover subscriptions',
      () async {
        final gateway = _DrivenChildGateway();

        // First account session.
        await supervisor.attach(
          localProfileId: 100,
          gateway: gateway,
          parentUid: 'parent-uid-A',
          remoteProfileId: 'child-A',
        );
        expect(supervisor.isAttached, isTrue);

        // Simulate account switch: AppShell fires exit() which calls detach().
        await supervisor.detach();
        expect(supervisor.isAttached, isFalse);

        // Emit on old session's channel — must NOT reach the dispatcher now.
        final dispatchCountBefore = dispatcher.dispatched.length;
        gateway.emitCollection('curriculum_tracks', [
          {'firestore_id': 'stale-track', 'updated_at': 'old'},
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(
          dispatcher.dispatched.length,
          dispatchCountBefore,
          reason: 'Stale stream events must not reach dispatcher after detach',
        );

        // Second account session — new attach must work cleanly.
        final gateway2 = _DrivenChildGateway();
        await supervisor.attach(
          localProfileId: 200,
          gateway: gateway2,
          parentUid: 'parent-uid-B',
          remoteProfileId: 'child-B',
        );
        expect(supervisor.isAttached, isTrue);

        gateway2.emitCollection('goals', [
          {'firestore_id': 'goal-1', 'updated_at': DateTime.now().toIso8601String()},
        ]);
        await Future<void>.delayed(Duration.zero);

        final goalDispatches = dispatcher.dispatched.where(
          (d) => d.kind == 'goal',
        );
        expect(goalDispatches, isNotEmpty);
        for (final d in goalDispatches) {
          expect(
            d.profileId,
            200,
            reason: 'New session must dispatch under new localProfileId',
          );
        }

        await supervisor.detach();
      },
    );

    // (F) ─────────────────────────────────────────────────────────────────────
    test('(F) preference document payloads routed correctly', () async {
      final gateway = _DrivenChildGateway();
      await supervisor.attach(
        localProfileId: 7,
        gateway: gateway,
        parentUid: 'parent-uid',
        remoteProfileId: 'child-1',
      );

      gateway.emitDocument('preferences', 'gamification_settings', {
        'firestore_id': 'gamification_settings',
        'points_per_item': 3,
      });
      await Future<void>.delayed(Duration.zero);

      final gamDispatches = dispatcher.dispatched.where(
        (d) => d.kind == 'gamification_settings',
      );
      expect(gamDispatches, isNotEmpty);
      for (final d in gamDispatches) {
        expect(d.profileId, 7);
      }

      await supervisor.detach();
    });
  });
}
