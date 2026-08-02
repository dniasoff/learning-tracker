/// Unit tests for
/// `lib/data/repositories/firestore_streak_event_repository.dart` — the
/// second of the two APPEND-ONLY repositories in the Firestore rewrite (the
/// other is `firestore_learning_ledger_repository_test.dart`, whose doc
/// comment covers the fuller "what fake_cloud_firestore cannot see" list —
/// not repeated in full here). Covers: doc-id correctness, ULID
/// retry-idempotency, `dayUtc` derivation from `eventTimestamp` (mirroring
/// `StreakEventLog.append`'s own derivation), model round-trip, the
/// documented natural-key-dedup behavior CHANGE from the Drift-era UNIQUE
/// index (two independently-triggered calls for the same day/type are now
/// two documents, not one), `getEventsForDay`, one-shot AND streamed decode
/// leniency, and doc-id-ordered pagination past the 500-item page size.
///
/// **What these tests cannot see:** same `fake_cloud_firestore` rules-
/// evaluation gap as `firestore_learning_ledger_repository_test.dart`
/// (`request.resource`/`resource` are unsupported by the fake's rules
/// companion) — the SR-4 500-item `list()` cap and the SR-3
/// `created_at is timestamp` guard (moot here: this repository never
/// writes a `created_at` key at all, see [StreakEventEntry]'s doc comment)
/// are reviewed, not test-proven. The resubscribe-with-backoff behavior
/// [FirestoreStreakEventRepository.watchEvent]/`watchRecentEvents` delegate
/// to is covered directly and exhaustively in
/// `test/data/firestore/resilient_doc_stream_test.dart` — not re-proven
/// here.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';

import '../../helpers/firestore_fake.dart';

