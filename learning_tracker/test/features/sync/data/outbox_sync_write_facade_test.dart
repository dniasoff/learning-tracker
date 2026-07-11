/// Tests for [OutboxSyncWriteFacade] — AUD-sync-03 (EH-3).
///
/// [OutboxSyncWriteFacade._enqueue] fires the injected `onEnqueueDrain`
/// write-tee fire-and-forget after every enqueue. Before this fix, any
/// exception from that tee vanished into a log-less `catchError` with no
/// way to trace it (the class had no `AppLogger` field at all). This suite
/// asserts a thrown drain-tee exception is now logged via [AppLogger].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/log_events.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:talker/talker.dart';

import '../../../helpers/drift_memory.dart';

const _profileId = 1;

void main() {
  group('OutboxSyncWriteFacade — drain-tee failure logging (AUD-sync-03)', () {
    test('a thrown onEnqueueDrain exception is logged via AppLogger, not '
        'silently swallowed', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);

      final talker = Talker();
      final logger = AppLogger(talker);
      final historyBefore = talker.history.length;

      final facade = OutboxSyncWriteFacade(
        outboxDao: db.outboxDao,
        database: db,
        resolveProfileId: () => _profileId,
        clock: FakeLocalDayClock(DateTime.utc(2026, 5, 29)),
        logger: logger,
        onEnqueueDrain: () async {
          throw Exception('simulated drain-tee failure');
        },
      );

      await facade.pushSettings({'curriculum_id': 'mishnayos'});

      // The tee is fire-and-forget (unawaited) — pump the microtask queue
      // so the catchError handler has run before asserting on it.
      await Future<void>.delayed(Duration.zero);

      expect(
        talker.history.length,
        greaterThan(historyBefore),
        reason: 'the drain-tee failure must be logged, not swallowed',
      );
      final lastMessage = talker.history.last.generateTextMessage();
      expect(lastMessage, contains(LogEvents.sync.outboxEnqueueDrainTeeFailed));
    });

    test(
      'a successful onEnqueueDrain does not log a drain-tee failure event',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final talker = Talker();
        final logger = AppLogger(talker);

        var drainCalls = 0;
        final facade = OutboxSyncWriteFacade(
          outboxDao: db.outboxDao,
          database: db,
          resolveProfileId: () => _profileId,
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 29)),
          logger: logger,
          onEnqueueDrain: () async {
            drainCalls++;
          },
        );

        await facade.pushSettings({'curriculum_id': 'mishnayos'});
        await Future<void>.delayed(Duration.zero);

        expect(drainCalls, 1);
        expect(
          talker.history.any(
            (e) => e.generateTextMessage().contains(
              LogEvents.sync.outboxEnqueueDrainTeeFailed,
            ),
          ),
          isFalse,
        );
      },
    );
  });
}
