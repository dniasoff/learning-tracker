/// Unit tests for
/// `lib/data/repositories/firestore_points_ledger_repository.dart` — the
/// third of the three APPEND-ONLY repositories in the Firestore rewrite
/// (the other two are `firestore_learning_ledger_repository_test.dart` and
/// `firestore_streak_event_repository_test.dart`, whose doc comments cover
/// the fuller "what fake_cloud_firestore cannot see" list — not repeated in
/// full here). Covers: doc-id correctness, ULID retry-idempotency,
/// entry-kind/delta round-trip, `source` decode defaults, one-shot decode
/// leniency, doc-id-ordered pagination past the 500-item page size, watch
/// streams, and — the behavior unique to this repository — the DERIVED,
/// CLAMPED, AD-50 filtered totals ([FirestorePointsLedgerRepository.getTotals]) and its
/// negative-raw-sum warning (owner decision 5,
/// `docs/firestore-rewrite-map.md`).
///
/// **What these tests cannot see:** same `fake_cloud_firestore` rules-
/// evaluation gap as the other two append-only repositories'
/// (`request.resource`/`resource` are unsupported by the fake's rules
/// companion) — the SR-4 500-item `list()` cap and the SR-3
/// `created_at is timestamp` guard are reviewed, not test-proven. The
/// resubscribe-with-backoff behavior [FirestorePointsLedgerRepository.watchEntry]
/// / `watchRecentLedgerEntries` delegate to is covered directly and
/// exhaustively in `test/data/firestore/resilient_doc_stream_test.dart` —
/// not re-proven here.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance and its own `Talker`/`AppLogger` pair.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:talker/talker.dart';

import '../../helpers/firestore_fake.dart';

const _uid = 'uid-1';
const _profileId = '01J0000000000000000000000P';

