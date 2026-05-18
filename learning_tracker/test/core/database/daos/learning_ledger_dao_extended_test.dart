/// Extended tests for LearningLedgerDao covering the duplicate-insert dedup
/// path (INSERT OR IGNORE → return existing id) and getCompletionCountByTrack.
library;

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    // Seed curriculum tracks so that trackId FK constraints are satisfied.
    // The helper entries use trackId 1 and 2, so insert both with distinct
    // track_type values to avoid the unique(profile_id, curriculum_id, track_type) constraint.
    await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            trackType: 'personal',
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            trackType: 'amud',
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  // Helper to build a minimal LearningLedgerCompanion.
  LearningLedgerCompanion entry({
    int profileId = 1,
    String curriculumId = 'mishnayos',
    String entryScope = 'masechta',
    String unitIdentifier = 'Berakhot',
    String ulid = 'ulid-001',
    int trackId = 1,
    DateTime? completedAt,
  }) => LearningLedgerCompanion.insert(
    profileId: profileId,
    ulid: Value(ulid),
    curriculumId: curriculumId,
    entryScope: entryScope,
    unitIdentifier: unitIdentifier,
    unitDisplayNameHe: 'ברכות',
    unitDisplayNameEn: 'Berakhot',
    trackType: 'personal',
    trackId: Value(trackId),
    completedAt: completedAt ?? DateTime.utc(2026, 5, 1),
    completionNumber: 1,
    markedBy: profileId,
  );

  group('LearningLedgerDao.insertEntry — dedup path', () {
    test(
      'returns same id when inserting duplicate (profileId, ulid)',
      () async {
        final firstId = await db.learningLedgerDao.insertEntry(
          entry(ulid: 'ulid-abc'),
        );
        final secondId = await db.learningLedgerDao.insertEntry(
          entry(ulid: 'ulid-abc'),
        );

        // Should return the same id on duplicate.
        expect(secondId, firstId);

        // DB should still have only one row.
        final entries = await db.learningLedgerDao.getEntriesByProfile(1);
        expect(entries, hasLength(1));
      },
    );

    test('inserts two distinct entries with different ulids', () async {
      final id1 = await db.learningLedgerDao.insertEntry(entry(ulid: 'ulid-1'));
      final id2 = await db.learningLedgerDao.insertEntry(entry(ulid: 'ulid-2'));

      expect(id1, isNot(id2));

      final entries = await db.learningLedgerDao.getEntriesByProfile(1);
      expect(entries, hasLength(2));
    });
  });

  group('LearningLedgerDao.getCompletionCountByTrack', () {
    test('returns 0 when no entries for the track', () async {
      final count = await db.learningLedgerDao.getCompletionCountByTrack(
        999,
        1,
        'mishnayos',
        'Berakhot',
      );
      expect(count, 0);
    });

    test(
      'returns count for the matching (trackId, profileId, curriculum, unit)',
      () async {
        // Insert two entries for track 1.
        await db.learningLedgerDao.insertEntry(
          entry(trackId: 1, ulid: 'a1', unitIdentifier: 'Berakhot'),
        );
        await db.learningLedgerDao.insertEntry(
          entry(trackId: 1, ulid: 'a2', unitIdentifier: 'Berakhot'),
        );
        // Insert one entry for track 2 (should not be counted).
        await db.learningLedgerDao.insertEntry(
          entry(trackId: 2, ulid: 'b1', unitIdentifier: 'Berakhot'),
        );

        final count = await db.learningLedgerDao.getCompletionCountByTrack(
          1,
          1,
          'mishnayos',
          'Berakhot',
        );
        expect(count, 2);
      },
    );

    test('does not count entries for different unit', () async {
      await db.learningLedgerDao.insertEntry(
        entry(trackId: 1, ulid: 'x1', unitIdentifier: 'Berakhot'),
      );
      await db.learningLedgerDao.insertEntry(
        entry(trackId: 1, ulid: 'x2', unitIdentifier: 'Shabbat'),
      );

      final countBerakhot = await db.learningLedgerDao
          .getCompletionCountByTrack(1, 1, 'mishnayos', 'Berakhot');
      final countShabbat = await db.learningLedgerDao.getCompletionCountByTrack(
        1,
        1,
        'mishnayos',
        'Shabbat',
      );

      expect(countBerakhot, 1);
      expect(countShabbat, 1);
    });
  });
}
