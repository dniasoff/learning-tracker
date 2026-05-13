import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:test/test.dart';

import '../../../helpers/test_database.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('LearningLedgerDao', () {
    group('insertEntry', () {
      test('inserts a ledger entry and returns its id', () async {
        final id = await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 1),
            completionNumber: 1,
            markedBy: 1,
          ),
        );

        expect(id, greaterThan(0));
      });

      test('auto-sets createdAt when not provided', () async {
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 1),
            completionNumber: 1,
            markedBy: 1,
          ),
        );

        final entries = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(entries, hasLength(1));
        expect(entries.first.createdAt, isNotNull);
      });
    });

    group('getEntriesByProfile', () {
      test('returns entries for the given profile only', () async {
        // Insert for profile 1
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 1),
            completionNumber: 1,
            markedBy: 1,
          ),
        );
        // Insert for profile 2
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 2,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Shabbat',
            unitDisplayNameHe: 'שבת',
            unitDisplayNameEn: 'Shabbat',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 2),
            completionNumber: 1,
            markedBy: 2,
          ),
        );

        final entries = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(entries, hasLength(1));
        expect(entries.first.unitIdentifier, 'Berakhot');
      });

      test('returns entries ordered by completedAt descending', () async {
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 1, 1),
            completionNumber: 1,
            markedBy: 1,
          ),
        );
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Shabbat',
            unitDisplayNameHe: 'שבת',
            unitDisplayNameEn: 'Shabbat',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 1),
            completionNumber: 1,
            markedBy: 1,
          ),
        );

        final entries = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(entries.first.unitIdentifier, 'Shabbat'); // newer first
        expect(entries.last.unitIdentifier, 'Berakhot');
      });
    });

    group('getEntriesByCurriculum', () {
      test('filters by curriculum', () async {
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 1),
            completionNumber: 1,
            markedBy: 1,
          ),
        );
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'daf_yomi',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 2),
            completionNumber: 1,
            markedBy: 1,
          ),
        );

        final entries = await db.learningLedgerDao.getEntriesByCurriculum(
          1,
          'mishna',
        );
        expect(entries, hasLength(1));
        expect(entries.first.curriculumId, 'mishna');
      });
    });

    group('getCompletionCount', () {
      test('returns 0 when no entries exist', () async {
        final count = await db.learningLedgerDao.getCompletionCount(
          1,
          'mishna',
          'Berakhot',
        );
        expect(count, 0);
      });

      test('counts entries for the specific unit', () async {
        // Two completions of Berakhot
        for (var i = 1; i <= 2; i++) {
          await db.learningLedgerDao.insertEntry(
            LearningLedgerCompanion.insert(
              profileId: 1,
              curriculumId: 'mishna',
              unitType: 'masechta',
              unitIdentifier: 'Berakhot',
              unitDisplayNameHe: 'ברכות',
              unitDisplayNameEn: 'Berakhot',
              trackType: 'personal',
              completedAt: DateTime.utc(2026, i, 1),
              completionNumber: i,
              markedBy: 1,
            ),
          );
        }
        // One completion of Shabbat (should not count)
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Shabbat',
            unitDisplayNameHe: 'שבת',
            unitDisplayNameEn: 'Shabbat',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 1),
            completionNumber: 1,
            markedBy: 1,
          ),
        );

        final count = await db.learningLedgerDao.getCompletionCount(
          1,
          'mishna',
          'Berakhot',
        );
        expect(count, 2);
      });
    });

    group('getEntriesGroupedByCurriculum', () {
      test('groups entries by curriculum id', () async {
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 1),
            completionNumber: 1,
            markedBy: 1,
          ),
        );
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'daf_yomi',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 2),
            completionNumber: 1,
            markedBy: 1,
          ),
        );

        final grouped = await db.learningLedgerDao
            .getEntriesGroupedByCurriculum(1);
        expect(grouped.keys, containsAll(['mishna', 'daf_yomi']));
        expect(grouped['mishna'], hasLength(1));
        expect(grouped['daf_yomi'], hasLength(1));
      });
    });

    group('getLatestEntries', () {
      test('respects limit parameter', () async {
        for (var i = 1; i <= 5; i++) {
          await db.learningLedgerDao.insertEntry(
            LearningLedgerCompanion.insert(
              profileId: 1,
              curriculumId: 'mishna',
              unitType: 'masechta',
              unitIdentifier: 'Unit$i',
              unitDisplayNameHe: 'יחידה$i',
              unitDisplayNameEn: 'Unit$i',
              trackType: 'personal',
              completedAt: DateTime.utc(2026, 1, i),
              completionNumber: 1,
              markedBy: 1,
            ),
          );
        }

        final entries = await db.learningLedgerDao.getLatestEntries(
          1,
          limit: 3,
        );
        expect(entries, hasLength(3));
        // Most recent first
        expect(entries.first.unitIdentifier, 'Unit5');
      });
    });

    group('entryExists', () {
      test('returns false when entry does not exist', () async {
        final exists = await db.learningLedgerDao.entryExists(
          profileId: 1,
          curriculumId: 'mishna',
          unitIdentifier: 'Berakhot',
          trackType: 'personal',
          completedAt: DateTime.utc(2026, 3, 1),
        );
        expect(exists, false);
      });

      test('returns true when entry exists', () async {
        final completedAt = DateTime.utc(2026, 3, 1);
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: completedAt,
            completionNumber: 1,
            markedBy: 1,
          ),
        );

        final exists = await db.learningLedgerDao.entryExists(
          profileId: 1,
          curriculumId: 'mishna',
          unitIdentifier: 'Berakhot',
          trackType: 'personal',
          completedAt: completedAt,
        );
        expect(exists, true);
      });
    });

    group('isManual field', () {
      test('defaults to false', () async {
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 1),
            completionNumber: 1,
            markedBy: 1,
          ),
        );

        final entries = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(entries.first.isManual, false);
      });

      test('can be set to true for manual siyum', () async {
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 1),
            completionNumber: 1,
            markedBy: 1,
            isManual: const Value(true),
          ),
        );

        final entries = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(entries.first.isManual, true);
      });
    });

    group('trackId nullable', () {
      test('trackId can be null (survives track deletion)', () async {
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 1),
            completionNumber: 1,
            markedBy: 1,
          ),
        );

        final entries = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(entries.first.trackId, isNull);
      });

      test('trackId can be set', () async {
        await db.learningLedgerDao.insertEntry(
          LearningLedgerCompanion.insert(
            profileId: 1,
            curriculumId: 'mishna',
            unitType: 'masechta',
            unitIdentifier: 'Berakhot',
            unitDisplayNameHe: 'ברכות',
            unitDisplayNameEn: 'Berakhot',
            trackType: 'personal',
            trackId: const Value(42),
            completedAt: DateTime.utc(2026, 3, 1),
            completionNumber: 1,
            markedBy: 1,
          ),
        );

        final entries = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(entries.first.trackId, 42);
      });
    });
  });
}
