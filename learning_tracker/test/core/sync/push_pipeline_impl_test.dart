/// Unit tests for [OutboxPushPipeline] — the concrete PushPipeline that
/// dispatches outbox mutations to a [FirestoreGateway].
///
/// Coverage focus: routing correctness, single-flight serialisation per
/// entity kind, parallel execution across different kinds, failure recovery,
/// batch vs single dispatch, and payload extraction for delete operations.
///
/// No real Firebase — [_FakeGateway] is an in-process spy that records every
/// call made to it.
library;

import 'dart:async';

import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/push_pipeline_impl.dart';
import 'package:test/test.dart';

// ── Fake Gateway ─────────────────────────────────────────────────────────────

/// A spy [FirestoreGateway] that records every call it receives.
///
/// Each push method appends a [_GatewayCall] to [calls].  The optional
/// [onPushCompletion] / [onPushStreak] / ... hooks let individual tests
/// inject delays or errors without sub-classing.
class _FakeGateway implements FirestoreGateway {
  /// All calls made to any `push*` / `delete*` method, in invocation order.
  final List<_GatewayCall> calls = [];

  // Per-method hooks — set in tests that need custom behaviour.
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushCompletion;
  Future<void> Function(int profileId, Map<String, dynamic> data)? onPushStreak;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushSettings;
  Future<void> Function(int profileId, Map<String, dynamic> data)? onPushTrack;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushLearningOrder;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushBookmark;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushStageDefinition;
  Future<void> Function(int profileId, Map<String, dynamic> data)? onPushGoal;
  Future<void> Function(int profileId, String firestoreId)? onDeleteGoal;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushLearnerProfile;
  Future<void> Function(int profileId)? onDeleteLearnerProfile;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushGamificationSettings;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushNotificationSettings;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushUiPreferences;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushProfileProgram;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushLedgerEntry;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushStudyDayConfig;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushPointsLedgerEntry;
  Future<void> Function(int profileId, Map<String, dynamic> data)?
  onPushRewardRedemption;

  /// Hook for pushCompletionsBatch — lets tests inject partial or total
  /// failures without modifying every push individually.
  Future<List<String>> Function(
    int profileId,
    List<({String entityKey, Map<String, dynamic> payload})> items,
  )?
  onPushCompletionsBatch;

  // ── push* methods ──────────────────────────────────────────────────────────

