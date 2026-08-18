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

  group('restoring a tombstoned entry at the same deterministic ulid '
      '(Fix 2 — closes the re-earn trapdoor)', () {
    test('clears purged_at, leaves completedAt/completionNumber untouched, '
        'does not create a second document', () async {
      final repo = buildRepo();
      const ulid = 'RESTOREULID0000000000AAA';

      final original = await record(
        repo,
        unitIdentifier: 'unit-1',
        completedAt: DateTime.utc(2026, 1, 1),
        ulid: ulid,
      );
      expect(original.completionNumber, 1);
      expect(original.purgedAt, isNull);

      await repo.purgeEntry(ulid: ulid, purgedAt: DateTime.utc(2026, 3, 1));
      // getLedgerForCurriculum excludes tombstoned rows at its
      // `_decodeAll` choke point — read the raw doc instead to confirm
      // the tombstone actually landed.
      final tombstonedData = (await rawDoc(ulid).get()).data()!;
      expect(tombstonedData['purged_at'], isNotNull);

      // Re-earn: CompletionDetectionService always resolves the SAME
      // deterministic ulid for a given unit, so this mirrors its call
      // shape exactly.
      final restored = await record(
        repo,
        unitIdentifier: 'unit-1',
        completedAt: DateTime.utc(2026, 4, 1),
        ulid: ulid,
      );

      expect(restored.purgedAt, isNull, reason: 'restore must clear purged_at');
      expect(
        restored.completedAt,
        DateTime.utc(2026, 1, 1),
        reason:
            'completedAt is NOT re-stamped to the new re-earning moment — '
            'firestore.rules only allows purged_at to change on this '
            'collection (see recordCompletion\'s doc comment)',
      );
      expect(
        restored.completionNumber,
        1,
        reason: 'completionNumber must not be recomputed on restore',
      );

      final all = await repo.getLedgerForCurriculum(CurriculumId.mishnayos);
      expect(
        all,
        hasLength(1),
        reason: 'restore must not create a second document',
      );
      expect(all.single.purgedAt, isNull);
    });

    test('restoring one entry does not corrupt completionNumber for a sibling '
        'entry of the same unit', () async {
      final repo = buildRepo();
      const ulidA = 'RESTOREULIDAAAAAAAAAAA01';

      final a = await record(
        repo,
        unitIdentifier: 'unit-1',
        completedAt: DateTime.utc(2026, 1, 1),
        ulid: ulidA,
      );
      expect(a.completionNumber, 1);

      await repo.purgeEntry(ulid: ulidA, purgedAt: DateTime.utc(2026, 2, 1));

      // A second, genuinely different completion of the SAME unit while
      // `a` is tombstoned — `_nextCompletionNumber` counts the tombstoned
      // doc too, so this is 2, not 1.
      final b = await record(
        repo,
        unitIdentifier: 'unit-1',
        completedAt: DateTime.utc(2026, 3, 1),
      );
      expect(b.completionNumber, 2);

      // Restore `a`.
      final restoredA = await record(
        repo,
        unitIdentifier: 'unit-1',
        completedAt: DateTime.utc(2026, 4, 1),
        ulid: ulidA,
      );
      expect(
        restoredA.completionNumber,
        1,
        reason: 'restoring a must not change its own original number',
      );

      final all = await repo.getLedgerForCurriculum(CurriculumId.mishnayos);
      final bReloaded = all.firstWhere((e) => e.ulid == b.ulid);
      expect(
        bReloaded.completionNumber,
        2,
        reason: 'restoring a sibling entry must not renumber b',
      );
    });
  });

  group('getLedgerForCurriculumIncludingTombstoned — D-M epoch-rule seam', () {
    // `BulkPriorCompletionService.expungePriorCompletions`'s "epoch rule"
    // (retract at most one ledger entry per unit per genuine coverage-loss
    // event, never cascade down to older historical entries) depends on
    // this method actually returning tombstoned entries. A prior round of
    // this feature had the algorithm right but read from the
    // tombstone-FILTERING `getLedgerForCurriculum` instead — the safety
    // check it needed could never fire, and the service-level test suite
    // didn't catch it because a hand-written fake diverged from production.
    // These tests pin the PRODUCTION repository/adapter layer directly, so
    // a regression here (e.g. `_decodeAll`'s `includeTombstoned` flag or the
    // `includeTombstoned: true` argument being dropped) fails on its own,
    // without depending on any other test's fake staying in sync.
    test('returns tombstoned AND non-tombstoned entries, including the '
        'true-highest-completionNumber entry when it is the tombstoned one — '
        'while every ordinary reader still hides it', () async {
      final repo = buildRepo();
      const ulidLow = 'EPOCHULIDLOW00000000001';
      const ulidHigh = 'EPOCHULIDHIGH0000000001';
      const ulidOther = 'EPOCHULIDOTHER000000001';

      final low = await record(
        repo,
        unitIdentifier: 'berachos',
        completedAt: DateTime.utc(2026, 1, 1),
        ulid: ulidLow,
      );
      final high = await record(
        repo,
        unitIdentifier: 'berachos',
        completedAt: DateTime.utc(2026, 2, 1),
        ulid: ulidHigh,
      );
      final other = await record(
        repo,
        unitIdentifier: 'shabbos',
        completedAt: DateTime.utc(2026, 1, 1),
        ulid: ulidOther,
      );
      expect(low.completionNumber, 1);
      expect(high.completionNumber, 2);
      expect(other.completionNumber, 1);

      await repo.purgeEntry(ulid: ulidHigh, purgedAt: DateTime.utc(2026, 3, 1));

      final includingTombstoned = await repo
          .getLedgerForCurriculumIncludingTombstoned(CurriculumId.mishnayos);
      expect(includingTombstoned.map((e) => e.ulid).toSet(), {
        ulidLow,
        ulidHigh,
        ulidOther,
      }, reason: 'must include the tombstoned entry, not silently drop it');
      final highReloaded = includingTombstoned.firstWhere(
        (e) => e.ulid == ulidHigh,
      );
      expect(highReloaded.purgedAt, isNotNull);
      final berachosEntries =
          includingTombstoned
              .where((e) => e.unitIdentifier == 'berachos')
              .toList()
            ..sort((a, b) => b.completionNumber.compareTo(a.completionNumber));
      expect(
        berachosEntries.first.ulid,
        ulidHigh,
        reason:
            'the true-highest-completionNumber entry for the unit is the '
            'tombstoned one — this is exactly what the epoch rule needs '
            'to see to correctly stop retracting further',
      );

      // Every ORDINARY reader must still hide the tombstoned entry — the
      // D-M "invisible to every reader" invariant is unaffected by adding
      // this one narrow exception.
      final plain = await repo.getLedgerForCurriculum(CurriculumId.mishnayos);
      expect(plain.map((e) => e.ulid).toSet(), {ulidLow, ulidOther});

      final lifetime = await repo.getLifetimeLedger();
      expect(lifetime.map((e) => e.ulid).toSet(), {ulidLow, ulidOther});

      final stats = await repo.getCompletionStats(CurriculumId.mishnayos);
      expect(
        stats['total'],
        2,
        reason:
            'getCompletionStats delegates to getLedgerForCurriculum, '
            'which excludes the tombstoned entry',
      );
    });

    test('returns the identical doc set as getLedgerForCurriculum when nothing '
        'is tombstoned (query-shape parity — both build the same underlying '
        'query, only the decode step differs)', () async {
      final repo = buildRepo();
      final ids = List.generate(5, (_) => newUlid());
      for (final id in ids) {
        await record(repo, unitIdentifier: id, ulid: id);
      }
      // A different curriculum's entry must never leak into either read.
      await record(
        repo,
        curriculumId: CurriculumId.bavli,
        unitIdentifier: 'other-curriculum',
      );

      final plain = await repo.getLedgerForCurriculum(CurriculumId.mishnayos);
      final includingTombstoned = await repo
          .getLedgerForCurriculumIncludingTombstoned(CurriculumId.mishnayos);

      expect(plain.map((e) => e.ulid).toSet(), ids.toSet());
      expect(includingTombstoned.map((e) => e.ulid).toSet(), ids.toSet());
    });

    test(
      'paginates past the 500-item page size identically to '
      'getLedgerForCurriculum — including tombstoned rows in the count',
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

        // Tombstone exactly half of the 501 documents directly (bypassing
        // repo.purgeEntry, which would be 251 round trips) — a raw write is
        // fine here since this test only cares about the READ side.
        final tombstoneBatch = firestore.batch();
        for (final id in ids.take(250)) {
          tombstoneBatch.update(rawDoc(id), {
            'purged_at': DateTime.utc(2026, 5, 1),
          });
        }
        await tombstoneBatch.commit();

        final includingTombstoned = await repo
            .getLedgerForCurriculumIncludingTombstoned(CurriculumId.mishnayos);
        final plain = await repo.getLedgerForCurriculum(CurriculumId.mishnayos);

        expect(
          includingTombstoned,
          hasLength(501),
          reason:
              'the including-tombstoned read must reassemble all 501 '
              'documents across pages, tombstoned or not',
        );
        expect(plain, hasLength(251), reason: '501 total minus 250 tombstoned');
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

  group('source — write-time provenance (not a retraction key)', () {
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
              'written via CompletionSource.name — the exact enum '
              'member-name string, for write-time policy and display, not '
              'for keying retraction',
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
