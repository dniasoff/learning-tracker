/// Tests for OutboxProcessor — covers drain() dispatch logic with a fake
/// PushPipeline and in-memory OutboxDao.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/outbox/push_pipeline.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';

import '../../../helpers/drift_memory.dart';

// ── Fake PushPipeline ────────────────────────────────────────────────────────

class _FakePipeline extends Fake implements PushPipeline {
  final List<(String kind, String entityKey)> calls = [];
  bool failNextPush = false;

  @override
  Future<void> pushCompletion({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('completion', entityKey));
  }

  @override
  Future<List<String>> pushCompletionsBatch({
    required int profileId,
    required List<({String entityKey, Map<String, dynamic> payload})> entries,
  }) async {
    if (failNextPush) {
      failNextPush = false;
      throw Exception('network error');
    }
    for (final entry in entries) {
      calls.add(('completion', entry.entityKey));
    }
    return entries.map((e) => e.entityKey).toList();
  }

  @override
  Future<void> pushStreak({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('streak', entityKey));
  }

  @override
  Future<void> pushSettings({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('settings', entityKey));
  }

  @override
  Future<void> pushTrack({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('track', entityKey));
  }

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('learning_order', entityKey));
  }

  @override
  Future<void> pushBookmark({
    required int profileId,
    required String entityKey,
    required Map<String, dynamic> payload,
  }) async {
    calls.add(('bookmark', entityKey));
  }
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late UserDatabase db;
  late _FakePipeline pipeline;
  late OutboxProcessor processor;
  const profileId = 1;

  setUp(() {
    db = inMemoryDb();
    pipeline = _FakePipeline();
    processor = OutboxProcessor(
      outboxDao: db.outboxDao,
      pipeline: pipeline,
      clock: FakeLocalDayClock(DateTime.utc(2026, 5, 14)),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertRow({
    String entityKind = OutboxEntityKind.completion,
    String entityKey = 'key1',
    Map<String, dynamic>? payload,
  }) async {
    await db.outboxDao.insertOutboxRow(
      OutboxCompanion.insert(
        profileId: profileId,
        entityKind: entityKind,
        entityKey: entityKey,
        payload: jsonEncode(payload ?? {'ref': 'Berakhot.2a'}),
        createdAt: DateTime.utc(2026, 5, 14),
      ),
    );
  }

  group('OutboxProcessor.drain', () {
    test('returns 0 when no pending rows', () async {
      final count = await processor.drain(profileId);
      expect(count, 0);
      expect(pipeline.calls, isEmpty);
    });

    test('pushes completion rows and returns 1', () async {
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');

      final count = await processor.drain(profileId);
      expect(count, 1);
      expect(pipeline.calls, [('completion', 'c1')]);
    });

    test('pushes streak rows', () async {
      await insertRow(entityKind: OutboxEntityKind.streak, entityKey: 's1');

      await processor.drain(profileId);
      expect(pipeline.calls, [('streak', 's1')]);
    });

    test('pushes track rows', () async {
      await insertRow(entityKind: OutboxEntityKind.track, entityKey: 't1');

      await processor.drain(profileId);
      expect(pipeline.calls, [('track', 't1')]);
    });

    test('pushes learning_order rows', () async {
      await insertRow(
        entityKind: OutboxEntityKind.learningOrder,
        entityKey: 'lo1',
      );

      await processor.drain(profileId);
      expect(pipeline.calls, [('learning_order', 'lo1')]);
    });

    test('pushes bookmark rows', () async {
      await insertRow(entityKind: OutboxEntityKind.bookmark, entityKey: 'bm1');

      await processor.drain(profileId);
      expect(pipeline.calls, [('bookmark', 'bm1')]);
    });

    test('pushes settings rows', () async {
      await insertRow(entityKind: OutboxEntityKind.settings, entityKey: 'st1');

      await processor.drain(profileId);
      expect(pipeline.calls, [('settings', 'st1')]);
    });

    test('deletes row from outbox after successful push', () async {
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');

      await processor.drain(profileId);

      // Row should be removed.
      final remaining = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        profileId,
      );
      expect(remaining, isEmpty);
    });

    test('keeps row in outbox when push fails', () async {
      pipeline.failNextPush = true;
      await insertRow(
        entityKind: OutboxEntityKind.completion,
        entityKey: 'fail1',
      );

      final count = await processor.drain(profileId);
      expect(count, 0); // failed push does not count

      final remaining = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        profileId,
      );
      expect(remaining, hasLength(1));
    });

    test('continues draining remaining rows after a single failure', () async {
      pipeline.failNextPush = true;
      // Insert a completion (will fail) and then a streak (should succeed).
      await insertRow(
        entityKind: OutboxEntityKind.completion,
        entityKey: 'fail1',
      );
      await insertRow(entityKind: OutboxEntityKind.streak, entityKey: 's1');

      final count = await processor.drain(profileId);
      // Only streak succeeded.
      expect(count, 1);
      expect(pipeline.calls, [('streak', 's1')]);
    });

    test('does not process rows for a different profileId', () async {
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');

      // Drain for profile 2 — should not touch profile 1's row.
      final count = await processor.drain(2);
      expect(count, 0);
      expect(pipeline.calls, isEmpty);
    });

    test('pushes multiple rows of different kinds', () async {
      await insertRow(entityKind: OutboxEntityKind.completion, entityKey: 'c1');
      await insertRow(entityKind: OutboxEntityKind.streak, entityKey: 's1');
      await insertRow(entityKind: OutboxEntityKind.bookmark, entityKey: 'bm1');

      final count = await processor.drain(profileId);
      expect(count, 3);
    });
  });

  group('OutboxEntityKind constants', () {
    test('completion constant is "completion"', () {
      expect(OutboxEntityKind.completion, 'completion');
    });

    test('streak constant is "streak"', () {
      expect(OutboxEntityKind.streak, 'streak');
    });

    test('settings constant is "settings"', () {
      expect(OutboxEntityKind.settings, 'settings');
    });

    test('track constant is "track"', () {
      expect(OutboxEntityKind.track, 'track');
    });

    test('learningOrder constant is "learning_order"', () {
      expect(OutboxEntityKind.learningOrder, 'learning_order');
    });

    test('bookmark constant is "bookmark"', () {
      expect(OutboxEntityKind.bookmark, 'bookmark');
    });
  });
}