  @override
  Future<void> pushCompletion({
    required int profileId,
    required Map<String, dynamic> data,
    String? docId,
  }) async {
    calls.add(_GatewayCall('pushCompletion', profileId: profileId, data: data));
    await onPushCompletion?.call(profileId, data);
  }

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> items,
  }) async {
    calls.add(
      _GatewayCall(
        'pushCompletionsBatch',
        profileId: profileId,
        batchItems: items,
      ),
    );
    if (onPushCompletionsBatch != null) {
      return onPushCompletionsBatch!(profileId, items);
    }
    return items.map((e) => e.entityKey).toList();
  }

  @override
  Future<void> pushStreak({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(_GatewayCall('pushStreak', profileId: profileId, data: data));
    await onPushStreak?.call(profileId, data);
  }

  @override
  Future<void> pushSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(_GatewayCall('pushSettings', profileId: profileId, data: data));
    await onPushSettings?.call(profileId, data);
  }

  @override
  Future<void> pushTrack({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(_GatewayCall('pushTrack', profileId: profileId, data: data));
    await onPushTrack?.call(profileId, data);
  }

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(
      _GatewayCall('pushLearningOrder', profileId: profileId, data: data),
    );
    await onPushLearningOrder?.call(profileId, data);
  }

  @override
  Future<void> pushBookmark({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(_GatewayCall('pushBookmark', profileId: profileId, data: data));
    await onPushBookmark?.call(profileId, data);
  }

  @override
  Future<void> pushStageDefinition({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(
      _GatewayCall('pushStageDefinition', profileId: profileId, data: data),
    );
    await onPushStageDefinition?.call(profileId, data);
  }

  @override
  Future<void> pushGoal({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(_GatewayCall('pushGoal', profileId: profileId, data: data));
    await onPushGoal?.call(profileId, data);
  }

  @override
  Future<void> deleteGoal({
    required int profileId,
    required String firestoreId,
  }) async {
    calls.add(
      _GatewayCall(
        'deleteGoal',
        profileId: profileId,
        firestoreId: firestoreId,
      ),
    );
    await onDeleteGoal?.call(profileId, firestoreId);
  }

  @override
  Future<void> pushLearnerProfile({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(
      _GatewayCall('pushLearnerProfile', profileId: profileId, data: data),
    );
    await onPushLearnerProfile?.call(profileId, data);
  }

  @override
  Future<void> deleteLearnerProfile(int profileId) async {
    calls.add(_GatewayCall('deleteLearnerProfile', profileId: profileId));
    await onDeleteLearnerProfile?.call(profileId);
  }

  @override
  Future<void> pushGamificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(
      _GatewayCall(
        'pushGamificationSettings',
        profileId: profileId,
        data: data,
      ),
    );
    await onPushGamificationSettings?.call(profileId, data);
  }

  @override
  Future<void> pushNotificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(
      _GatewayCall(
        'pushNotificationSettings',
        profileId: profileId,
        data: data,
      ),
    );
    await onPushNotificationSettings?.call(profileId, data);
  }

  @override
  Future<void> pushUiPreferences({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(
      _GatewayCall('pushUiPreferences', profileId: profileId, data: data),
    );
    await onPushUiPreferences?.call(profileId, data);
  }

  @override
  Future<void> pushProfileProgram({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(
      _GatewayCall('pushProfileProgram', profileId: profileId, data: data),
    );
    await onPushProfileProgram?.call(profileId, data);
  }

  @override
  Future<void> pushLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(
      _GatewayCall('pushLedgerEntry', profileId: profileId, data: data),
    );
    await onPushLedgerEntry?.call(profileId, data);
  }

  @override
  Future<void> pushStudyDayConfig({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(
      _GatewayCall('pushStudyDayConfig', profileId: profileId, data: data),
    );
    await onPushStudyDayConfig?.call(profileId, data);
  }

  @override
  Future<void> pushPointsLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(
      _GatewayCall('pushPointsLedgerEntry', profileId: profileId, data: data),
    );
    await onPushPointsLedgerEntry?.call(profileId, data);
  }

  @override
  Future<void> pushRewardRedemption({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    calls.add(
      _GatewayCall('pushRewardRedemption', profileId: profileId, data: data),
    );
    await onPushRewardRedemption?.call(profileId, data);
  }

  // ── Unrelated gateway methods (not exercised by PushPipeline) ─────────────

  @override
  Future<void> pushLedgerEntriesBatch({
    required int profileId,
    required List<Map<String, dynamic>> entries,
  }) async {}

  @override
  Future<void> removeProfileProgramAssignment({
    required int profileId,
    required String curriculumStorageKey,
  }) async {}

  @override
  Future<FirestorePage> fetchPage({
    required int profileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => const FirestorePage(rows: []);

  @override
  Future<List<Map<String, dynamic>>> fetchAll({
    required int profileId,
    required String collection,
  }) async => [];

  @override
  Future<void> pushAccountProfile({required Map<String, dynamic> data}) async {}

  @override
  Future<void> pushCurriculumImportMetadata({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> deleteUserData(String uid) async {}

  @override
  Future<void> pushDiagnosticLog({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> pushAccountUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Stream<ListenerSnapshot> listenToCollection({
    required int profileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToTutorGrants({int limit = 500}) =>
      const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToLearnerProfiles({int limit = 500}) =>
      const Stream.empty();

  @override
  Stream<ListenerSnapshot> listenToChildCollection({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String orderField,
    int limit = 500,
  }) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> listenToChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String docId,
  }) => const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> fetchLearnerProfiles() async => [];

  @override
  Future<Map<String, dynamic>?> fetchDocument({
    required int profileId,
    required String collection,
    required String docId,
  }) async => null;

  @override
  Future<FirestorePage> fetchChildPage({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required int pageSize,
    Map<String, dynamic>? cursor,
  }) async => const FirestorePage(rows: []);

  @override
  Future<Map<String, dynamic>?> fetchChildDocument({
    required String parentUid,
    required String remoteProfileId,
    required String collection,
    required String docId,
  }) async => null;

  @override
  Future<List<Map<String, dynamic>>> fetchAuditLogEntries({
    required String grantId,
    String? startTimestamp,
    String? endTimestamp,
    String? actionFilter,
  }) async => [];
}

/// Captured record of a single [_FakeGateway] invocation.
class _GatewayCall {
  _GatewayCall(
    this.method, {
    required this.profileId,
    this.data,
    this.firestoreId,
    this.batchItems,
  });

  final String method;
  final int profileId;
  final Map<String, dynamic>? data;
  final String? firestoreId;
  final List<({String entityKey, Map<String, dynamic> payload})>? batchItems;

  @override
  String toString() =>
      '_GatewayCall($method, profile=$profileId, data=$data, '
      'firestoreId=$firestoreId)';
}

// ── Helpers ───────────────────────────────────────────────────────────────────

OutboxPushPipeline _pipeline(_FakeGateway gateway) =>
    OutboxPushPipeline(gateway: gateway);

const _pid = 7;
const _key = 'entity-key-1';

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('OutboxPushPipeline — per-collection routing', () {
    // Each test: verify that the pipeline method delegates to the CORRECT
    // gateway method with the exact profileId and payload passed through.

    test('pushCompletion → gateway.pushCompletion', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'sefaria_ref': 'Berakhot.2a'};
      await pl.pushCompletion(
        profileId: _pid,
        entityKey: _key,
        payload: payload,
      );
      expect(gw.calls, hasLength(1));
      final call = gw.calls.single;
      expect(call.method, 'pushCompletion');
      expect(call.profileId, _pid);
      expect(call.data, payload);
    });

    test(
      'pushCompletionsBatch → gateway.pushCompletionsBatch (not loop)',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        final entries = [
          (
            entityKey: 'k1',
            payload: <String, dynamic>{'sefaria_ref': 'Berakhot.2a'},
          ),
          (
            entityKey: 'k2',
            payload: <String, dynamic>{'sefaria_ref': 'Berakhot.3a'},
          ),
        ];
        final committed = await pl.pushCompletionsBatch(
          profileId: _pid,
          entries: entries,
        );
        // Must call batch method once, NOT pushCompletion twice.
        expect(
          gw.calls.where((c) => c.method == 'pushCompletion'),
          isEmpty,
          reason: 'pipeline must not fall back to single-item pushCompletion',
        );
        expect(
          gw.calls.where((c) => c.method == 'pushCompletionsBatch'),
          hasLength(1),
        );
        expect(committed, equals(['k1', 'k2']));
      },
    );

    test('pushStreak → gateway.pushStreak', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'streak': 5};
      await pl.pushStreak(profileId: _pid, entityKey: _key, payload: payload);
      expect(gw.calls.single.method, 'pushStreak');
      expect(gw.calls.single.profileId, _pid);
      expect(gw.calls.single.data, payload);
    });

    test('pushSettings → gateway.pushSettings', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'theme': 'dark'};
      await pl.pushSettings(profileId: _pid, entityKey: _key, payload: payload);
      expect(gw.calls.single.method, 'pushSettings');
      expect(gw.calls.single.data, payload);
    });

    test('pushTrack → gateway.pushTrack', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'track_id': 99};
      await pl.pushTrack(profileId: _pid, entityKey: _key, payload: payload);
      expect(gw.calls.single.method, 'pushTrack');
      expect(gw.calls.single.data, payload);
    });

    test('pushLearningOrder → gateway.pushLearningOrder', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'order': 1};
      await pl.pushLearningOrder(
        profileId: _pid,
        entityKey: _key,
        payload: payload,
      );
      expect(gw.calls.single.method, 'pushLearningOrder');
      expect(gw.calls.single.data, payload);
    });

    test('pushBookmark → gateway.pushBookmark', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'ref': 'Berakhot.5a'};
      await pl.pushBookmark(profileId: _pid, entityKey: _key, payload: payload);
      expect(gw.calls.single.method, 'pushBookmark');
      expect(gw.calls.single.data, payload);
    });

    test('pushStageDefinition → gateway.pushStageDefinition', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'stage_order': 2};
      await pl.pushStageDefinition(
        profileId: _pid,
        entityKey: _key,
        payload: payload,
      );
      expect(gw.calls.single.method, 'pushStageDefinition');
      expect(gw.calls.single.data, payload);
    });

    test('pushGoal → gateway.pushGoal', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'goal': 'learn_daf'};
      await pl.pushGoal(profileId: _pid, entityKey: _key, payload: payload);
      expect(gw.calls.single.method, 'pushGoal');
      expect(gw.calls.single.data, payload);
    });

    test('pushLearnerProfile → gateway.pushLearnerProfile', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'display_name': 'Avi'};
      await pl.pushLearnerProfile(
        profileId: _pid,
        entityKey: _key,
        payload: payload,
      );
      expect(gw.calls.single.method, 'pushLearnerProfile');
      expect(gw.calls.single.data, payload);
    });

    test(
      'pushGamificationSettings → gateway.pushGamificationSettings',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        final payload = <String, dynamic>{'points_enabled': true};
        await pl.pushGamificationSettings(
          profileId: _pid,
          entityKey: _key,
          payload: payload,
        );
        expect(gw.calls.single.method, 'pushGamificationSettings');
        expect(gw.calls.single.data, payload);
      },
    );

    test(
      'pushNotificationSettings → gateway.pushNotificationSettings',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        final payload = <String, dynamic>{'push_enabled': false};
        await pl.pushNotificationSettings(
          profileId: _pid,
          entityKey: _key,
          payload: payload,
        );
        expect(gw.calls.single.method, 'pushNotificationSettings');
        expect(gw.calls.single.data, payload);
      },
    );

    test('pushUiPreferences → gateway.pushUiPreferences', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'locale': 'he'};
      await pl.pushUiPreferences(
        profileId: _pid,
        entityKey: _key,
        payload: payload,
      );
      expect(gw.calls.single.method, 'pushUiPreferences');
      expect(gw.calls.single.data, payload);
    });

    test('pushProfileProgram → gateway.pushProfileProgram', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'program_id': 'daf_yomi'};
      await pl.pushProfileProgram(
        profileId: _pid,
        entityKey: _key,
        payload: payload,
      );
      expect(gw.calls.single.method, 'pushProfileProgram');
      expect(gw.calls.single.data, payload);
    });

    test('pushLearningLedgerEntry → gateway.pushLedgerEntry', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'minutes': 30};
      await pl.pushLearningLedgerEntry(
        profileId: _pid,
        entityKey: _key,
        payload: payload,
      );
      expect(gw.calls.single.method, 'pushLedgerEntry');
      expect(gw.calls.single.data, payload);
    });

    test('pushStudyDayConfig → gateway.pushStudyDayConfig', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'day_of_week': 1};
      await pl.pushStudyDayConfig(
        profileId: _pid,
        entityKey: _key,
        payload: payload,
      );
      expect(gw.calls.single.method, 'pushStudyDayConfig');
      expect(gw.calls.single.data, payload);
    });

    test('pushPointsLedgerEntry → gateway.pushPointsLedgerEntry', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'delta': 10};
      await pl.pushPointsLedgerEntry(
        profileId: _pid,
        entityKey: _key,
        payload: payload,
      );
      expect(gw.calls.single.method, 'pushPointsLedgerEntry');
      expect(gw.calls.single.data, payload);
    });

    test('pushRewardRedemption → gateway.pushRewardRedemption', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final payload = <String, dynamic>{'reward_id': 'sticker'};
      await pl.pushRewardRedemption(
        profileId: _pid,
        entityKey: _key,
        payload: payload,
      );
      expect(gw.calls.single.method, 'pushRewardRedemption');
      expect(gw.calls.single.data, payload);
    });
  });

  // ── Delete payload extraction ──────────────────────────────────────────────

  group('OutboxPushPipeline — delete payload extraction', () {
    test(
      'deleteGoal extracts firestore_id from payload and passes it to gateway',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        await pl.deleteGoal(
          profileId: _pid,
          entityKey: _key,
          payload: {'firestore_id': 'goal-firestore-abc'},
        );
        expect(gw.calls.single.method, 'deleteGoal');
        expect(gw.calls.single.profileId, _pid);
        expect(gw.calls.single.firestoreId, 'goal-firestore-abc');
      },
    );

    test(
      'deleteGoal falls back to empty string when firestore_id is absent',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        // Payload has no firestore_id key — the pipeline must not throw.
        await pl.deleteGoal(
          profileId: _pid,
          entityKey: _key,
          payload: <String, dynamic>{},
        );
        expect(gw.calls.single.method, 'deleteGoal');
        expect(gw.calls.single.firestoreId, '');
      },
    );

    test(
      'deleteLearnerProfile uses profile_id from payload when present',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        // payload carries a different profile_id than the outer profileId arg.
        await pl.deleteLearnerProfile(
          profileId: 99,
          entityKey: _key,
          payload: {'profile_id': 42},
        );
        expect(gw.calls.single.method, 'deleteLearnerProfile');
        // Gateway must receive the payload's profile_id (42), not the outer 99.
        expect(gw.calls.single.profileId, 42);
      },
    );

    test('deleteLearnerProfile falls back to outer profileId when '
        'profile_id absent from payload', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      await pl.deleteLearnerProfile(
        profileId: _pid,
        entityKey: _key,
        payload: <String, dynamic>{},
      );
      expect(gw.calls.single.method, 'deleteLearnerProfile');
      expect(gw.calls.single.profileId, _pid);
    });
  });

  // ── Single-flight serialisation ────────────────────────────────────────────

  group('OutboxPushPipeline — single-flight per kind', () {
    test(
      'concurrent calls for the same kind are serialised (non-overlapping)',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        final order = <String>[];

        gw.onPushCompletion = (_, data) async {
          order.add('start:${data['id']}');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          order.add('end:${data['id']}');
        };

        final f1 = pl.pushCompletion(
          profileId: _pid,
          entityKey: 'a',
          payload: {'id': 'a'},
        );
        final f2 = pl.pushCompletion(
          profileId: _pid,
          entityKey: 'b',
          payload: {'id': 'b'},
        );
        await Future.wait(<Future<void>>[f1, f2]);

        expect(
          order,
          equals(['start:a', 'end:a', 'start:b', 'end:b']),
          reason: 'same-kind pushes must not overlap',
        );
      },
    );

    test(
      'three concurrent calls for the same kind execute in arrival order',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        final order = <String>[];

        gw.onPushStreak = (_, data) async {
          order.add('start:${data['id']}');
          await Future<void>.delayed(const Duration(milliseconds: 5));
          order.add('end:${data['id']}');
        };

        final futures = [
          pl.pushStreak(profileId: _pid, entityKey: 's1', payload: {'id': '1'}),
          pl.pushStreak(profileId: _pid, entityKey: 's2', payload: {'id': '2'}),
          pl.pushStreak(profileId: _pid, entityKey: 's3', payload: {'id': '3'}),
        ];
        await Future.wait(futures);

        expect(
          order,
          equals(['start:1', 'end:1', 'start:2', 'end:2', 'start:3', 'end:3']),
          reason: 'three same-kind calls must not overlap',
        );
      },
    );

    test(
      'different entity kinds run in parallel (completion does not block streak)',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        final order = <String>[];

        final completionStarted = Completer<void>();
        final streakAllowedToFinish = Completer<void>();

        gw.onPushCompletion = (_, __) async {
          order.add('completion:start');
          completionStarted.complete();
          await streakAllowedToFinish.future;
          order.add('completion:end');
        };
        gw.onPushStreak = (_, __) async {
          order.add('streak:start');
          order.add('streak:end');
          streakAllowedToFinish.complete();
        };

        final f1 = pl.pushCompletion(
          profileId: _pid,
          entityKey: 'c',
          payload: {'id': 'c'},
        );
        await completionStarted.future;

        final f2 = pl.pushStreak(
          profileId: _pid,
          entityKey: 's',
          payload: {'id': 's'},
        );
        await Future.wait(<Future<void>>[f1, f2]);

        expect(
          order,
          equals([
            'completion:start',
            'streak:start',
            'streak:end',
            'completion:end',
          ]),
          reason: 'different kinds must run in parallel',
        );
      },
    );

    test(
      'failing push releases single-flight slot — next call proceeds',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        var callCount = 0;

        gw.onPushCompletion = (_, __) async {
          callCount++;
          if (callCount == 1) throw StateError('network failure');
        };

        // First call must surface the error.
        await expectLater(
          pl.pushCompletion(
            profileId: _pid,
            entityKey: 'a',
            payload: {'id': 'a'},
          ),
          throwsA(isA<StateError>()),
        );

        // Second call must succeed — slot was released on failure.
        await pl.pushCompletion(
          profileId: _pid,
          entityKey: 'b',
          payload: {'id': 'b'},
        );
        expect(callCount, 2);
      },
    );

    test('in-flight failure for kind A does not block kind B', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      final completionHanging = Completer<void>();

      // Make streak hang until we release it manually.
      gw.onPushStreak = (_, __) async {
        await completionHanging.future; // waits until released
      };

      // Launch streak (will hang).
      final streakFuture = pl.pushStreak(
        profileId: _pid,
        entityKey: 's',
        payload: {'id': 's'},
      );

      // Launch completion (different kind — must not be blocked by streak).
      var completionPushed = false;
      final completionFuture = pl
          .pushCompletion(profileId: _pid, entityKey: 'c', payload: {'id': 'c'})
          .then((_) {
            completionPushed = true;
          });

      // Pump microtasks to let completion proceed.
      await Future<void>.delayed(Duration.zero);
      expect(
        completionPushed,
        isTrue,
        reason: 'completion must not wait for streak to finish',
      );

      completionHanging.complete();
      await streakFuture;
      await completionFuture;
    });

    test('a later same-kind call that arrives while prior is in-flight clears '
        'the slot after it completes, not the prior caller slot', () async {
      // Regression: the slot-clearing logic checks `identical(_inFlight[kind], ourSlot)`.
      // If a third caller replaces the slot before the second completes,
      // the second caller must NOT clear the slot on its way out.
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      var callsMade = 0;

      // Use a completer so we can control when each call starts.
      final firstDone = Completer<void>();
      final secondDone = Completer<void>();

      gw.onPushSettings = (_, data) async {
        callsMade++;
        final id = data['id'] as String;
        if (id == '1') await firstDone.future;
        if (id == '2') await secondDone.future;
      };

      final f1 = pl.pushSettings(
        profileId: _pid,
        entityKey: 'e1',
        payload: {'id': '1'},
      );
      final f2 = pl.pushSettings(
        profileId: _pid,
        entityKey: 'e2',
        payload: {'id': '2'},
      );
      final f3 = pl.pushSettings(
        profileId: _pid,
        entityKey: 'e3',
        payload: {'id': '3'},
      );

      // Release first, then second.
      firstDone.complete();
      await Future<void>.delayed(Duration.zero);
      secondDone.complete();
      await Future<void>.delayed(Duration.zero);

      await Future.wait(<Future<void>>[f1, f2, f3]);
      expect(callsMade, 3);
    });
  });

  // ── Batch push — partial failure ──────────────────────────────────────────

  group('OutboxPushPipeline — pushCompletionsBatch partial-failure', () {
    test(
      'returns committed keys reported by gateway on full success',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        final entries = [
          (entityKey: 'k1', payload: <String, dynamic>{}),
          (entityKey: 'k2', payload: <String, dynamic>{}),
          (entityKey: 'k3', payload: <String, dynamic>{}),
        ];
        final committed = await pl.pushCompletionsBatch(
          profileId: _pid,
          entries: entries,
        );
        expect(committed, equals(['k1', 'k2', 'k3']));
      },
    );

    test(
      'SyncPushException from gateway propagates to caller unchanged',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        gw.onPushCompletionsBatch = (_, items) async {
          throw SyncPushException(
            committed: ['k1'],
            pushCause: Exception('second chunk failed'),
          );
        };
        final entries = [
          (entityKey: 'k1', payload: <String, dynamic>{}),
          (entityKey: 'k2', payload: <String, dynamic>{}),
        ];
        await expectLater(
          pl.pushCompletionsBatch(profileId: _pid, entries: entries),
          throwsA(
            isA<SyncPushException>().having(
              (e) => e.committed,
              'committed',
              equals(['k1']),
            ),
          ),
        );
      },
    );

    test('non-SyncPushException from gateway propagates to caller', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      gw.onPushCompletionsBatch = (_, __) async {
        throw Exception('totally failed');
      };
      await expectLater(
        pl.pushCompletionsBatch(
          profileId: _pid,
          entries: [(entityKey: 'k1', payload: <String, dynamic>{})],
        ),
        throwsException,
      );
    });

    test(
      'pushCompletionsBatch is serialised with pushCompletion for the same kind',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        final order = <String>[];

        gw.onPushCompletion = (_, __) async {
          order.add('single:start');
          await Future<void>.delayed(const Duration(milliseconds: 10));
          order.add('single:end');
        };
        gw.onPushCompletionsBatch = (_, __) async {
          order.add('batch:start');
          order.add('batch:end');
          return ['k1'];
        };

        final f1 = pl.pushCompletion(
          profileId: _pid,
          entityKey: 'x',
          payload: {'id': 'x'},
        );
        final f2 = pl.pushCompletionsBatch(
          profileId: _pid,
          entries: [(entityKey: 'k1', payload: <String, dynamic>{})],
        );
        await Future.wait(<Future<void>>[f1, f2]);

        // batch must not start until single finishes.
        expect(
          order,
          equals(['single:start', 'single:end', 'batch:start', 'batch:end']),
        );
      },
    );
  });

  // ── profileId pass-through ─────────────────────────────────────────────────

  group('OutboxPushPipeline — profileId pass-through', () {
    test(
      'profileId is forwarded unchanged to gateway for every push kind',
      () async {
        const otherPid = 42;
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        final payload = <String, dynamic>{};

        await pl.pushStreak(
          profileId: otherPid,
          entityKey: _key,
          payload: payload,
        );
        await pl.pushSettings(
          profileId: otherPid,
          entityKey: _key,
          payload: payload,
        );
        await pl.pushTrack(
          profileId: otherPid,
          entityKey: _key,
          payload: payload,
        );
        await pl.pushBookmark(
          profileId: otherPid,
          entityKey: _key,
          payload: payload,
        );

        for (final call in gw.calls) {
          expect(
            call.profileId,
            otherPid,
            reason: '${call.method} must forward profileId=$otherPid',
          );
        }
      },
    );

    test('pushCompletionsBatch passes profileId to gateway', () async {
      const otherPid = 13;
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      await pl.pushCompletionsBatch(
        profileId: otherPid,
        entries: [(entityKey: 'k', payload: <String, dynamic>{})],
      );
      expect(gw.calls.single.profileId, otherPid);
    });
  });

  // ── Error propagation (non-batch push methods) ─────────────────────────────

  group('OutboxPushPipeline — error propagation', () {
    test('gateway error in pushStreak propagates to caller', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      gw.onPushStreak = (_, __) async => throw StateError('firestore down');
      await expectLater(
        pl.pushStreak(
          profileId: _pid,
          entityKey: _key,
          payload: <String, dynamic>{},
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('gateway error in pushGoal propagates to caller', () async {
      final gw = _FakeGateway();
      final pl = _pipeline(gw);
      gw.onPushGoal = (_, __) async => throw Exception('permission denied');
      await expectLater(
        pl.pushGoal(
          profileId: _pid,
          entityKey: _key,
          payload: <String, dynamic>{},
        ),
        throwsException,
      );
    });

    test(
      'error does not contaminate subsequent push of a different kind',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        gw.onPushStreak = (_, __) async => throw StateError('bad');
        gw.onPushSettings = null; // succeeds by default

        // Streak fails.
        await expectLater(
          pl.pushStreak(
            profileId: _pid,
            entityKey: 's',
            payload: <String, dynamic>{},
          ),
          throwsA(isA<StateError>()),
        );

        // Settings must still succeed.
        await pl.pushSettings(
          profileId: _pid,
          entityKey: 'cfg',
          payload: <String, dynamic>{},
        );

        expect(gw.calls.where((c) => c.method == 'pushSettings'), hasLength(1));
      },
    );
  });

  // ── Slot idempotency: third call does not evict second's slot ──────────────

  group('OutboxPushPipeline — _inFlight slot management', () {
    test(
      'slot is cleared after last call completes — state does not leak',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);

        await pl.pushCompletion(
          profileId: _pid,
          entityKey: 'a',
          payload: {'id': 'a'},
        );

        // After completion, a subsequent call must be able to start immediately
        // (it should not wait on a stale prior future).
        var started = false;
        gw.onPushCompletion = (_, __) async {
          started = true;
        };

        await pl.pushCompletion(
          profileId: _pid,
          entityKey: 'b',
          payload: {'id': 'b'},
        );
        expect(started, isTrue);
      },
    );

    test(
      'inFlight map is keyed per kind: independent slots for each entity type',
      () async {
        final gw = _FakeGateway();
        final pl = _pipeline(gw);
        final completionDone = Completer<void>();
        final streakDone = Completer<void>();

        gw.onPushCompletion = (_, __) async {
          await completionDone.future;
        };
        gw.onPushStreak = (_, __) async {
          await streakDone.future;
        };

        // Launch both simultaneously.
        final fc = pl.pushCompletion(
          profileId: _pid,
          entityKey: 'c',
          payload: {'id': 'c'},
        );
        final fs = pl.pushStreak(
          profileId: _pid,
          entityKey: 's',
          payload: {'id': 's'},
        );

        // Neither has finished yet, so both futures are pending.
        expect(fc, isA<Future<void>>());
        expect(fs, isA<Future<void>>());

        completionDone.complete();
        streakDone.complete();
        await Future.wait(<Future<void>>[fc, fs]);

        // Both should have called the gateway once each.
        expect(
          gw.calls.where((c) => c.method == 'pushCompletion'),
          hasLength(1),
        );
        expect(gw.calls.where((c) => c.method == 'pushStreak'), hasLength(1));
      },
    );
  });
}
