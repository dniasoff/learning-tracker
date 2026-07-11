/// Tests for [OutboxSyncWriteFacade] — AUD-sync-03 (EH-3) and AUD-sync-05
/// (SM-7).
///
/// [OutboxSyncWriteFacade._enqueue] fires the injected `onEnqueueDrain`
/// write-tee fire-and-forget after every enqueue. Before this fix, any
/// exception from that tee vanished into a log-less `catchError` with no
/// way to trace it (the class had no `AppLogger` field at all). This suite
/// asserts a thrown drain-tee exception is now logged via [AppLogger].
///
/// AUD-sync-05: [buildGamificationSnapshot] constructed its
/// [RewardMilestoneService] inline, so a test could not substitute a fake
/// without also faking the whole Drift database it reads. The constructor
/// now takes an optional `rewardMilestoneServiceFactory` seam — asserted
/// below.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/log_events.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

import '../../../helpers/drift_memory.dart';

const _profileId = 1;

/// Fake [RewardMilestoneService] that skips the real SharedPreferences /
/// Drift-backed export logic so the test can assert on a value that could
/// only have come from the injected factory, not from a real service.
class _FakeRewardMilestoneService extends RewardMilestoneService {
  _FakeRewardMilestoneService(super.database, {required super.profileId});

  @override
  Future<Map<String, dynamic>> exportCloudPayload() async {
    return {'source': 'fake', 'profile_id_seen': profileId};
  }
}

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

  group(
    'OutboxSyncWriteFacade — rewardMilestoneServiceFactory (AUD-sync-05)',
    () {
      test('buildGamificationSnapshot uses the injected '
          'rewardMilestoneServiceFactory, called with the live-resolved '
          'profile id', () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        await seedProfile(db);

        final seenProfileIds = <int>[];
        final facade = OutboxSyncWriteFacade(
          outboxDao: db.outboxDao,
          database: db,
          resolveProfileId: () => _profileId,
          clock: FakeLocalDayClock(DateTime.utc(2026, 5, 29)),
          rewardMilestoneServiceFactory: (profileId) {
            seenProfileIds.add(profileId);
            return _FakeRewardMilestoneService(db, profileId: profileId);
          },
        );

        final snapshot = await facade.buildGamificationSnapshot();

        expect(
          seenProfileIds,
          [_profileId],
          reason:
              'the factory must be called exactly once, with the '
              'live-resolved profile id',
        );
        expect(snapshot['reward_settings'], {
          'source': 'fake',
          'profile_id_seen': _profileId,
        });
      });

      test(
        'without an injected factory, buildGamificationSnapshot falls back '
        'to a real RewardMilestoneService (production default unchanged)',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final db = inMemoryDb();
          addTearDown(db.close);
          await seedProfile(db);

          final facade = OutboxSyncWriteFacade(
            outboxDao: db.outboxDao,
            database: db,
            resolveProfileId: () => _profileId,
            clock: FakeLocalDayClock(DateTime.utc(2026, 5, 29)),
          );

          final snapshot = await facade.buildGamificationSnapshot();

          // Real RewardMilestoneService.exportCloudPayload shape — proves the
          // default factory still builds the genuine service.
          expect(snapshot['reward_settings'], isA<Map<String, dynamic>>());
          final rewardSettings =
              snapshot['reward_settings'] as Map<String, dynamic>;
          expect(rewardSettings.containsKey('milestones'), isTrue);
          expect(rewardSettings.containsKey('unlocks'), isTrue);
        },
      );
    },
  );
}
