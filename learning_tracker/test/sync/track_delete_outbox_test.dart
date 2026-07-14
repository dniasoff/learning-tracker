/// I-5: soft-delete enqueues a track_delete outbox row for push.
///
/// Split out of the former `test/sync/two_device_sync_test.dart`
/// (AUD-t-cross-42): that file's S1/S3 scenarios hand-decoded outbox JSON
/// and called DAOs directly, bypassing MergeRouter/CompletionEventMerger —
/// duplicating, with lower fidelity, what `test/integration/two_device_sync_test.dart`
/// already covers end-to-end through the real merge stack. This scenario
/// (`deleteTrackAndData` enqueuing a `track_delete` outbox row) is not
/// covered there, so it moves here under its own name rather than share a
/// filename with the merge-router-driven integration test.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

import '../helpers/drift_memory.dart' show inMemoryDb, seedProfile;

void main() {
  late UserDatabase deviceA;

  setUp(() async {
    deviceA = inMemoryDb();
    await seedProfile(deviceA);
  });

  tearDown(() async {
    await deviceA.close();
  });

  test('I-5: deleteTrackAndData enqueues a track_delete outbox row', () async {
    final trackId = await deviceA.trackDao.restoreOrCreate(
      profileId: 1,
      curriculumId: CurriculumId.mishnayos,
    );

    await deviceA.trackDao.deleteTrackAndData(trackId);

    final outboxRows = await deviceA.outboxDao.getPendingByKind('track', 1);
    expect(
      outboxRows.any((r) => r.entityKey.contains('track_delete')),
      isTrue,
      reason:
          'I-5: soft-delete must enqueue track_delete so remote devices sync',
    );
  });
}
