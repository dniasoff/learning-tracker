import 'package:drift/drift.dart' show Value;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../helpers/test_database.dart';

class _MockOutboxFacade extends Mock implements OutboxSyncWriteFacade {}

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

      test('pushes to sync engine after insert', () async {
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

        // The repository routes ledger pushes through the outbox facade now —
        // verify the enqueue happened exactly once.
        verify(() => mockOutboxFacade.enqueueLedgerEntry(any())).called(1);
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
      test('inserts multiple rows and pushes one ledger batch', () async {
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
        // The batch path enqueues one outbox row per entry; the legacy
        // direct-batch gateway call is no longer used.
        verify(() => mockOutboxFacade.enqueueLedgerEntry(any())).called(2);
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