void main() {
  late FakeFirebaseFirestore firestore;
  late Talker talker;
  late AppLogger logger;

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    talker = Talker();
    logger = AppLogger(talker);
  });

  DocumentReference<Map<String, dynamic>> rawDoc(String ulid) => firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('points_ledger')
      .doc(ulid);

  Future<int> lifetime(FirestorePointsLedgerRepository repo) async =>
      (await repo.getTotals(earningEventIds: const {})).lifetimeEarned;

  /// Writes the AD-50 `pts_{eventId}` award of [eventId] as the capture
  /// batch does.
  Future<void> award(String eventId, int amount) => rawDoc('pts_$eventId').set({
    'ulid': 'pts_$eventId',
    'entry_kind': 'completion',
    'delta': amount,
    'created_at': DateTime.utc(2026, 6, 1),
    'source': 'live',
    'event_id': eventId,
  });

  FirestorePointsLedgerRepository buildRepo() {
    return FirestorePointsLedgerRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
      logger: logger,
    );
  }

  group('doc-id correctness', () {
    test(
      'append writes at doc-id == ulid (DocIds.pointsLedgerDocId)',
      () async {
        final repo = buildRepo();
        const ulid = 'FIXEDULID00000000000000AA';

        final entry = await repo.append(
          entryKind: 'completion',
          delta: 10,
          createdAt: DateTime.utc(2026, 4, 10, 9),
          ulid: ulid,
        );

        expect(entry.ulid, ulid);
        expect(ulid, DocIds.pointsLedgerDocId({'ulid': ulid}));
        final snapshot = await rawDoc(ulid).get();
        expect(snapshot.exists, isTrue);
      },
    );

    test('append mints a fresh ulid when none is supplied', () async {
      final repo = buildRepo();
      final a = await repo.append(
        entryKind: 'completion',
        delta: 5,
        createdAt: DateTime.utc(2026, 4, 10),
      );
      final b = await repo.append(
        entryKind: 'completion',
        delta: 5,
        createdAt: DateTime.utc(2026, 4, 11),
      );
      expect(a.ulid, isNot(b.ulid));
    });

    test('never writes profile_id', () async {
      final repo = buildRepo();
      final entry = await repo.append(
        entryKind: 'completion',
        delta: 5,
        createdAt: DateTime.utc(2026, 4, 10),
      );

      final data = (await rawDoc(entry.ulid).get()).data()!;
      expect(data, isNot(contains('profile_id')));
    });
  });

  group('ULID retry-idempotency', () {
    test('retrying the same ulid returns the already-committed entry, not a '
        'new document', () async {
      final repo = buildRepo();
      const ulid = 'RETRYULID0000000000000AA';

      final first = await repo.append(
        entryKind: 'parent_add',
        delta: 20,
        createdAt: DateTime.utc(2026, 4, 10, 8),
        note: 'Birthday bonus',
        ulid: ulid,
      );

      final retried = await repo.append(
        entryKind: 'parent_add',
        delta: 20,
        createdAt: DateTime.utc(2026, 4, 10, 8),
        note: 'Birthday bonus',
        ulid: ulid,
      );

      expect(retried.ulid, first.ulid);
      expect(retried.delta, first.delta);

      final all = await repo.getLedger();
      expect(all, hasLength(1), reason: 'retry must not duplicate the doc');
    });
  });

  group('entry-kind / delta round-trip', () {
    test('every field survives write then read', () async {
      final repo = buildRepo();
      final written = await repo.append(
        entryKind: 'redemption_debit',
        delta: -30,
        createdAt: DateTime.utc(2026, 5, 1, 14, 22, 10),
        note: 'Extra screen time',
        redemptionUlid: 'REDEMPTION0000000000000A',
        source: CompletionSource.live,
      );

      final all = await repo.getLedger();
      final loaded = all.single;

      expect(loaded.ulid, written.ulid);
      expect(loaded.entryKind, 'redemption_debit');
      expect(loaded.delta, -30);
      expect(loaded.note, 'Extra screen time');
      expect(loaded.redemptionUlid, 'REDEMPTION0000000000000A');
      expect(loaded.createdAt, DateTime.utc(2026, 5, 1, 14, 22, 10));
      expect(loaded.source, CompletionSource.live);
    });

    test(
      'note and redemptionUlid are optional and omitted, not written as null',
      () async {
        final repo = buildRepo();
        final entry = await repo.append(
          entryKind: 'completion',
          delta: 5,
          createdAt: DateTime.utc(2026, 5, 2),
        );

        final data = (await rawDoc(entry.ulid).get()).data()!;
        expect(data, isNot(contains('note')));
        expect(data, isNot(contains('redemption_ulid')));

        final loaded = (await repo.getLedger()).single;
        expect(loaded.note, isNull);
        expect(loaded.redemptionUlid, isNull);
      },
    );

    test(
      'source defaults to CompletionSource.live when not supplied',
      () async {
        final repo = buildRepo();
        final entry = await repo.append(
          entryKind: 'completion',
          delta: 5,
          createdAt: DateTime.utc(2026, 5, 2),
        );
        expect(entry.source, CompletionSource.live);

        final loaded = (await repo.getLedger()).single;
        expect(loaded.source, CompletionSource.live);
      },
    );

    test(
      'a document written with no source key decodes as CompletionSource.live '
      '(fail-safe default, e.g. a pre-existing doc predating the field)',
      () async {
        const ulid = 'NOSOURCEULID0000000000AA';
        await rawDoc(ulid).set({
          'ulid': ulid,
          'entry_kind': 'completion',
          'delta': 5,
          'created_at': DateTime.utc(2026, 5, 2),
        });

        final repo = buildRepo();
        final all = await repo.getLedger();
        expect(all.single.source, CompletionSource.live);
      },
    );
  });

  group('derived, clamped balance (owner decision 5)', () {
    test('getBalance sums every entry\'s delta', () async {
      final repo = buildRepo();
      await repo.append(
        entryKind: 'completion',
        delta: 10,
        createdAt: DateTime.utc(2026, 6, 1),
      );
      await repo.append(
        entryKind: 'completion',
        delta: 15,
        createdAt: DateTime.utc(2026, 6, 2),
      );
      await repo.append(
        entryKind: 'redemption_debit',
        delta: -5,
        createdAt: DateTime.utc(2026, 6, 3),
      );

      expect(await repo.getBalance(earningEventIds: const {}), 20);
    });

    test('getBalance returns 0 for a profile with no ledger entries', () async {
      final repo = buildRepo();
      expect(await repo.getBalance(earningEventIds: const {}), 0);
    });

    test(
      'getBalance clamps at 0 when deductions exceed credits (never negative)',
      () async {
        final repo = buildRepo();
        await repo.append(
          entryKind: 'completion',
          delta: 10,
          createdAt: DateTime.utc(2026, 6, 1),
        );
        // A deliberately over-large deduction — an app bug this repository
        // does not prevent (that guard lives above this layer), but the
        // derived balance must still never go negative on the child's screen.
        await repo.append(
          entryKind: 'parent_deduct',
          delta: -999,
          createdAt: DateTime.utc(2026, 6, 2),
        );

        expect(await repo.getBalance(earningEventIds: const {}), 0);
      },
    );

    test(
      'getBalance clamps at (1 << 30) on an implausibly large positive sum',
      () async {
        final repo = buildRepo();
        await repo.append(
          entryKind: 'parent_add',
          delta: (1 << 30) + 1000,
          createdAt: DateTime.utc(2026, 6, 1),
        );

        expect(await repo.getBalance(earningEventIds: const {}), 1 << 30);
      },
    );

    test('logs a warning when the raw (pre-clamp) sum is negative, so the app '
        'bug that produced it stays visible even though the clamp hides it '
        'from the child\'s screen', () async {
      final repo = buildRepo();
      await repo.append(
        entryKind: 'completion',
        delta: 10,
        createdAt: DateTime.utc(2026, 6, 1),
      );
      await repo.append(
        entryKind: 'parent_deduct',
        delta: -999,
        createdAt: DateTime.utc(2026, 6, 2),
      );

      await repo.getBalance(earningEventIds: const {});

      expect(
        talker.history.any(
          (entry) => entry.generateTextMessage().contains(
            'firestore_points_ledger_negative_raw_sum',
          ),
        ),
        isTrue,
        reason:
            'raw sum here is 10 - 999 = -989, negative before the clamp — '
            'must be logged, not silently swallowed',
      );
    });

    test('does NOT log the negative-sum warning when the raw sum is zero or '
        'positive', () async {
      final repo = buildRepo();
      await repo.append(
        entryKind: 'completion',
        delta: 10,
        createdAt: DateTime.utc(2026, 6, 1),
      );
      await repo.append(
        entryKind: 'redemption_debit',
        delta: -10,
        createdAt: DateTime.utc(2026, 6, 2),
      );

      await repo.getBalance(earningEventIds: const {});

      expect(
        talker.history.any(
          (entry) => entry.generateTextMessage().contains(
            'firestore_points_ledger_negative_raw_sum',
          ),
        ),
        isFalse,
      );
    });
  });

  group(
    'one-shot reads skip a malformed document instead of failing the whole read',
    () {
      test('getLedger omits a document missing entry_kind', () async {
        final repo = buildRepo();
        final bad = await repo.append(
          entryKind: 'completion',
          delta: 5,
          createdAt: DateTime.utc(2026, 4, 10),
        );
        await repo.append(
          entryKind: 'completion',
          delta: 5,
          createdAt: DateTime.utc(2026, 4, 11),
        );
        await rawDoc(bad.ulid).update({'entry_kind': FieldValue.delete()});

        final all = await repo.getLedger();

        expect(all, hasLength(1));
      });
    },
  );

  group('watchEntry / watchRecentLedgerEntries — stream emits on change', () {
    test('watchEntry eventually reflects the written document', () async {
      final repo = buildRepo();
      const ulid = 'WATCHULID000000000000AAA';

      final stream = repo.watchEntry(ulid).map((e) => e != null);
      final done = expectLater(stream, emitsThrough(true));

      await repo.append(
        entryKind: 'completion',
        delta: 5,
        createdAt: DateTime.utc(2026, 4, 10),
        ulid: ulid,
      );

      await done;
    });

    test(
      'watchRecentLedgerEntries eventually reflects newly-appended entries',
      () async {
        final repo = buildRepo();

        final stream = repo
            .watchRecentLedgerEntries(limit: 10)
            .map((entries) => entries.length);
        final done = expectLater(stream, emitsThrough(2));

        await repo.append(
          entryKind: 'completion',
          delta: 5,
          createdAt: DateTime.utc(2026, 4, 10),
        );
        await repo.append(
          entryKind: 'completion',
          delta: 5,
          createdAt: DateTime.utc(2026, 4, 11),
        );

        await done;
      },
    );
  });

  group('derived lifetime-earned points', () {
    test(
      'sums only explicit earning kinds and excludes debits and refunds',
      () async {
        final repo = buildRepo();
        await repo.append(
          entryKind: 'completion',
          delta: 100,
          createdAt: DateTime.utc(2026, 6, 1),
        );
        await repo.append(
          entryKind: 'parent_add',
          delta: 50,
          createdAt: DateTime.utc(2026, 6, 2),
        );
        await repo.append(
          entryKind: 'redemption_debit',
          delta: -100,
          createdAt: DateTime.utc(2026, 6, 3),
        );
        await repo.append(
          entryKind: 'redemption_refund',
          delta: 100,
          createdAt: DateTime.utc(2026, 6, 4),
        );
        await repo.append(
          entryKind: 'parent_deduct',
          delta: -10,
          createdAt: DateTime.utc(2026, 6, 5),
        );

        expect(await lifetime(repo), 150);
        expect(await repo.getBalance(earningEventIds: const {}), 140);
      },
    );

    test('returns 0 for a profile with no ledger entries', () async {
      final repo = buildRepo();
      expect(await lifetime(repo), 0);
    });
  });

  group('pagination past the 500-item page size', () {
    test(
      'getLedger reassembles a 501-document collection across pages',
      () async {
        final repo = buildRepo();
        final ids = List.generate(501, (_) => newUlid());

        Map<String, dynamic> rawEntryData(String ulid) => {
          'ulid': ulid,
          'entry_kind': 'completion',
          'delta': 1,
          'created_at': DateTime.utc(2026, 1, 1),
          'source': 'live',
        };

        final batch1 = firestore.batch();
        for (final id in ids.take(500)) {
          batch1.set(rawDoc(id), rawEntryData(id));
        }
        await batch1.commit();

        final batch2 = firestore.batch();
        batch2.set(rawDoc(ids.last), rawEntryData(ids.last));
        await batch2.commit();

        final all = await repo.getLedger();

        expect(all, hasLength(501));
        expect(all.map((e) => e.ulid).toSet(), ids.toSet());
        expect(await repo.getBalance(earningEventIds: const {}), 501);
      },
    );
  });

  group('AD-50 filtered totals (DNI-480)', () {
    test('an event row counts only while its event earns; non-event rows '
        'always count', () async {
      final repo = buildRepo();
      await award('evA', 10);
      await award('evB', 5);
      // An orphan / ineligible pts_ row: its event is not earning.
      await award('evOrphan', 99);
      await repo.append(
        entryKind: 'parent_add',
        delta: 3,
        createdAt: DateTime.utc(2026, 6, 2),
      );
      await repo.append(
        entryKind: 'redemption_debit',
        delta: -4,
        createdAt: DateTime.utc(2026, 6, 3),
      );

      expect(
        await repo.getTotals(earningEventIds: {'evA', 'evB'}),
        const PointsTotals(balance: 14, lifetimeEarned: 18),
      );
      // Voiding evB removes it from the earning set: both totals fall,
      // with no reversal row written.
      final before = (await repo.getLedger()).length;
      expect(
        await repo.getTotals(earningEventIds: {'evA'}),
        const PointsTotals(balance: 9, lifetimeEarned: 13),
      );
      expect(await repo.getBalance(earningEventIds: {'evA'}), 9);
      expect((await repo.getLedger()).length, before);
    });

    test('a legacy pts_ row with no event_id is never a non-event row: it '
        'counts only while the event its doc id names earns', () async {
      final repo = buildRepo();
      // Legacy rows at pts_{eventId} written before capture wrote event_id:
      // one whose stored ulid is the doc id, one whose ulid differs.
      await rawDoc('pts_evLegacy').set({
        'ulid': 'pts_evLegacy',
        'entry_kind': 'completion',
        'delta': 40,
        'created_at': DateTime.utc(2026, 6, 1),
        'source': 'live',
      });
      await rawDoc('pts_evOther').set({
        'ulid': '01J0000000000000000000LEGA',
        'entry_kind': 'completion',
        'delta': 25,
        'created_at': DateTime.utc(2026, 6, 1),
        'source': 'live',
      });
      await repo.append(
        entryKind: 'parent_add',
        delta: 2,
        createdAt: DateTime.utc(2026, 6, 2),
      );

      final ledger = await repo.getLedger();
      expect(
        {for (final e in ledger) e.eventId},
        {'evLegacy', 'evOther', null},
      );

      // Neither event earns: only the adjustment counts, toward both.
      expect(
        await repo.getTotals(earningEventIds: const {}),
        const PointsTotals(balance: 2, lifetimeEarned: 2),
      );
      // resolveTotals sees them as event rows, so it consults the engine.
      var resolved = 0;
      expect(
        await repo.resolveTotals(() async {
          resolved++;
          return const <String>{};
        }),
        const PointsTotals(balance: 2, lifetimeEarned: 2),
      );
      expect(resolved, 1);
      // Once the engine says evLegacy earns, it counts like any award.
      expect(
        await repo.getTotals(earningEventIds: {'evLegacy'}),
        const PointsTotals(balance: 42, lifetimeEarned: 42),
      );
    });

    test('resolveTotals reads the earning set only when the ledger holds '
        'event rows', () async {
      final repo = buildRepo();
      await repo.append(
        entryKind: 'parent_add',
        delta: 7,
        createdAt: DateTime.utc(2026, 6, 1),
      );
      var resolved = 0;
      Future<Set<String>> earning() async {
        resolved++;
        return const {};
      }

      expect(
        await repo.resolveTotals(earning),
        const PointsTotals(balance: 7, lifetimeEarned: 7),
      );
      expect(resolved, 0, reason: 'no event row: the filter is irrelevant');

      await award('evA', 3);
      expect(
        await repo.resolveTotals(earning),
        const PointsTotals(balance: 7, lifetimeEarned: 7),
      );
      expect(resolved, 1);
    });

    test(
      'the negative-raw-sum warning is judged on the filtered sum',
      () async {
        final repo = buildRepo();
        await award('evA', 10);
        await repo.append(
          entryKind: 'redemption_debit',
          delta: -8,
          createdAt: DateTime.utc(2026, 6, 2),
        );

        expect(await repo.getBalance(earningEventIds: const {}), 0);
        expect(
          talker.history.any(
            (entry) => entry.generateTextMessage().contains(
              'firestore_points_ledger_negative_raw_sum',
            ),
          ),
          isTrue,
        );
      },
    );
  });
}
