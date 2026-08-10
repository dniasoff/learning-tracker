/// Regression test: `deleteLearnerProfile` must enqueue its outbox row under
/// profile 0 (the account-level sweep), NOT under the profile being deleted.
///
/// The OutboxProcessor's `_doDrain(activeProfile)` only sweeps the active
/// profile AND profile 0. A profile-delete stamped with the TARGET profile id
/// is orphaned: once the user switches away from that profile (or it is gone),
/// no drain ever targets it, so the deletion never reaches the cloud and the
/// row lingers forever. (Found on-device 2026-06-01 — a `learner_profile_delete`
/// row stranded under profile_id 2 while the active profile was 4.)
///
/// The CF still targets `payload['profile_id']`, so re-homing the ROW to
/// profile 0 deletes the correct profile.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';

import '../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int activeProfileId;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    activeProfileId = (await db.select(db.learnerProfiles).get()).first.id;
  });

  tearDown(() async => db.close());

  test(
    'deleteLearnerProfile enqueues under profile 0 (not the target profile) so '
    'the account-level sweep always drains it; payload keeps the target id',
    () async {
      final facade = OutboxSyncWriteFacade(
        outboxDao: db.outboxDao,
        database: db,
        resolveProfileId: () => activeProfileId,
        clock: FakeLocalDayClock(DateTime.utc(2026, 6, 1)),
      );

      // Delete a DIFFERENT profile than the active one — the orphan scenario.
      const targetProfileUlid = '01TESTPROFILEULID000000000';
      // Outbox routing id for the target profile's lane (not the active profile).
      // 999 was the original value before the type migration.
      const targetProfileOutboxId = 999;
      await facade.deleteLearnerProfile(targetProfileUlid);

      // The row is swept by the profile-0 account-level drain...
      final profile0Rows = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.learnerProfileDelete,
        0,
      );
      expect(
        profile0Rows,
        hasLength(1),
        reason: 'profile-delete must be enqueued under profile 0',
      );

      // ...and NOT stranded under the target (or active) profile.
      final targetRows = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.learnerProfileDelete,
        targetProfileOutboxId,
      );
      expect(targetRows, isEmpty, reason: 'must not orphan under target id');
      final activeRows = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.learnerProfileDelete,
        activeProfileId,
      );
      expect(activeRows, isEmpty, reason: 'must not orphan under active id');

      // The payload still names the correct profile for the CF to delete.
      expect(profile0Rows.single.entityKey, targetProfileUlid);
      expect(
        profile0Rows.single.payload,
        contains('"profile_id":"$targetProfileUlid"'),
      );
    },
  );
}
