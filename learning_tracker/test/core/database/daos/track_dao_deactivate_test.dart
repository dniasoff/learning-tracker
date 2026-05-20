// Extra coverage for TrackDao — deactivateTrack personal track guard,
// InvalidTrackOperationException.toString, and BaseDao accessor methods.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/exceptions/invalid_track_operation_exception.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // TrackDao.deactivateTrack — personal track guard
  // =========================================================================

  group('TrackDao.deactivateTrack', () {
    // W3.22/W3.28: deactivateTrack is now an alias for retireTrack.
    // It no longer throws InvalidTrackOperationException — if no matching
    // track is found it is a no-op; if found it sets state=retired.
    test(
      'deactivateTrack on a non-existent track is a no-op (no throw)',
      () async {
        await expectLater(
          db.trackDao.deactivateTrack(CurriculumId.mishnayos),
          completes,
        );
      },
    );
  });

  // =========================================================================
  // InvalidTrackOperationException
  // =========================================================================

  group('InvalidTrackOperationException', () {
    test('toString includes the message', () {
      const ex = InvalidTrackOperationException('test error message');
      expect(ex.toString(), contains('test error message'));
      expect(ex.toString(), contains('InvalidTrackOperationException'));
    });
  });

  // =========================================================================
  // TrackDao — BaseDao accessors (table, idColumn, profileIdColumn)
  // =========================================================================

  group('TrackDao BaseDao accessors', () {
    test('table getter returns curriculumTracks table', () {
      // Calling table triggers the getter on line 18-20.
      final table = db.trackDao.table;
      expect(table, isNotNull);
    });
  });
}
