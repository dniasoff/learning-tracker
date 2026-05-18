import 'package:drift/drift.dart' show Value;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/firestore_gateway.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../helpers/test_database.dart';

class _MockFirestoreGateway extends Mock implements FirestoreGateway {}

void main() {
  late UserDatabase db;
  late _MockFirestoreGateway mockGateway;

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db);
    // Seed a second learner profile (id=5) used by child-profile tests.
    await db.into(db.learnerProfiles).insert(
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
    await db.into(db.curriculumTracks).insert(
      CurriculumTracksCompanion(
        id: const Value(42),
        profileId: const Value(1),
        curriculumId: const Value('mishna'),
        trackType: const Value('personal'),
        activatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    mockGateway = _MockFirestoreGateway();
    when(
      () => mockGateway.pushLedgerEntry(
        profileId: any(named: 'profileId'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockGateway.pushLedgerEntriesBatch(
        profileId: any(named: 'profileId'),
        entries: any(named: 'entries'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await db.close();
  });

  LearningLedgerRepositoryImpl createRepo({
    int profileId = 1,
    String profileMode = 'adult',
    bool parentPinSessionMatches = false,
  }) {
    return LearningLedgerRepositoryImpl(
      database: db,
      firestoreGateway: mockGateway,
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

        verify(
          () => mockGateway.pushLedgerEntry(
            profileId: any(named: 'profileId'),
            data: any(named: 'data'),
          ),
        ).called(1);
      });

      test(
        'allows manual completion for child when parent PIN session active',
        () async {
          final repo = createRepo(
            profileId: 5,
            profileMode: 'child',
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
        final repo = createRepo(profileId: 5, profileMode: 'child');

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
        final repo = createRepo(profileId: 1, profileMode: 'adult');
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
        final repo = createRepo(profileId: 1, profileMode: 'adult');
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
        final repo = createRepo(profileId: 5, profileMode: 'child');
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
        verifyNever(
          () => mockGateway.pushLedgerEntry(
            profileId: any(named: 'profileId'),
            data: any(named: 'data'),
          ),
        );
        verify(
          () => mockGateway.pushLedgerEntriesBatch(
            profileId: any(named: 'profileId'),
            entries: any(named: 'entries'),
          ),
        ).called(1);
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
