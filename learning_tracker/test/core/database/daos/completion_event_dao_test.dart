import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  CompletionEventsCompanion makeEvent({
    int profileId = 1,
    String curriculumId = 'daf_yomi',
    String sefariaRef = 'Berakhot.2a',
    int stageId = 1,
    String trackType = 'personal',
    DateTime? eventTimestamp,
  }) {
    return CompletionEventsCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      sefariaRef: sefariaRef,
      stageId: stageId,
      trackType: trackType,
      eventTimestamp: eventTimestamp ?? DateTime.utc(2026, 5, 13, 12, 0),
    );
  }

  group('CompletionEventDao', () {
    group('appendEvent', () {
      test('inserts an event and returns its id', () async {
        final id = await db.completionEventDao.appendEvent(makeEvent());
        expect(id, greaterThan(0));

        final rows = await db.select(db.completionEvents).get();
        expect(rows, hasLength(1));
        expect(rows.first.profileId, 1);
        expect(rows.first.sefariaRef, 'Berakhot.2a');
      });

      test('is idempotent on the natural key '
          '(profileId, sefariaRef, stageId, trackType)', () async {
        final id1 = await db.completionEventDao.appendEvent(makeEvent());
        final id2 = await db.completionEventDao.appendEvent(makeEvent());

        // Same natural key — should collapse to one row.
        final rows = await db.select(db.completionEvents).get();
        expect(rows, hasLength(1));
        // Both calls return the same row id.
        expect(id1, id2);
      });

      test('allows different sefariaRef to produce separate rows', () async {
        await db.completionEventDao.appendEvent(
          makeEvent(sefariaRef: 'Berakhot.2a'),
        );
        await db.completionEventDao.appendEvent(
          makeEvent(sefariaRef: 'Berakhot.2b'),
        );

        final rows = await db.select(db.completionEvents).get();
        expect(rows, hasLength(2));
      });

      test('allows different trackType to produce separate rows', () async {
        await db.completionEventDao.appendEvent(
          makeEvent(trackType: 'personal'),
        );
        await db.completionEventDao.appendEvent(makeEvent(trackType: 'shared'));

        final rows = await db.select(db.completionEvents).get();
        expect(rows, hasLength(2));
      });
    });

    group('getEventsByProfile', () {
      test('returns empty list when no events exist for the profile', () async {
        final events = await db.completionEventDao.getEventsByProfile(1);
        expect(events, isEmpty);
      });

      test('returns only events for the requested profile', () async {
        await db.completionEventDao.appendEvent(makeEvent(profileId: 1));
        await db.completionEventDao.appendEvent(
          makeEvent(profileId: 2, sefariaRef: 'Berakhot.3a'),
        );

        final events = await db.completionEventDao.getEventsByProfile(1);
        expect(events, hasLength(1));
        expect(events.first.profileId, 1);
      });

      test('orders events by eventTimestamp ascending', () async {
        final t1 = DateTime.utc(2026, 5, 13, 8, 0);
        final t2 = DateTime.utc(2026, 5, 14, 8, 0);

        await db.completionEventDao.appendEvent(
          makeEvent(sefariaRef: 'Berakhot.3a', eventTimestamp: t2),
        );
        await db.completionEventDao.appendEvent(
          makeEvent(sefariaRef: 'Berakhot.2a', eventTimestamp: t1),
        );

        final events = await db.completionEventDao.getEventsByProfile(1);
        expect(events, hasLength(2));
        // First event should be earlier than the second.
        expect(
          events[0].eventTimestamp.isBefore(events[1].eventTimestamp),
          isTrue,
        );
      });
    });
  });
}