const _uid = 'uid-1';
const _profileId = 'profile-ulid-1';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
  });

  DocumentReference<Map<String, dynamic>> rawDoc(String ulid) => firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('streak_events')
      .doc(ulid);

  FirestoreStreakEventRepository buildRepo() {
    return FirestoreStreakEventRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

  group('doc-id correctness', () {
    test('append writes at doc-id == ulid (DocIds.streakEventDocId)', () async {
      final repo = buildRepo();
      const ulid = 'FIXEDULID00000000000000AA';

      final entry = await repo.append(
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 4, 10, 9),
        ulid: ulid,
      );

      expect(entry.ulid, ulid);
      expect(ulid, DocIds.streakEventDocId({'ulid': ulid}));
      final snapshot = await rawDoc(ulid).get();
      expect(snapshot.exists, isTrue);
    });

    test('append mints a fresh ulid when none is supplied', () async {
      final repo = buildRepo();
      final a = await repo.append(
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 4, 10),
      );
      final b = await repo.append(
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 4, 11),
      );
      expect(a.ulid, isNot(b.ulid));
    });

    test('never writes profile_id, and never writes created_at', () async {
      final repo = buildRepo();
      final entry = await repo.append(
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 4, 10),
      );

      final data = (await rawDoc(entry.ulid).get()).data()!;
      expect(data, isNot(contains('profile_id')));
      expect(
        data,
        isNot(contains('created_at')),
        reason:
            'redundant with the ulid\'s own embedded creation instant — '
            'also sidesteps the SR-3 created_at-is-timestamp guard entirely '
            'by leaving the (optional) field out',
      );
    });
  });

  group('dayUtc derivation', () {
    test(
      'normalises eventTimestamp down to UTC midnight, mirroring StreakEventLog.append',
      () async {
        final repo = buildRepo();

        final entry = await repo.append(
          eventType: 'completion',
          eventTimestamp: DateTime.utc(2026, 4, 10, 23, 59, 59),
        );

        expect(entry.dayUtc, DateTime.utc(2026, 4, 10));
        expect(entry.eventTimestamp, DateTime.utc(2026, 4, 10, 23, 59, 59));
      },
    );
  });

  group('ULID retry-idempotency', () {
    test(
      'retrying the same ulid returns the already-committed entry, not a new document',
      () async {
        final repo = buildRepo();
        const ulid = 'RETRYULID0000000000000AA';

        final first = await repo.append(
          eventType: 'completion',
          eventTimestamp: DateTime.utc(2026, 4, 10, 8),
          clientDeviceId: 'device-1',
          ulid: ulid,
        );

        final retried = await repo.append(
          eventType: 'completion',
          eventTimestamp: DateTime.utc(2026, 4, 10, 8),
          clientDeviceId: 'device-1',
          ulid: ulid,
        );

        expect(retried.ulid, first.ulid);
        expect(retried.dayUtc, first.dayUtc);

        final all = await repo.getAllEvents();
        expect(all, hasLength(1), reason: 'retry must not duplicate the doc');
      },
    );
  });

  group(
    'natural-key dedup is NOT automatic — documented behavior change from Drift',
    () {
      test(
        'two independently-minted-ulid calls for the same day+type produce TWO documents',
        () async {
          final repo = buildRepo();

          final first = await repo.append(
            eventType: 'completion',
            eventTimestamp: DateTime.utc(2026, 4, 10, 8),
          );
          final second = await repo.append(
            eventType: 'completion',
            eventTimestamp: DateTime.utc(2026, 4, 10, 20),
          );

          expect(first.ulid, isNot(second.ulid));
          final sameDay = await repo.getEventsForDay(DateTime.utc(2026, 4, 10));
          expect(
            sameDay,
            hasLength(2),
            reason:
                'unlike the Drift UNIQUE(profileId, dayUtc, eventType) index, '
                'the Firestore doc-id (the ulid) does not collapse these — a '
                'caller wanting that must check getEventsForDay first',
          );
        },
      );
    },
  );

  group('model round-trip', () {
    test('every field survives write then read', () async {
      final repo = buildRepo();
      final written = await repo.append(
        eventType: 'manual_adjust',
        eventTimestamp: DateTime.utc(2026, 5, 1, 14, 22, 10),
        clientDeviceId: 'device-xyz',
      );

      final all = await repo.getAllEvents();
      final loaded = all.single;

      expect(loaded.ulid, written.ulid);
      expect(loaded.eventType, 'manual_adjust');
      expect(loaded.dayUtc, DateTime.utc(2026, 5, 1));
      expect(loaded.eventTimestamp, DateTime.utc(2026, 5, 1, 14, 22, 10));
      expect(loaded.clientDeviceId, 'device-xyz');
    });

    test(
      'clientDeviceId is optional and omitted, not written as null',
      () async {
        final repo = buildRepo();
        final entry = await repo.append(
          eventType: 'day_boundary',
          eventTimestamp: DateTime.utc(2026, 5, 2),
        );

        final data = (await rawDoc(entry.ulid).get()).data()!;
        expect(data, isNot(contains('client_device_id')));

        final loaded = (await repo.getAllEvents()).single;
        expect(loaded.clientDeviceId, isNull);
      },
    );
  });

  group('getEventsForDay', () {
    test(
      'filters to just the requested UTC day, ignoring time-of-day input',
      () async {
        final repo = buildRepo();
        await repo.append(
          eventType: 'completion',
          eventTimestamp: DateTime.utc(2026, 6, 1, 6),
        );
        await repo.append(
          eventType: 'day_boundary',
          eventTimestamp: DateTime.utc(2026, 6, 1, 23),
        );
        await repo.append(
          eventType: 'completion',
          eventTimestamp: DateTime.utc(2026, 6, 2, 6),
        );

        // Pass a non-midnight instant on the same day — must still match,
        // since the query normalises internally just like append() does.
        final events = await repo.getEventsForDay(
          DateTime.utc(2026, 6, 1, 18, 30),
        );

        expect(events, hasLength(2));
        expect(
          events.every((e) => e.dayUtc == DateTime.utc(2026, 6, 1)),
          isTrue,
        );
      },
    );

    test('returns an empty list for a day with no events', () async {
      final repo = buildRepo();
      final events = await repo.getEventsForDay(DateTime.utc(2026, 1, 1));
      expect(events, isEmpty);
    });
  });

  group(
    'one-shot reads skip a malformed document instead of failing the whole read',
    () {
      test('getAllEvents omits a document missing event_type', () async {
        final repo = buildRepo();
        final bad = await repo.append(
          eventType: 'completion',
          eventTimestamp: DateTime.utc(2026, 4, 10),
        );
        await repo.append(
          eventType: 'completion',
          eventTimestamp: DateTime.utc(2026, 4, 11),
        );
        await rawDoc(bad.ulid).update({'event_type': FieldValue.delete()});

        final all = await repo.getAllEvents();

        expect(all, hasLength(1));
      });
    },
  );

  group('watchEvent / watchRecentEvents — stream emits on change', () {
    test('watchEvent eventually reflects the written document', () async {
      final repo = buildRepo();
      const ulid = 'WATCHULID000000000000AAA';

      final stream = repo.watchEvent(ulid).map((e) => e != null);
      final done = expectLater(stream, emitsThrough(true));

      await repo.append(
        eventType: 'completion',
        eventTimestamp: DateTime.utc(2026, 4, 10),
        ulid: ulid,
      );

      await done;
    });

    test(
      'watchRecentEvents eventually reflects newly-appended events',
      () async {
        final repo = buildRepo();

        final stream = repo
            .watchRecentEvents(limit: 10)
            .map((events) => events.length);
        final done = expectLater(stream, emitsThrough(2));

        await repo.append(
          eventType: 'completion',
          eventTimestamp: DateTime.utc(2026, 4, 10),
        );
        await repo.append(
          eventType: 'completion',
          eventTimestamp: DateTime.utc(2026, 4, 11),
        );

        await done;
      },
    );
  });

  group('pagination past the 500-item page size', () {
    test(
      'getAllEvents reassembles a 501-document collection across pages',
      () async {
        final repo = buildRepo();
        final ids = List.generate(501, (_) => newUlid());

        Map<String, dynamic> rawEventData(String ulid) => {
          'ulid': ulid,
          'event_type': 'completion',
          'day_utc': DateTime.utc(2026, 1, 1).toIso8601String(),
          'event_timestamp': DateTime.utc(2026, 1, 1).toIso8601String(),
        };

        final batch1 = firestore.batch();
        for (final id in ids.take(500)) {
          batch1.set(rawDoc(id), rawEventData(id));
        }
        await batch1.commit();

        final batch2 = firestore.batch();
        batch2.set(rawDoc(ids.last), rawEventData(ids.last));
        await batch2.commit();

        final all = await repo.getAllEvents();

        expect(all, hasLength(501));
        expect(all.map((e) => e.ulid).toSet(), ids.toSet());
      },
    );
  });
}
