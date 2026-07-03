import 'package:drift/drift.dart'
    show
        ApplyInterceptor,
        BatchedStatements,
        QueryExecutor,
        QueryInterceptor,
        Value;
import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../helpers/test_database.dart';

class _MockOutboxFacade extends Mock implements OutboxSyncWriteFacade {}

/// AUD-learning-03 regression harness: simulates a real mid-transaction
/// failure (disk error, crash) on the write that touches the `outbox`
/// table — either a single-row INSERT ([runInsert]) or a batched INSERT
/// ([runBatched], used by [LearningLedgerRepositoryImpl.recordCompletionsBatch])
/// — while every other statement (including the `learning_ledger` inserts)
/// passes through untouched. Proves the fix at the real Drift/SQLite level,
/// not through a mocked collaborator.
class _ThrowOnOutboxWrite extends QueryInterceptor {
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (statement.contains('"outbox"')) {
      throw Exception('AUD-learning-03: simulated outbox insert failure');
    }
    return executor.runInsert(statement, args);
  }

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    if (statements.statements.any((sql) => sql.contains('"outbox"'))) {
      throw Exception('AUD-learning-03: simulated outbox batch-insert failure');
    }
    return executor.runBatched(statements);
  }
}

void main() {
  late UserDatabase db;
  late _MockOutboxFacade mockOutboxFacade;

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db);
    // Seed a second learner profile (id=5) used by child-profile tests.
    await db
        .into(db.learnerProfiles)
        .insert(
          LearnerProfilesCompanion(
            id: const Value(5),
            accountId: const Value(1),
            displayName: const Value('Child User'),
            mode: const Value('child'),
            createdAt: Value(DateTime.now().toUtc()),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    // Seed a curriculum track with id=42 for the 'stores trackId' test.
    await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion(
            id: const Value(42),
            profileId: const Value(1),
            curriculumId: const Value('mishna'),
            state: const Value('active'),
            stateChangedAt: Value(DateTime.now().toUtc()),
            activatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    mockOutboxFacade = _MockOutboxFacade();
    when(
      () => mockOutboxFacade.enqueueLedgerEntry(any()),
    ).thenAnswer((_) async {});
    // AUD-learning-03: recordCompletion/recordCompletionsBatch now request a
    // post-commit drain (the write-tee) instead of routing the enqueue
    // itself through the facade.
    when(() => mockOutboxFacade.requestSyncDrain()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await db.close();
  });

  LearningLedgerRepositoryImpl createRepo({
    int profileId = 1,
    ProfileMode profileMode = ProfileMode.adult,
    bool parentPinSessionMatches = false,
  }) {
    return LearningLedgerRepositoryImpl(
      database: db,
      outboxFacade: mockOutboxFacade,
      activeProfileId: profileId,
      activeProfileMode: profileMode,
      parentPinSessionMatchesActiveProfile: parentPinSessionMatches,
    );
  }

  group('LearningLedgerRepositoryImpl', () {
    group('recordCompletion', () {
      test('auto-calculates completionNumber starting at 1', () async {
        final repo = createRepo();
        final entry = await repo.recordCompletion(
          curriculumId: 'mishna',
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: 1,
          isManual: false,
        );

        expect(entry.completionNumber, 1);
      });

      test('increments completionNumber on subsequent completions', () async {
        final repo = createRepo();
        await repo.recordCompletion(
          curriculumId: 'mishna',
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: 1,
          isManual: false,
        );

        final entry2 = await repo.recordCompletion(
          curriculumId: 'mishna',
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: 1,
          isManual: false,
        );

        expect(entry2.completionNumber, 2);
      });

      test('enqueues an outbox row for the entry after insert', () async {
        final repo = createRepo();
        final entry = await repo.recordCompletion(
          curriculumId: 'mishna',
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: 1,
          isManual: false,
        );

        // AUD-learning-03: the outbox row is now written directly against
        // OutboxDao inside the SAME transaction as the ledger insert (DB-2),
        // not via a facade call — assert the durable outcome (a pending
        // outbox row for this entry) instead of a mock interaction.
        final outbox = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.learningLedgerEntry,
          1,
        );
        expect(outbox, hasLength(1));
        expect(outbox.single.entityKey, entry.unitIdentifier);
        // The write-tee drain is still requested once the row has committed.
        verify(() => mockOutboxFacade.requestSyncDrain()).called(1);
      });

      test(
        'allows manual completion for child when parent PIN session active',
        () async {
          final repo = createRepo(
            profileId: 5,
            profileMode: ProfileMode.child,
            parentPinSessionMatches: true,
          );
          final entry = await repo.recordCompletion(
            curriculumId: 'mishna',
            entryScope: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            markedBy: 5,
            isManual: true,
          );

          expect(entry.isManual, true);
          expect(entry.markedBy, 5);
        },
      );

      test('rejects child self-mark for manual completions', () async {
        final repo = createRepo(profileId: 5, profileMode: ProfileMode.child);

        expect(
          () => repo.recordCompletion(
            curriculumId: 'mishna',
            entryScope: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            markedBy: 5, // child marking for self
            isManual: true,
          ),
          throwsA(isA<ChildSelfMarkException>()),
        );
      });

      test('allows adult self-mark for manual completions', () async {
        final repo = createRepo(profileId: 1, profileMode: ProfileMode.adult);
        final entry = await repo.recordCompletion(
          curriculumId: 'mishna',
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: 1,
          isManual: true,
        );

        expect(entry.isManual, true);
        expect(entry.markedBy, 1);
      });

      test('allows parent to mark for child (manual)', () async {
        // Parent is active (profileId=1, mode=adult), marking for child (profileId=5)
        final repo = createRepo(profileId: 1, profileMode: ProfileMode.adult);
        final entry = await repo.recordCompletion(
          curriculumId: 'mishna',
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: 1, // parent is the marker
          isManual: true,
        );

        expect(entry.markedBy, 1);
      });

      test('allows auto-completion for child profiles (not manual)', () async {
        // Auto-completions should work for any profile mode
        final repo = createRepo(profileId: 5, profileMode: ProfileMode.child);
        final entry = await repo.recordCompletion(
          curriculumId: 'mishna',
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: 5,
          isManual: false, // auto, not manual
        );

        expect(entry.isManual, false);
      });

      test('stores trackId when provided', () async {
        final repo = createRepo();
        final entry = await repo.recordCompletion(
          curriculumId: 'mishna',
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          trackId: 42,
          markedBy: 1,
          isManual: false,
        );

        expect(entry.trackId, 42);
      });
    });

    group('recordCompletionsBatch', () {
      test('inserts multiple rows and enqueues one outbox row each', () async {
        final repo = createRepo();
        final entries = await repo.recordCompletionsBatch([
          const LedgerManualBatchItem(
            curriculumId: 'mishna',
            entryScope: 'level1',
            unitIdentifier: 'A',
            unitDisplayNameHe: 'א',
            unitDisplayNameEn: 'A',
            trackType: 'personal',
            markedBy: 1,
            isManual: true,
          ),
          const LedgerManualBatchItem(
            curriculumId: 'mishna',
            entryScope: 'level1',
            unitIdentifier: 'B',
            unitDisplayNameHe: 'ב',
            unitDisplayNameEn: 'B',
            trackType: 'personal',
            markedBy: 1,
            isManual: true,
          ),
        ]);

        expect(entries, hasLength(2));
        expect(entries.first.completionNumber, 1);
        expect(entries.last.completionNumber, 1);
        // AUD-learning-03: outbox rows are written directly against
        // OutboxDao inside the SAME transaction as the batch's ledger
        // inserts (DB-2, via one batch() flush) — assert the durable
        // outcome instead of a facade mock call.
        final outbox = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.learningLedgerEntry,
          1,
          limit: 100,
        );
        expect(outbox, hasLength(2));
        expect(
          outbox.map((row) => row.entityKey),
          containsAll(<String>['A', 'B']),
        );
        // The write-tee drain is requested once per batch, not once per row.
        verify(() => mockOutboxFacade.requestSyncDrain()).called(1);
      });

      // ── WS8 sentinel date tests ────────────────────────────────────────────
      //
      // These are the acceptance-criterion tests for WS8.credit-path: prove
      // that non-live [CompletionSource]s write the sentinel date
      // (DateTime.utc(2000, 1, 1)) to stored rows, NOT DateTime.now(). The
      // sentinel prevents any date-keyed read (streak, pace, recent activity)
      // from crediting lifetime/bulk marks.

      List<LedgerManualBatchItem> twoItems() => [
        const LedgerManualBatchItem(
          curriculumId: 'mishna',
          entryScope: 'level1',
          unitIdentifier: 'Seder Zeraim',
          unitDisplayNameHe: 'סדר זרעים',
          unitDisplayNameEn: 'Seder Zeraim',
          trackType: 'personal',
          markedBy: 1,
          isManual: true,
        ),
        const LedgerManualBatchItem(
          curriculumId: 'mishna',
          entryScope: 'level2',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: 1,
          isManual: true,
        ),
      ];

      // Helper: normalise a DateTime to UTC so Drift's local-timezone rounding
      // does not cause false failures. Drift stores timestamps as UTC ms-since-
      // epoch integers, but the round-trip through SQLite can produce a local-
      // timezone DateTime on some platforms. Converting to UTC before comparison
      // removes the offset. The sentinel year (2000) is chosen to be far enough
      // in the past that even UTC+14 cannot push it into 2001.
      DateTime normaliseToUtc(DateTime dt) => dt.toUtc();

      test(
        'WS8 — default source (lifetimeOnly) writes sentinel date to all rows',
        () async {
          final repo = createRepo();
          // Default source = CompletionSource.lifetimeOnly per the updated API.
          final entries = await repo.recordCompletionsBatch(twoItems());

          expect(entries, hasLength(2));
          for (final entry in entries) {
            final stored = normaliseToUtc(entry.completedAt);
            expect(
              stored.year,
              equals(2000),
              reason:
                  'lifetimeOnly (default) must write the sentinel date '
                  '(year 2000) so no date-keyed read credits these rows '
                  'toward streak or pace',
            );
            expect(stored.month, equals(1));
            expect(stored.day, equals(1));
          }
        },
      );

      test('WS8 — explicit lifetimeOnly source writes sentinel date', () async {
        final repo = createRepo();
        final entries = await repo.recordCompletionsBatch(
          twoItems(),
          source: CompletionSource.lifetimeOnly,
        );

        expect(entries, hasLength(2));
        for (final entry in entries) {
          final stored = normaliseToUtc(entry.completedAt);
          expect(stored.year, equals(2000));
          expect(stored.month, equals(1));
          expect(stored.day, equals(1));
        }
      });

      test('WS8 — bulkInTrack source writes sentinel date', () async {
        final repo = createRepo();
        final entries = await repo.recordCompletionsBatch(
          twoItems(),
          source: CompletionSource.bulkInTrack,
        );

        expect(entries, hasLength(2));
        for (final entry in entries) {
          final stored = normaliseToUtc(entry.completedAt);
          expect(
            stored.year,
            equals(2000),
            reason:
                'bulkInTrack also suppresses engagement — '
                'sentinel must be written to avoid inflating recent activity',
          );
          expect(stored.month, equals(1));
          expect(stored.day, equals(1));
        }
      });

      test(
        'WS8 — live source writes a real (non-sentinel) timestamp',
        () async {
          final repo = createRepo();
          final entries = await repo.recordCompletionsBatch(
            twoItems(),
            source: CompletionSource.live,
          );

          expect(entries, hasLength(2));
          for (final entry in entries) {
            final stored = normaliseToUtc(entry.completedAt);
            expect(
              stored.year,
              isNot(equals(2000)),
              reason:
                  'live source must NOT use the sentinel — '
                  'it should record the actual time of marking (year > 2000)',
            );
          }
        },
      );
    });

    // AUD-learning-03 (DB-2): the ledger insert and its outbox row must
    // commit or roll back TOGETHER. These use a real Drift/SQLite failure
    // (via _ThrowOnOutboxWrite) injected at the exact statement that writes
    // the `outbox` table, rather than a mocked collaborator — the fixed
    // repository no longer calls the outbox facade from inside the
    // transaction at all (see the class doc on LearningLedgerRepositoryImpl),
    // so this is the only way to prove the atomicity guarantee end-to-end.
    group('AUD-learning-03 — ledger/outbox atomicity (DB-2)', () {
      test('recordCompletion: a failing outbox insert rolls back the ledger '
          'row too (no ledger row survives without its outbox pair)', () async {
        final failingDb = UserDatabase(
          NativeDatabase.memory().interceptWith(_ThrowOnOutboxWrite()),
        );
        await seedProfile(failingDb);
        addTearDown(failingDb.close);

        final repo = LearningLedgerRepositoryImpl(
          database: failingDb,
          outboxFacade: mockOutboxFacade,
          activeProfileId: 1,
          activeProfileMode: ProfileMode.adult,
        );

        await expectLater(
          repo.recordCompletion(
            curriculumId: 'mishna',
            entryScope: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            markedBy: 1,
            isManual: false,
          ),
          throwsA(anything),
        );

        final ledgerRows = await failingDb.learningLedgerDao
            .getEntriesByProfile(1);
        expect(
          ledgerRows,
          isEmpty,
          reason:
              'DB-2: the ledger insert must roll back when its paired '
              'outbox insert fails — otherwise the ledger row is stranded '
              'local-only and never reaches Firestore or a second device',
        );
        final outboxRows = await failingDb.select(failingDb.outbox).get();
        expect(outboxRows, isEmpty);
      });

      test('recordCompletionsBatch: a failing outbox insert rolls back EVERY '
          'ledger row in the batch (no ledger row survives without its '
          'outbox pair)', () async {
        final failingDb = UserDatabase(
          NativeDatabase.memory().interceptWith(_ThrowOnOutboxWrite()),
        );
        await seedProfile(failingDb);
        addTearDown(failingDb.close);

        final repo = LearningLedgerRepositoryImpl(
          database: failingDb,
          outboxFacade: mockOutboxFacade,
          activeProfileId: 1,
          activeProfileMode: ProfileMode.adult,
        );

        await expectLater(
          repo.recordCompletionsBatch([
            const LedgerManualBatchItem(
              curriculumId: 'mishna',
              entryScope: 'level1',
              unitIdentifier: 'A',
              unitDisplayNameHe: 'א',
              unitDisplayNameEn: 'A',
              trackType: 'personal',
              markedBy: 1,
              isManual: true,
            ),
            const LedgerManualBatchItem(
              curriculumId: 'mishna',
              entryScope: 'level1',
              unitIdentifier: 'B',
              unitDisplayNameHe: 'ב',
              unitDisplayNameEn: 'B',
              trackType: 'personal',
              markedBy: 1,
              isManual: true,
            ),
          ]),
          throwsA(anything),
        );

        final ledgerRows = await failingDb.learningLedgerDao
            .getEntriesByProfile(1);
        expect(
          ledgerRows,
          isEmpty,
          reason:
              'DB-2: neither ledger row may survive when the batch '
              'outbox insert fails — a partial commit would strand '
              'ledger rows with no outbox pair',
        );
        final outboxRows = await failingDb.select(failingDb.outbox).get();
        expect(outboxRows, isEmpty);
      });
    });

    group('getLifetimeLedger', () {
      test('returns all entries for a profile', () async {
        final repo = createRepo();
        await repo.recordCompletion(
          curriculumId: 'mishna',
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: 1,
          isManual: false,
        );
        await repo.recordCompletion(
          curriculumId: 'daf_yomi',
          entryScope: 'masechta',
          unitIdentifier: 'Shabbat',
          unitDisplayNameHe: 'שבת',
          unitDisplayNameEn: 'Shabbat',
          trackType: 'personal',
          markedBy: 1,
          isManual: false,
        );

        final ledger = await repo.getLifetimeLedger(1);
        expect(ledger, hasLength(2));
      });
    });

    group('getCompletionStats', () {
      test('returns correct auto/manual breakdown', () async {
        final repo = createRepo();
        await repo.recordCompletion(
          curriculumId: 'mishna',
          entryScope: 'masechta',
          unitIdentifier: 'Berakhot',
          unitDisplayNameHe: 'ברכות',
          unitDisplayNameEn: 'Berakhot',
          trackType: 'personal',
          markedBy: 1,
          isManual: false,
        );
        await repo.recordCompletion(
          curriculumId: 'mishna',
          entryScope: 'masechta',
          unitIdentifier: 'Shabbat',
          unitDisplayNameHe: 'שבת',
          unitDisplayNameEn: 'Shabbat',
          trackType: 'personal',
          markedBy: 1,
          isManual: true,
        );

        final stats = await repo.getCompletionStats(1, 'mishna');
        expect(stats['total'], 2);
        expect(stats['auto'], 1);
        expect(stats['manual'], 1);
      });
    });
  });
}
