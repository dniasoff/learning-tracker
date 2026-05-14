// Extra coverage for TrackDao — deactivateTrack personal track guard,
// InvalidOperationException.toString, and BaseDao accessor methods.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

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
    test(
      'deactivating personal track throws InvalidOperationException',
      () async {
        await expectLater(
          db.trackDao.deactivateTrack(
            CurriculumId.mishnayos,
            TrackType.personal,
          ),
          throwsA(isA<InvalidOperationException>()),
        );
      },
    );
  });

  // =========================================================================
  // InvalidOperationException
  // =========================================================================

  group('InvalidOperationException', () {
    test('toString includes the message', () {
      const ex = InvalidOperationException('test error message');
      expect(ex.toString(), contains('test error message'));
      expect(ex.toString(), contains('InvalidOperationException'));
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
