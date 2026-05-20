// Extra coverage for LearningLedgerDao — dedup path, getEntryById,
// and getCompletionCountByTrack were not exercised by the baseline test.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db); // creates accounts(id=1) + learner_profiles(id=1)
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  LearningLedgerCompanion makeEntry({
    int profileId = 1,
    String curriculumId = 'bavli',
    String unitIdentifier = 'Berakhot',
    DateTime? completedAt,
    String? ulid,
    int? trackId,
  }) {
    return LearningLedgerCompanion.insert(
      profileId: profileId,
      curriculumId: curriculumId,
      entryScope: 'masechta',
      unitIdentifier: unitIdentifier,
      unitDisplayNameHe: 'ברכות',
      unitDisplayNameEn: 'Berakhot',
      trackType: 'personal',
      completedAt: completedAt ?? DateTime.utc(2026, 1, 1),
      completionNumber: 1,
      markedBy: 1,
      ulid: ulid != null ? Value(ulid) : const Value.absent(),
      trackId: trackId != null ? Value(trackId) : const Value.absent(),
    );
  }

  // ---------------------------------------------------------------------------
  // getEntryById
  // ---------------------------------------------------------------------------

  group('LearningLedgerDao.getEntryById', () {
    test('returns the entry for a known id', () async {
      final id = await db.learningLedgerDao.insertEntry(makeEntry());
      final row = await db.learningLedgerDao.getEntryById(id);
      expect(row, isNotNull);
      expect(row!.id, id);
      expect(row.unitIdentifier, 'Berakhot');
    });

    test('returns null for an unknown id', () async {
      final row = await db.learningLedgerDao.getEntryById(9999);
      expect(row, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // insertEntry — dedup path (INSERT OR IGNORE collision)
  // ---------------------------------------------------------------------------

  group('LearningLedgerDao.insertEntry — dedup / ulid collision', () {
    test(
      'second insert with same (profileId, ulid) returns id of existing row',
      () async {
        const testUlid = '01HQZZ000000000000000001';

        final id1 = await db.learningLedgerDao.insertEntry(
          makeEntry(ulid: testUlid),
        );
        // Same profile + ulid => INSERT OR IGNORE collapses; must return id1.
        final id2 = await db.learningLedgerDao.insertEntry(
          makeEntry(ulid: testUlid),
        );

        expect(id1, greaterThan(0));
        expect(id2, equals(id1));

        // Only one row should exist.
        final rows = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(rows, hasLength(1));
      },
    );

    test('different ulids produce two distinct rows', () async {
      const ulid1 = '01HQZZ000000000000000002';
      const ulid2 = '01HQZZ000000000000000003';

      final id1 = await db.learningLedgerDao.insertEntry(
        makeEntry(ulid: ulid1),
      );
      final id2 = await db.learningLedgerDao.insertEntry(
        makeEntry(
          ulid: ulid2,
          unitIdentifier: 'Shabbat',
          completedAt: DateTime.utc(2026, 2, 1),
        ),
      );

      expect(id1, isNot(id2));
      final rows = await db.learningLedgerDao.getEntriesByProfile(1);
      expect(rows, hasLength(2));
    });
  });

  // ---------------------------------------------------------------------------
  // getCompletionCountByTrack
  // ---------------------------------------------------------------------------

  group('LearningLedgerDao.getCompletionCountByTrack', () {
    late int trackId;

    setUp(() async {
      trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
    });

    test('returns 0 when no entries exist for the track', () async {
      final count = await db.learningLedgerDao.getCompletionCountByTrack(
        trackId,
        1,
        'bavli',
        'Berakhot',
      );
      expect(count, 0);
    });

    test(
      'counts only entries matching track + profile + curriculum + unit',
      () async {
        // Two completions of Berakhot on this track.
        await db.learningLedgerDao.insertEntry(
          makeEntry(trackId: trackId, completedAt: DateTime.utc(2026, 1, 1)),
        );
        await db.learningLedgerDao.insertEntry(
          makeEntry(
            trackId: trackId,
            completedAt: DateTime.utc(2026, 2, 1),
            ulid: '01HQZZ000000000000000010',
          ),
        );
        // One completion of a different unit — should not count.
        await db.learningLedgerDao.insertEntry(
          makeEntry(
            trackId: trackId,
            unitIdentifier: 'Shabbat',
            completedAt: DateTime.utc(2026, 3, 1),
            ulid: '01HQZZ000000000000000011',
          ),
        );

        final count = await db.learningLedgerDao.getCompletionCountByTrack(
          trackId,
          1,
          'bavli',
          'Berakhot',
        );
        expect(count, 2);
      },
    );

    test('is scoped to the correct track', () async {
      final otherTrackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await db.learningLedgerDao.insertEntry(makeEntry(trackId: otherTrackId));

      final count = await db.learningLedgerDao.getCompletionCountByTrack(
        trackId, // different track
        1,
        'bavli',
        'Berakhot',
      );
      expect(count, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // getEntriesByTrack
  // ---------------------------------------------------------------------------

  group('LearningLedgerDao.getEntriesByTrack', () {
    late int trackId;

    setUp(() async {
      trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
    });

    test('returns entries for the given track', () async {
      await db.learningLedgerDao.insertEntry(makeEntry(trackId: trackId));

      final rows = await db.learningLedgerDao.getEntriesByTrack(trackId, 1);
      expect(rows, hasLength(1));
      expect(rows.first.trackId, trackId);
    });

    test('returns empty list for a track with no entries', () async {
      final rows = await db.learningLedgerDao.getEntriesByTrack(999, 1);
      expect(rows, isEmpty);
    });
  });
}
