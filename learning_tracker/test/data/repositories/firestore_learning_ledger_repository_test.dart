/// Unit tests for
/// `lib/data/repositories/firestore_learning_ledger_repository.dart` — one
/// of the two APPEND-ONLY repositories in the Firestore rewrite (the other
/// is `firestore_streak_event_repository_test.dart`). Covers: doc-id
/// correctness, ULID retry-idempotency (a retry must NOT recompute
/// `completionNumber`), `completionNumber` auto-increment (including that
/// it is scoped per `(curriculumId, unitIdentifier)`, independent of other
/// units), model round-trip (including that `completed_at` survives the
/// real-Firestore-`Timestamp` round trip the repository's class doc
/// comment describes — this is the one behavior most worth pinning: get it
/// wrong and every production write is silently rules-rejected),
/// `recordCompletionsBatch`'s in-memory running-count numbering,
/// `getCompletionStats`, one-shot AND streamed decode leniency, and the
/// doc-id-ordered pagination past the 500-item page size.
///
/// **What these tests cannot see** (same limitation documented in
/// `firestore_bookmark_repository_test.dart`/
/// `firestore_stage_definition_repository_test.dart`, restated here because
/// it is especially load-bearing for this collection):
/// `fake_cloud_firestore`'s rules companion cannot evaluate
/// `resource.data`/`request.resource` at all (see
/// `test/helpers/firestore_fake.dart`'s doc comment) — clauses using them
/// evaluate to deny under `strictRules: true`, which is STRICTER than
/// production, not equivalent to it, so `strictRules: true` is not usable
/// here to prove anything either way. That means:
/// - `firestore.rules`' SR-4 500-item `list()` cap
///   (`request.query.limit <= 500`) is never enforced by the fake — the
///   pagination tests below prove [FirestoreLearningLedgerRepository]
///   NEVER issues a query above that limit and correctly reassembles
///   multi-page results, but cannot prove a request missing `.limit()`
///   entirely would be rejected in production (it would be, by
///   construction: every query in the repository always chains `.limit()`
///   — reviewed, not test-proven).
/// - SR-3's `completed_at is timestamp` guard is never evaluated either.
///   The `completed_at`-is-a-real-`Timestamp` tests below prove the
///   WRITTEN VALUE has the correct Firestore-level TYPE (confirmed against
///   `fake_cloud_firestore`'s own `DateTime`→`Timestamp` write-time
///   transform, which mirrors real `cloud_firestore` SDK behavior) — they
///   cannot prove the rules engine accepts it, only that the type this
///   engine writes is the type the rule asks for.
/// - `LedgerEntryDraft.ulid`-based whole-batch retry safety is NOT
///   exercised — `recordCompletionsBatch`'s class doc comment already
///   states plainly that this method does not get `recordCompletion`'s
///   full retry protection; there is nothing more for a test to prove
///   about a documented non-guarantee.
///
/// TQ-6: no wall clock, no shared global state — every test builds its own
/// fake Firestore instance.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';

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
      .collection('learning_ledger')
      .doc(ulid);

  FirestoreLearningLedgerRepository buildRepo() {
    return FirestoreLearningLedgerRepository(
      firestore: firestore,
      uid: _uid,
      profileId: _profileId,
    );
  }

  Future<LearningLedgerEntry> record(
    FirestoreLearningLedgerRepository repo, {
    CurriculumId curriculumId = CurriculumId.mishnayos,
    String unitIdentifier = 'unit-1',
    DateTime? completedAt,
    bool isManual = false,
    String markedBy = _profileId,
    CompletionSource source = CompletionSource.live,
    String? ulid,
  }) {
    return repo.recordCompletion(
      curriculumId: curriculumId,
      entryScope: 'masechta',
      unitIdentifier: unitIdentifier,
      unitDisplayNameHe: 'שם',
      unitDisplayNameEn: 'Name',
      trackType: 'personal',
      completedAt: completedAt ?? DateTime.utc(2026, 1, 1),
      markedBy: markedBy,
      isManual: isManual,
      source: source,
      ulid: ulid,
    );
  }

  Map<String, dynamic> rawLedgerData({
    required String ulid,
    required CurriculumId curriculumId,
    required String unitIdentifier,
  }) => {
    'ulid': ulid,
    'curriculum_id': curriculumId.storageKey,
    'entry_scope': 'masechta',
    'unit_identifier': unitIdentifier,
    'unit_display_name_he': 'שם',
    'unit_display_name_en': 'Name',
    'track_type': 'personal',
    'completed_at': DateTime.utc(2026, 1, 1),
    'completion_number': 1,
    'marked_by': _profileId,
    'is_manual': false,
  };

  group('doc-id correctness', () {
    test(
      'recordCompletion writes at doc-id == ulid (DocIds.learningLedgerDocId)',
      () async {
        final repo = buildRepo();
        const ulid = 'FIXEDULID00000000000000AA';

        final entry = await record(repo, ulid: ulid);

        expect(entry.ulid, ulid);
        expect(
          ulid,
          DocIds.learningLedgerDocId({'ulid': ulid}),
          reason: 'sanity: the formula is a pure echo of the ulid',
        );
        final snapshot = await rawDoc(ulid).get();
        expect(snapshot.exists, isTrue);
      },
    );

    test('recordCompletion mints a fresh ulid when none is supplied', () async {
      final repo = buildRepo();
      final a = await record(repo, unitIdentifier: 'unit-a');
      final b = await record(repo, unitIdentifier: 'unit-b');
      expect(a.ulid, isNot(b.ulid));
    });

    test(
      'never writes track_id or profile_id (MCF-11 / path-scoped, not payload-scoped)',
      () async {
        final repo = buildRepo();
        final entry = await record(repo);

        final data = (await rawDoc(entry.ulid).get()).data()!;
        expect(data, isNot(contains('track_id')));
        expect(data, isNot(contains('profile_id')));
      },
    );
  });

  group('ULID retry-idempotency', () {
    test(
      'retrying the same ulid returns the already-committed entry, not a recomputed one',
      () async {
        final repo = buildRepo();
        const ulid = 'RETRYULID0000000000000AA';

        final first = await record(
          repo,
          unitIdentifier: 'unit-1',
          completedAt: DateTime.utc(2026, 1, 1),
          ulid: ulid,
        );
        expect(first.completionNumber, 1);

        // A second, genuinely different completion of the SAME unit — if a
        // retry of `ulid` wrongly recomputed instead of short-circuiting, it
        // would now see this row too and return completionNumber 3, not 1.
        await record(
          repo,
          unitIdentifier: 'unit-1',
          completedAt: DateTime.utc(2026, 2, 1),
        );

        final retried = await record(
          repo,
          unitIdentifier: 'unit-1',
          completedAt: DateTime.utc(2026, 1, 1),
          ulid: ulid,
        );

        expect(retried.completionNumber, 1, reason: 'retry must not recompute');
        expect(retried.ulid, ulid);

        final all = await repo.getLedgerForCurriculum(CurriculumId.mishnayos);
        expect(all, hasLength(2), reason: 'retry must not duplicate the doc');
      },
    );
  });

  group('completionNumber auto-increment', () {
    test(
      'increments per (curriculumId, unitIdentifier), independent of other units',
      () async {
        final repo = buildRepo();

        final first = await record(
          repo,
          curriculumId: CurriculumId.bavli,
          unitIdentifier: 'daf-2a',
        );
        expect(first.completionNumber, 1);

        final second = await record(
          repo,
          curriculumId: CurriculumId.bavli,
          unitIdentifier: 'daf-2a',
          completedAt: DateTime.utc(2026, 6, 1),
        );
        expect(second.completionNumber, 2);

        final otherUnit = await record(
          repo,
          curriculumId: CurriculumId.bavli,
          unitIdentifier: 'daf-2b',
        );
        expect(otherUnit.completionNumber, 1);

        final otherCurriculum = await record(
          repo,
          curriculumId: CurriculumId.mishnayos,
          unitIdentifier: 'daf-2a',
        );
        expect(
          otherCurriculum.completionNumber,
          1,
          reason: 'scoped by curriculumId too, not unitIdentifier alone',
        );
      },
    );
  });

  group('model round-trip', () {
    test('every field survives write then read', () async {
      final repo = buildRepo();
      final written = await record(
        repo,
        curriculumId: CurriculumId.yerushalmi,
        unitIdentifier: 'daf-9b',
        isManual: true,
        markedBy: 'marker-profile-ulid',
        completedAt: DateTime.utc(2026, 3, 15, 10, 30, 45),
        source: CompletionSource.bulkInTrack,
      );

      final all = await repo.getLedgerForCurriculum(CurriculumId.yerushalmi);
      final loaded = all.single;

      expect(loaded.ulid, written.ulid);
      expect(loaded.curriculumId, CurriculumId.yerushalmi);
      expect(loaded.entryScope, 'masechta');
      expect(loaded.unitIdentifier, 'daf-9b');
      expect(loaded.unitDisplayNameHe, 'שם');
      expect(loaded.unitDisplayNameEn, 'Name');
      expect(loaded.trackType, 'personal');
      expect(loaded.completedAt, DateTime.utc(2026, 3, 15, 10, 30, 45));
      expect(loaded.completionNumber, 1);
      expect(loaded.markedBy, 'marker-profile-ulid');
      expect(loaded.isManual, isTrue);
      expect(loaded.source, CompletionSource.bulkInTrack);
    });

    group('completed_at is a real Firestore Timestamp, not a String', () {
      test('the written field has Timestamp type', () async {
        final repo = buildRepo();
        final entry = await record(
          repo,
          completedAt: DateTime.utc(2026, 3, 15, 10, 30),
        );

        final data = (await rawDoc(entry.ulid).get()).data()!;
        expect(
          data['completed_at'],
          isA<Timestamp>(),
          reason:
              'firestore.rules requires completed_at is timestamp (SR-3) — '
              'a String value would fail that check in production',
        );
      });

      test('decodes back to the exact same UTC instant', () async {
        final repo = buildRepo();
        final completedAt = DateTime.utc(2026, 3, 15, 10, 30, 45, 123);

        final written = await record(repo, completedAt: completedAt);
        expect(written.completedAt, completedAt);
        expect(written.completedAt.isUtc, isTrue);

        final reloaded = await repo.getLedgerForCurriculum(
          CurriculumId.mishnayos,
        );
        expect(reloaded.single.completedAt, completedAt);
        expect(reloaded.single.completedAt.isUtc, isTrue);
      });
    });
  });

  group('source — provenance for the bulk-mark-deletion Cloud Function', () {
    test('recordCompletion defaults to CompletionSource.live', () async {
      final repo = buildRepo();
      final entry = await repo.recordCompletion(
        curriculumId: CurriculumId.mishnayos,
        entryScope: 'masechta',
        unitIdentifier: 'unit-1',
        unitDisplayNameHe: 'שם',
        unitDisplayNameEn: 'Name',
        trackType: 'personal',
        completedAt: DateTime.utc(2026, 1, 1),
        markedBy: _profileId,
        isManual: false,
        // source omitted deliberately.
      );

      expect(entry.source, CompletionSource.live);
    });

    test('each CompletionSource round-trips through write then read', () async {
      final repo = buildRepo();

      for (final source in CompletionSource.values) {
        final written = await record(
          repo,
          unitIdentifier: 'unit-${source.name}',
          source: source,
        );

        final all = await repo.getLedgerForCurriculum(CurriculumId.mishnayos);
        final loaded = all.firstWhere((e) => e.ulid == written.ulid);

        expect(
          loaded.source,
          source,
          reason: 'CompletionSource.${source.name} must round-trip exactly',
        );
      }
    });

    test(
      'is present, as the enum member name, on every written raw document',
      () async {
        final repo = buildRepo();
        final entry = await record(repo, source: CompletionSource.bulkInTrack);

        final data = (await rawDoc(entry.ulid).get()).data()!;

        expect(
          data['source'],
          'bulkInTrack',
          reason:
              'written via CompletionSource.name — the exact string the '
              'bulk-mark-deletion Cloud Function filters on',
        );
      },
    );

    test(
      'recordCompletionsBatch stamps the same source across the whole batch, '
      'defaulting to CompletionSource.lifetimeOnly',
      () async {
        final repo = buildRepo();

        final defaulted = await repo.recordCompletionsBatch([
          const LedgerEntryDraft(
            curriculumId: CurriculumId.bavli,
            entryScope: 'masechta',
            unitIdentifier: 'daf-1',
            unitDisplayNameHe: 'א',
            unitDisplayNameEn: 'A',
            trackType: 'personal',
            markedBy: _profileId,
            isManual: true,
          ),
        ], completedAt: DateTime.utc(2026, 1, 1));
        expect(defaulted.single.source, CompletionSource.lifetimeOnly);

        final explicit = await repo.recordCompletionsBatch(
          [
            const LedgerEntryDraft(
              curriculumId: CurriculumId.bavli,
              entryScope: 'masechta',
              unitIdentifier: 'daf-2',
              unitDisplayNameHe: 'ב',
              unitDisplayNameEn: 'B',
              trackType: 'personal',
              markedBy: _profileId,
              isManual: true,
            ),
          ],
          completedAt: DateTime.utc(2026, 1, 1),
          source: CompletionSource.bulkInTrack,
        );
        expect(explicit.single.source, CompletionSource.bulkInTrack);
      },
    );

    group('missing or unrecognised source decodes safely, never throws', () {
      test(
        'a document written before this field existed decodes as live',
        () async {
          final repo = buildRepo();
          const ulid = 'PRESOURCE0000000000000AA';
          await rawDoc(ulid).set(
            rawLedgerData(
              ulid: ulid,
              curriculumId: CurriculumId.mishnayos,
              unitIdentifier: 'unit-1',
            ), // no 'source' key — mirrors a pre-this-change document.
          );

          final all = await repo.getLedgerForCurriculum(CurriculumId.mishnayos);

          expect(
            all.single.source,
            CompletionSource.live,
            reason:
                'the fail-SAFE default: an entry with unknown provenance must '
                'never be mistaken for source == bulkInTrack (deletable)',
          );
        },
      );

      test(
        'an unrecognised source value decodes as live rather than throwing',
        () async {
          final repo = buildRepo();
          const ulid = 'BADSOURCE0000000000000AA';
          await rawDoc(ulid).set({
            ...rawLedgerData(
              ulid: ulid,
              curriculumId: CurriculumId.mishnayos,
              unitIdentifier: 'unit-1',
            ),
            'source': 'not-a-real-source',
          });

          final all = await repo.getLedgerForCurriculum(CurriculumId.mishnayos);

          expect(
            all,
            hasLength(1),
            reason: 'must not be skipped as a decode failure',
          );
          expect(all.single.source, CompletionSource.live);
        },
      );
    });
  });

  group('recordCompletionsBatch', () {
    test(
      'assigns consecutive completionNumbers within one call for the same unit',
      () async {
        final repo = buildRepo();

        final results = await repo.recordCompletionsBatch([
          const LedgerEntryDraft(
            curriculumId: CurriculumId.bavli,
            entryScope: 'masechta',
            unitIdentifier: 'daf-1',
            unitDisplayNameHe: 'א',
            unitDisplayNameEn: 'A',
            trackType: 'personal',
            markedBy: _profileId,
            isManual: true,
          ),
          const LedgerEntryDraft(
            curriculumId: CurriculumId.bavli,
            entryScope: 'masechta',
            unitIdentifier: 'daf-1',
            unitDisplayNameHe: 'א',
            unitDisplayNameEn: 'A',
            trackType: 'personal',
            markedBy: _profileId,
            isManual: true,
          ),
          const LedgerEntryDraft(
            curriculumId: CurriculumId.bavli,
            entryScope: 'masechta',
            unitIdentifier: 'daf-2',
            unitDisplayNameHe: 'ב',
            unitDisplayNameEn: 'B',
            trackType: 'personal',
            markedBy: _profileId,
            isManual: true,
          ),
        ], completedAt: DateTime.utc(2026, 1, 1));

        expect(results.map((e) => e.completionNumber), [1, 2, 1]);
        expect(
          results.map((e) => e.ulid).toSet(),
          hasLength(3),
          reason: 'each drafted entry gets its own doc-id',
        );

        final all = await repo.getLedgerForCurriculum(CurriculumId.bavli);
        expect(all, hasLength(3));
      },
    );

    test('continues numbering from entries already in Firestore', () async {
      final repo = buildRepo();
      await record(
        repo,
        curriculumId: CurriculumId.bavli,
        unitIdentifier: 'daf-1',
      );

      final results = await repo.recordCompletionsBatch([
        const LedgerEntryDraft(
          curriculumId: CurriculumId.bavli,
          entryScope: 'masechta',
          unitIdentifier: 'daf-1',
          unitDisplayNameHe: 'א',
          unitDisplayNameEn: 'A',
          trackType: 'personal',
          markedBy: _profileId,
          isManual: true,
        ),
      ], completedAt: DateTime.utc(2026, 2, 1));

      expect(results.single.completionNumber, 2);
    });

    test('empty list is a no-op', () async {
      final repo = buildRepo();
      final results = await repo.recordCompletionsBatch(
        const [],
        completedAt: DateTime.utc(2026, 1, 1),
      );
      expect(results, isEmpty);
    });
  });

  group('getCompletionStats', () {
    test('splits manual vs auto counts, scoped to one curriculum', () async {
      final repo = buildRepo();
      await record(
        repo,
        curriculumId: CurriculumId.mishnayos,
        unitIdentifier: 'u1',
        isManual: true,
      );
      await record(
        repo,
        curriculumId: CurriculumId.mishnayos,
        unitIdentifier: 'u2',
        isManual: false,
      );
      await record(
        repo,
        curriculumId: CurriculumId.mishnayos,
        unitIdentifier: 'u3',
        isManual: false,
      );
      // Different curriculum — must not be counted.
      await record(repo, curriculumId: CurriculumId.nach, unitIdentifier: 'u1');

      final stats = await repo.getCompletionStats(CurriculumId.mishnayos);

      expect(stats, {'total': 3, 'manual': 1, 'auto': 2});
    });
  });

  group(
    'one-shot reads skip a malformed document instead of failing the whole read',
    () {
      test(
        'getLifetimeLedger omits a document with an unrecognised curriculum_id',
        () async {
          final repo = buildRepo();
          final good = await record(repo, unitIdentifier: 'good-1');
          await record(repo, unitIdentifier: 'good-2');
          await rawDoc(
            good.ulid,
          ).update({'curriculum_id': 'not-a-real-curriculum'});

          final all = await repo.getLifetimeLedger();

          expect(all, hasLength(1));
          expect(all.single.unitIdentifier, 'good-2');
        },
      );

      test('getLedgerForCurriculum has the same leniency', () async {
        final repo = buildRepo();
        final bad = await record(repo, unitIdentifier: 'bad-1');
        await record(repo, unitIdentifier: 'good-1');
        await rawDoc(bad.ulid).update({'marked_by': FieldValue.delete()});

        final entries = await repo.getLedgerForCurriculum(
          CurriculumId.mishnayos,
        );

        expect(entries, hasLength(1));
        expect(entries.single.unitIdentifier, 'good-1');
      });
    },
  );

  group('watchRecentLedgerEntries — stream emits on change', () {
    test('eventually reflects newly-written entries', () async {
      final repo = buildRepo();

      final stream = repo
          .watchRecentLedgerEntries(limit: 10)
          .map((entries) => entries.length);
      final done = expectLater(stream, emitsThrough(2));

      await record(repo, unitIdentifier: 'unit-a');
      await record(repo, unitIdentifier: 'unit-b');

      await done;
    });
  });

  group('pagination past the 500-item page size', () {
    test(
      'getLifetimeLedger reassembles a 501-document collection across pages',
      () async {
        final repo = buildRepo();
        final ids = List.generate(501, (_) => newUlid());

        final batch1 = firestore.batch();
        for (final id in ids.take(500)) {
          batch1.set(
            rawDoc(id),
            rawLedgerData(
              ulid: id,
              curriculumId: CurriculumId.mishnayos,
              unitIdentifier: id,
            ),
          );
        }
        await batch1.commit();

        final batch2 = firestore.batch();
        batch2.set(
          rawDoc(ids.last),
          rawLedgerData(
            ulid: ids.last,
            curriculumId: CurriculumId.mishnayos,
            unitIdentifier: ids.last,
          ),
        );
        await batch2.commit();

        final all = await repo.getLifetimeLedger();

        expect(all, hasLength(501));
        expect(all.map((e) => e.ulid).toSet(), ids.toSet());
      },
    );
  });
}
