import 'package:drift/drift.dart' hide isNotNull, isNull;
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

  StreakEventsCompanion makeEvent({
    int profileId = 1,
    String eventType = 'completion',
    DateTime? dayUtc,
    DateTime? eventTimestamp,
    String? clientDeviceId,
  }) {
    final day = dayUtc ?? DateTime.utc(2026, 5, 13);
    return StreakEventsCompanion.insert(
      profileId: profileId,
      eventType: eventType,
      dayUtc: day,
      eventTimestamp: eventTimestamp ?? day,
      clientDeviceId: Value(clientDeviceId),
    );
  }

  group('StreakEventDao', () {
    group('appendEvent', () {
      test('inserts an event and returns its id', () async {
        final id = await db.streakEventDao.appendEvent(makeEvent());
        expect(id, greaterThan(0));

        final rows = await db.select(db.streakEvents).get();
        expect(rows, hasLength(1));
        expect(rows.first.profileId, 1);
        expect(rows.first.eventType, 'completion');
      });

      test('is idempotent on the natural key (profileId, dayUtc, eventType)', () async {
        final id1 = await db.streakEventDao.appendEvent(makeEvent());
        final id2 = await db.streakEventDao.appendEvent(makeEvent());

        // Same natural key — should collapse to one row.
        final rows = await db.select(db.streakEvents).get();
        expect(rows, hasLength(1));
        // Both calls return the same row id.
        expect(id1, id2);
      });

      test('allows different dayUtc to produce separate rows', () async {
        await db.streakEventDao.appendEvent(
          makeEvent(dayUtc: DateTime.utc(2026, 5, 13)),
        );
        await db.streakEventDao.appendEvent(
          makeEvent(dayUtc: DateTime.utc(2026, 5, 14)),
        );

        final rows = await db.select(db.streakEvents).get();
        expect(rows, hasLength(2));
      });

      test('allows different eventType on same day to produce separate rows', () async {
        await db.streakEventDao.appendEvent(
          makeEvent(eventType: 'completion'),
        );
        await db.streakEventDao.appendEvent(
          makeEvent(eventType: 'day_boundary'),
        );

        final rows = await db.select(db.streakEvents).get();
        expect(rows, hasLength(2));
      });
    });

    group('getEventsByProfile', () {
      test('returns empty list when no events exist for the profile', () async {
        final events = await db.streakEventDao.getEventsByProfile(1);
        expect(events, isEmpty);
      });

      test('returns only events for the requested profile', () async {
        await db.streakEventDao.appendEvent(makeEvent(profileId: 1));
        await db.streakEventDao.appendEvent(
          makeEvent(profileId: 2, dayUtc: DateTime.utc(2026, 5, 14)),
        );

        final events = await db.streakEventDao.getEventsByProfile(1);
        expect(events, hasLength(1));
        expect(events.first.profileId, 1);
      });

      test('orders events by eventTimestamp ascending', () async {
        final t1 = DateTime.utc(2026, 5, 13, 8, 0);
        final t2 = DateTime.utc(2026, 5, 14, 8, 0);

        await db.streakEventDao.appendEvent(
          makeEvent(dayUtc: DateTime.utc(2026, 5, 14), eventTimestamp: t2),
        );
        await db.streakEventDao.appendEvent(
          makeEvent(dayUtc: DateTime.utc(2026, 5, 13), eventTimestamp: t1),
        );

        final events = await db.streakEventDao.getEventsByProfile(1);
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
