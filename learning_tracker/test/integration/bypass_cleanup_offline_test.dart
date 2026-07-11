/// Phase 1 — direct-gateway bypass conversions.
///
/// Each previously-bypassing path now lands in the outbox so an offline write
/// is retained and pushed by the next drain. The tests below exercise the
/// four converted paths (learning ledger, notification settings, profile
/// program, bookmark-on-track-create) at the unit level: go "offline" by
/// throwing from the pipeline, perform the write, verify the outbox holds
/// the row; come "online" by clearing the throw, drain, verify the gateway
/// received it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/push_pipeline_impl.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';

import '../helpers/drift_memory.dart';

class _OfflineGateway implements FirestoreGateway {
  bool offline = true;

  final List<Map<String, dynamic>> ledgerPushes = [];
  final List<Map<String, dynamic>> notificationPushes = [];
  final List<Map<String, dynamic>> profileProgramPushes = [];
  final List<Map<String, dynamic>> bookmarkPushes = [];
  final List<Map<String, dynamic>> studyDayConfigPushes = [];
  final List<Map<String, dynamic>> streakPushes = [];

  Future<void> _gate() async {
    if (offline) throw Exception('offline');
  }

  @override
  Future<void> pushLedgerEntry({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    await _gate();
    ledgerPushes.add(data);
  }

  @override
  Future<void> pushNotificationSettings({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    await _gate();
    notificationPushes.add(data);
  }

  @override
  Future<void> pushProfileProgram({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    await _gate();
    profileProgramPushes.add(data);
  }

  @override
  Future<void> pushBookmark({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    await _gate();
    bookmarkPushes.add(data);
  }

  @override
  Future<void> pushStudyDayConfig({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    await _gate();
    studyDayConfigPushes.add(data);
  }

  @override
  Future<void> pushStreak({
    required int profileId,
    required Map<String, dynamic> data,
  }) async {
    await _gate();
    streakPushes.add(data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness({
    required this.db,
    required this.gateway,
    required this.facade,
    required this.processor,
  });

  final UserDatabase db;
  final _OfflineGateway gateway;
  final OutboxSyncWriteFacade facade;
  final OutboxProcessor processor;

  static Future<_Harness> create() async {
    final db = inMemoryDb();
    await seedProfile(db);
    final gateway = _OfflineGateway();
    final pipeline = OutboxPushPipeline(gateway: gateway);
    final processor = OutboxProcessor(
      outboxDao: db.outboxDao,
      pipeline: pipeline,
      clock: FakeLocalDayClock(DateTime.utc(2026, 5, 21)),
    );
    final facade = OutboxSyncWriteFacade(
      outboxDao: db.outboxDao,
      database: db,
      resolveProfileId: () => 1,
      clock: FakeLocalDayClock(DateTime.utc(2026, 5, 21)),
    );
    return _Harness(
      db: db,
      gateway: gateway,
      facade: facade,
      processor: processor,
    );
  }

  Future<void> close() async => db.close();
}

void main() {
  group('bypass cleanup — offline retain, online drain', () {
    test('learning ledger: write offline → outbox row → drain online → '
        'gateway received', () async {
      final h = await _Harness.create();
      addTearDown(h.close);

      // OFFLINE: enqueue a ledger entry; the outbox row is durable in Drift,
      // the gateway has not seen it.
      await h.facade.enqueueLedgerEntry({
        'ulid': '01HXYZ-LEDGER-1',
        'curriculum_id': 'mishnayos',
        'unit_identifier': 'Mishnah_Berakhot_1',
      });

      var rows = await h.db.outboxDao.getPendingByKind(
        OutboxEntityKind.learningLedgerEntry,
        1,
      );
      expect(rows, hasLength(1));
      expect(h.gateway.ledgerPushes, isEmpty);

      // ONLINE: drain runs the gateway. The row should now have landed.
      h.gateway.offline = false;
      final pushed = await h.processor.drain(1);

      expect(pushed, greaterThanOrEqualTo(1));
      expect(h.gateway.ledgerPushes, hasLength(1));
      rows = await h.db.outboxDao.getPendingByKind(
        OutboxEntityKind.learningLedgerEntry,
        1,
      );
      expect(rows, isEmpty, reason: 'pushed row deleted from outbox');
    });

    test('notification settings: write offline → outbox row → drain online → '
        'gateway received', () async {
      final h = await _Harness.create();
      addTearDown(h.close);

      await h.facade.enqueueNotificationSettings({
        'schema_version': 1,
        'updated_at': '2026-05-21T10:00:00.000Z',
      });

      var rows = await h.db.outboxDao.getPendingByKind(
        OutboxEntityKind.notificationSettings,
        1,
      );
      expect(rows, hasLength(1));
      expect(h.gateway.notificationPushes, isEmpty);

      h.gateway.offline = false;
      await h.processor.drain(1);

      expect(h.gateway.notificationPushes, hasLength(1));
      rows = await h.db.outboxDao.getPendingByKind(
        OutboxEntityKind.notificationSettings,
        1,
      );
      expect(rows, isEmpty);
    });

    test('profile program: write offline → outbox row → drain online → '
        'gateway received', () async {
      final h = await _Harness.create();
      addTearDown(h.close);

      await h.facade.enqueueProfileProgram({
        'profile_id': 1,
        'curriculum_id': 'mishnayos',
        'program_id': 42,
        'tracking_start_date': '2026-05-21T00:00:00.000Z',
      });

      var rows = await h.db.outboxDao.getPendingByKind(
        OutboxEntityKind.profileProgram,
        1,
      );
      expect(rows, hasLength(1));
      expect(h.gateway.profileProgramPushes, isEmpty);

      h.gateway.offline = false;
      await h.processor.drain(1);

      expect(h.gateway.profileProgramPushes, hasLength(1));
      rows = await h.db.outboxDao.getPendingByKind(
        OutboxEntityKind.profileProgram,
        1,
      );
      expect(rows, isEmpty);
    });

    test('bookmark on track create: write offline → outbox row → '
        'drain online → gateway received', () async {
      final h = await _Harness.create();
      addTearDown(h.close);

      await h.facade.pushBookmark({
        'curriculum_id': 'mishnayos',
        'track_type': 'personal',
        'content_item_id': 'Mishnah_Berakhot_1',
        'updated_at': '2026-05-21T10:00:00.000Z',
      });

      var rows = await h.db.outboxDao.getPendingByKind(
        OutboxEntityKind.bookmark,
        1,
      );
      expect(rows, hasLength(1));
      expect(h.gateway.bookmarkPushes, isEmpty);

      h.gateway.offline = false;
      await h.processor.drain(1);

      expect(h.gateway.bookmarkPushes, hasLength(1));
      rows = await h.db.outboxDao.getPendingByKind(
        OutboxEntityKind.bookmark,
        1,
      );
      expect(rows, isEmpty);
    });
  });
}
