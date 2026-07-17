/// `StreakService` tests — post-DNI-337 surface.
///
/// `recordCompletion` was removed by Story 25.16: streak state is derived
/// by `core/streak/StreakReducer` from the `streak_events` log, not
/// computed by an imperative service. The remaining `StreakService`
/// surface is the calendar helper, which is exercised here. The full
/// reducer / log / merger / round-trip path lives in
/// `test/story_acceptance/epic_25_story_16_streak_test.dart`.
library;

import 'package:drift/drift.dart' show Value;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/services/streak_service.dart';
import 'package:test/test.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/test_database.dart'
    show createTestDatabase, seedProfileZero;

void main() {
  late UserDatabase db;
  late StreakService service;
  late int trackId;

  setUp(() async {
    db = createTestDatabase();
    await seedProfileZero(
      db,
    ); // completions use profileId=0 (StreakService default)
    service = StreakService(db);

    final trackRow = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 0,
            curriculumId: 'test-curriculum',
            stateChangedAt: DateTime.now(),
            activatedAt: DateTime.now(),
          ),
        );
    trackId = trackRow.id;
  });

  tearDown(() async {
    await db.close();
  });

  var refCounter = 0;

  Future<void> addCompletion(UserDatabase db, DateTime completedAtUtc) async {
    // Each call uses a unique sefariaRef so the UNIQUE constraint on
    // completion_events(profileId, sefariaRef, stageId, trackType) does not
    // deduplicate completions from different dates.
    final ref = 'Genesis.${++refCounter}';
    await seedCompletion(
      db,
      CompletionEventsCompanion.insert(
        profileId: 0,
        curriculumId: 'test-curriculum',
        sefariaRef: ref,
        stageId: 1,
        trackType: 'primary',
        trackId: Value(trackId),
        eventTimestamp: completedAtUtc,
      ),
    );
  }

  group('StreakService.getStreakCalendar', () {
    test('returns correct set of active dates for date range', () async {
      await addCompletion(db, DateTimeFactory.utc(2026, 3, 10, 12));
      await addCompletion(db, DateTimeFactory.utc(2026, 3, 12, 8));
      await addCompletion(db, DateTimeFactory.utc(2026, 3, 12, 20));
      await addCompletion(db, DateTimeFactory.utc(2026, 3, 15, 12));

      final calendar = await service.getStreakCalendar(
        startUtc: DateTimeFactory.utc(2026, 3, 10),
        endUtc: DateTimeFactory.utc(2026, 3, 14),
      );

      // March 10 and 12 are in range; March 15 is not.
      expect(calendar.length, 2);
      expect(
        calendar.contains(
          LocalDayUtils.extractLocalDate(DateTimeFactory.utc(2026, 3, 10, 12)),
        ),
        isTrue,
      );
      expect(
        calendar.contains(
          LocalDayUtils.extractLocalDate(DateTimeFactory.utc(2026, 3, 12, 8)),
        ),
        isTrue,
      );
    });
  });
}
