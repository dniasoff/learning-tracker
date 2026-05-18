/// Tests for OfflineQueue enqueue methods and queue management.
///
/// These tests exercise the enqueue* methods, getPendingCount, and clearAll
/// using a real in-memory UserDatabase but a mock FirestoreDataSource so that
/// no real Firestore connections are opened.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:mocktail/mocktail.dart';
import 'package:talker/talker.dart';

import '../../../helpers/drift_memory.dart';

class _MockFirestoreGateway extends Mock implements FirestoreGateway {}

void main() {
  late UserDatabase db;
  late _MockFirestoreGateway mockGateway;
  late OfflineQueue queue;

  setUp(() {
    db = inMemoryDb();
    mockGateway = _MockFirestoreGateway();

    queue = OfflineQueue(
      database: db,
      firestoreGateway: mockGateway,
      logger: AppLogger(Talker()),
    );
  });

  tearDown(() async {
    await db.close();
  });

  // ── initial state ──────────────────────────────────────────────────────────

  test('getPendingCount is 0 for an empty queue', () async {
    final count = await queue.getPendingCount();
    expect(count, 0);
  });

  // ── enqueueBookmark ────────────────────────────────────────────────────────

  group('enqueueBookmark', () {
    test('adds one item to the queue', () async {
      await queue.enqueueBookmark({'curriculum_id': 'mishnayos'});
      expect(await queue.getPendingCount(), 1);
    });

    test('stores operationType = bookmark', () async {
      await queue.enqueueBookmark({'curriculum_id': 'mishnayos'});
      final items = await db.syncQueueDao.getAllPending();
      expect(items.first.operationType, 'bookmark');
    });
  });

  // ── enqueueSettings ────────────────────────────────────────────────────────

  test('enqueueSettings stores operationType = settings', () async {
    await queue.enqueueSettings({'key': 'value'});
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'settings');
  });

  // ── enqueueNotificationSettings ───────────────────────────────────────────

  test('enqueueNotificationSettings stores correct operationType', () async {
    await queue.enqueueNotificationSettings({'enabled': true});
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'notification_settings');
  });

  // ── enqueueGamificationSettings ───────────────────────────────────────────

  test('enqueueGamificationSettings stores correct operationType', () async {
    await queue.enqueueGamificationSettings({'points': 100});
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'gamification_settings');
  });

  // ── enqueueUiPreferences ──────────────────────────────────────────────────

  test('enqueueUiPreferences stores correct operationType', () async {
    await queue.enqueueUiPreferences({'locale': 'en'});
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'ui_preferences');
  });

  // ── enqueueStreak ─────────────────────────────────────────────────────────

  test('enqueueStreak stores correct operationType', () async {
    await queue.enqueueStreak({'current_streak': 7});
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'streak');
  });

  // ── enqueueProfile ────────────────────────────────────────────────────────

  test('enqueueProfile stores correct operationType', () async {
    await queue.enqueueProfile({'display_name': 'Alice'});
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'profile');
  });

  // ── enqueueLearnerProfile ─────────────────────────────────────────────────

  test('enqueueLearnerProfile stores correct operationType', () async {
    await queue.enqueueLearnerProfile({'profile_id': 1});
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'learner_profile');
  });

  // ── enqueueLearnerProfileDelete ───────────────────────────────────────────

  test('enqueueLearnerProfileDelete stores correct operationType', () async {
    await queue.enqueueLearnerProfileDelete(99);
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'learner_profile_delete');
  });

  // ── enqueueGoal ───────────────────────────────────────────────────────────

  test('enqueueGoal stores correct operationType', () async {
    await queue.enqueueGoal({'curriculum_id': 'mishnayos'});
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'goal');
  });

  // ── enqueueProfileProgram ─────────────────────────────────────────────────

  test('enqueueProfileProgram stores correct operationType', () async {
    await queue.enqueueProfileProgram({
      'curriculum_id': 'mishnayos',
      'program_id': 1,
    });
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'profile_program');
  });

  // ── enqueueProfileProgramDelete ───────────────────────────────────────────

  test('enqueueProfileProgramDelete stores correct operationType', () async {
    await queue.enqueueProfileProgramDelete({'curriculum_id': 'mishnayos'});
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'profile_program_delete');
  });

  // ── enqueueLedgerEntry ────────────────────────────────────────────────────

  test('enqueueLedgerEntry stores correct operationType', () async {
    await queue.enqueueLedgerEntry({'unit_id': 'berakhot_1'});
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'ledger_entry');
  });

  // ── enqueueCurriculumImportMetadata ───────────────────────────────────────

  test(
    'enqueueCurriculumImportMetadata stores correct operationType',
    () async {
      await queue.enqueueCurriculumImportMetadata({
        'curriculum_id': 'mishnayos',
      });
      final items = await db.syncQueueDao.getAllPending();
      expect(items.first.operationType, 'curriculum_import_metadata');
    },
  );

  // ── enqueueCurriculumTrack ────────────────────────────────────────────────

  test('enqueueCurriculumTrack stores correct operationType', () async {
    await queue.enqueueCurriculumTrack({
      'curriculum_id': 'mishnayos',
      'track_type': 'personal',
    });
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'curriculum_track');
  });

  // ── enqueueLearningOrderItem ──────────────────────────────────────────────

  test('enqueueLearningOrderItem stores correct operationType', () async {
    await queue.enqueueLearningOrderItem({
      'curriculum_id': 'mishnayos',
      'sefaria_ref': 'Berakhot',
    });
    final items = await db.syncQueueDao.getAllPending();
    expect(items.first.operationType, 'learning_order_item');
  });

  // ── multiple enqueues ─────────────────────────────────────────────────────

  test('multiple enqueues accumulate in FIFO order', () async {
    await queue.enqueueGoal({'id': 'a'});
    await queue.enqueueBookmark({'ref': 'b'});
    await queue.enqueueStreak({'current': 5});

    expect(await queue.getPendingCount(), 3);

    final items = await db.syncQueueDao.getAllPending();
    expect(items[0].operationType, 'goal');
    expect(items[1].operationType, 'bookmark');
    expect(items[2].operationType, 'streak');
  });

  // ── clearAll ──────────────────────────────────────────────────────────────

  group('clearAll', () {
    test('empties the queue', () async {
      await queue.enqueueGoal({'id': '1'});
      await queue.enqueueBookmark({'ref': '2'});
      expect(await queue.getPendingCount(), 2);

      await queue.clearAll();

      expect(await queue.getPendingCount(), 0);
    });

    test('clearAll on empty queue is a no-op', () async {
      await queue.clearAll();
      expect(await queue.getPendingCount(), 0);
    });
  });

  // ── flush with empty queue ────────────────────────────────────────────────

  test('flush on empty queue returns 0 without touching gateway', () async {
    final count = await queue.flush();
    expect(count, 0);
    verifyNever(
      () => mockGateway.pushBookmark(
        profileId: any(named: 'profileId'),
        data: any(named: 'data'),
      ),
    );
  });
}
