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
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/pull_pipeline.dart';
import 'package:learning_tracker/core/sync/tutored_listener_source.dart';
import 'package:learning_tracker/core/sync/tutored_listener_supervisor.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// Records every dispatch call.
class _RecordingDispatcher implements MergeDispatcher {
  final dispatched = <({int profileId, String kind, int rowCount})>[];

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

  /// Emits a stream error on [collection]'s channel — models Firestore
  /// terminating a `.snapshots()` stream (e.g. permission-denied on grant
  /// revocation, or a transient stream fault). Used by the
  /// AUD-core-sync-12 regression test.
  void emitError(String collection, Object error, [StackTrace? stackTrace]) {
    _ctrl(collection).addError(error, stackTrace ?? StackTrace.current);
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
  Stream<ListenerSnapshot> listenToLearnerProfiles({
    int limit = 500,
  }) => throw StateError(
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

/// A dispatcher that always throws [error] on dispatch — used to test the
/// R4-M1 catchError path in TutoredListenerSupervisor._onEvent.
///
/// AUD-core-sync-26 (EH-4): [error] is caller-supplied (not hardcoded) so
/// the same fake drives both halves of the EH-4 contract — an [Exception]
/// is still swallowed-and-logged (transient failure), while an [Error]
/// subtype now propagates to the zone instead (programming bug).
class _ThrowingDispatcher implements MergeDispatcher {
  _ThrowingDispatcher({required this.error});

  final Object error;

  @override
  Future<MergeOutcome> dispatch({
    required int profileId,
    required String kind,
    required List<Map<String, dynamic>> rows,
  }) => Future<MergeOutcome>.error(error);
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
      // 13 collection channels + 3 preference document channels = 16 total
      // (AUD-core-sync-18: learning_order added to close the real-time gap).
      // Collection channels: completions, bookmarks, settings, streak_events,
      //   curriculum_tracks, stage_definitions, study_day_configs, goals,
      //   learning_ledger, profile_programs, learning_order, points_ledger,
      //   reward_redemptions.
      // Document channels: preferences/notification_settings,
      //   preferences/gamification_settings, preferences/ui_preferences.
      expect(
        gateway.childCollectionListenerCount,
        13,
        reason: '13 collection listeners opened',
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
          {
            'firestore_id': 'goal-1',
            'updated_at': DateTime.now().toIso8601String(),
          },
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

    // (G) R4-M1: a failing dispatch must not crash (catchError is wired) ──────
    test('(G) R4-M1: an Exception from dispatch is swallowed by catchError '
        '(no unhandled exception)', () async {
      final throwingSupervisor = TutoredListenerSupervisor(
        dispatcher: _ThrowingDispatcher(
          error: Exception('intentional test error'),
        ),
      );
      final gateway = _DrivenChildGateway();
      await throwingSupervisor.attach(
        localProfileId: 1,
        gateway: gateway,
        parentUid: 'parent-uid',
        remoteProfileId: 'child-1',
      );

      // Emit a valid payload — dispatch will throw but must not cause an
      // unhandled exception (the catchError in _onEvent absorbs it).
      gateway.emitCollection('goals', [
        {'firestore_id': 'g1', 'updated_at': DateTime.now().toIso8601String()},
      ]);
      // If catchError is missing this await would surface an unhandled error.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Reaching here means no crash — catchError is wired correctly.
      await throwingSupervisor.detach();
    });

    // (H) AUD-core-sync-26 (EH-4): an Error subtype must NOT be swallowed ────
    test('(H) AUD-core-sync-26 (EH-4): a StateError from dispatch propagates '
        'to the zone instead of being silently swallowed', () async {
      final caught = <Object>[];
      final done = Completer<void>();

      await runZonedGuarded(
        () async {
          final throwingSupervisor = TutoredListenerSupervisor(
            dispatcher: _ThrowingDispatcher(
              error: StateError(
                'programming bug inside the goals merger — e.g. a bad '
                'cast or null dereference, NOT a transient I/O failure',
              ),
            ),
          );
          final gateway = _DrivenChildGateway();
          await throwingSupervisor.attach(
            localProfileId: 1,
            gateway: gateway,
            parentUid: 'parent-uid',
            remoteProfileId: 'child-1',
          );

          gateway.emitCollection('goals', [
            {
              'firestore_id': 'g1',
              'updated_at': DateTime.now().toIso8601String(),
            },
          ]);
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await throwingSupervisor.detach();
          if (!done.isCompleted) done.complete();
        },
        (error, stack) {
          caught.add(error);
          if (!done.isCompleted) done.complete();
        },
      );

      await done.future;
      expect(
        caught,
        hasLength(1),
        reason:
            'the StateError must reach the zone error handler exactly '
            'once — before AUD-core-sync-26 it was caught and logged by '
            'the bare catchError instead',
      );
      expect(caught.single, isA<StateError>());
    });

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

    // (H) AUD-core-sync-12 ───────────────────────────────────────────────────
    test('(H) AUD-core-sync-12: a stream error on a tutored channel reaches '
        'AppLogger instead of being silently dropped', () async {
      AppLogger.init();
      final gateway = _DrivenChildGateway();
      await supervisor.attach(
        localProfileId: 5,
        gateway: gateway,
        parentUid: 'parent-uid',
        remoteProfileId: 'child-1',
      );

      gateway.emitError('goals', Exception('permission-denied (simulated)'));
      await Future<void>.delayed(Duration.zero);

      final history = AppLogger.instance.talker.history
          .map((e) => e.generateTextMessage())
          .toList();
      expect(
        history.any((m) => m.contains('tutored_listener_stream_error')),
        isTrue,
        reason:
            'A tutored-channel stream error must reach AppLogger instead '
            'of vanishing silently (the inner ListenerSupervisor no-ops '
            'onError when null). Talker history: $history',
      );

      await supervisor.detach();
    });

    // (I) AUD-core-sync-18 ───────────────────────────────────────────────────
    test('(I) AUD-core-sync-18: TutoredListenerSource.openChannels() channel '
        "set is identical to PullPipeline.pullForTutoredProfile's collection "
        'set', () {
      final source = TutoredListenerSource(
        gateway: _DrivenChildGateway(),
        parentUid: 'parent-uid',
        remoteProfileId: 'child-1',
      );
      final channelKeys = source.openChannels().keys.toSet();

      final pullKeys = <String>{
        for (final entry in PullPipeline.tutoredCollections) entry.$1,
        for (final entry in PullPipeline.tutoredPreferenceDocs)
          'preferences/${entry.$1}',
      };

      expect(
        channelKeys,
        equals(pullKeys),
        reason:
            'TutoredListenerSource.openChannels() must mirror the pull '
            'set in PullPipeline.pullForTutoredProfile exactly — a '
            'collection present in the pull set but not the listener '
            'channel set reaches the mirror only on the next explicit '
            'pull, never in real time (learning_order was missing from '
            'openChannels before the fix).',
      );
    });

    // (J) AUD-core-sync-18 ───────────────────────────────────────────────────
    test('(J) AUD-core-sync-18: a learning_order channel event is routed to '
        'the dispatcher as EntityKind.learningOrder', () async {
      final gateway = _DrivenChildGateway();
      await supervisor.attach(
        localProfileId: 9,
        gateway: gateway,
        parentUid: 'parent-uid',
        remoteProfileId: 'child-1',
      );

      gateway.emitCollection('learning_order', [
        {
          'firestore_id': 'lo-1',
          'curriculum_id': 'dafYomi',
          'sefaria_ref': 'Berakhot.2a',
          'user_sort_order': 1,
        },
      ]);
      await Future<void>.delayed(Duration.zero);

      final dispatches = dispatcher.dispatched.where(
        (d) => d.kind == 'learning_order',
      );
      expect(dispatches, isNotEmpty);
      for (final d in dispatches) {
        expect(d.profileId, 9);
      }

      await supervisor.detach();
    });
  });
}
