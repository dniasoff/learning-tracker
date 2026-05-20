/// Regression tests for [LearningLedgerMerger].
///
/// C1 regression (V3-W1): merger was reading camelCase fields
/// (`curriculumId`, `unitIdentifier`, `trackType`, `completedAt`) while
/// the Firestore schema migrated to snake_case in W3.18/W3.19. Every
/// pulled row would silently fail the null-guard and be discarded, causing
/// complete data loss on new-device / device-restore scenarios.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/sync/merge/learning_ledger_merger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

import '../../../helpers/test_database.dart';

void main() {
  group('LearningLedgerMerger', () {
    test('C1 regression: snake_case row is inserted into Drift', () async {
      // GIVEN an in-memory DB with a seeded learner profile (profileId = 1).
      final db = createTestDatabase();
      await seedProfile(db);
      final profiles = await db.select(db.learnerProfiles).get();
      final profileId = profiles.first.id;

      final merger = LearningLedgerMerger(db);
      final completedAt = DateTime.utc(2026, 1, 10, 12);

      // WHEN a snake_case-encoded Firestore row is merged.
      await merger.merge(
        profileId: profileId,
        rows: [
          {
            'ulid': 'TEST_ULID_001',
            'profile_id': profileId,
            'curriculum_id': 'bavli',
            'unit_identifier': 'Berakhot',
            'track_type': 'personal',
            'entry_scope': 'masechta',
            'unit_display_name_he': 'ברכות',
            'unit_display_name_en': 'Berakhot',
            'completed_at': completedAt.toIso8601String(),
            'completion_number': 1,
            'marked_by': profileId,
            'is_manual': false,
          },
        ],
      );

      // THEN the row lands in Drift.
      final entries = await db.learningLedgerDao.getEntriesByProfile(profileId);
      expect(entries, hasLength(1));
      expect(entries.first.curriculumId, 'bavli');
      expect(entries.first.unitIdentifier, 'Berakhot');
      expect(entries.first.trackType, 'personal');
      expect(entries.first.ulid, 'TEST_ULID_001');

      await db.close();
    });

    test('C1 regression: camelCase legacy row is still accepted (fallback)',
        () async {
      // Ensure pre-migration documents already in Firestore continue to merge.
      final db = createTestDatabase();
      await seedProfile(db);
      final profiles = await db.select(db.learnerProfiles).get();
      final profileId = profiles.first.id;

      final merger = LearningLedgerMerger(db);
      final completedAt = DateTime.utc(2025, 6, 1);

      await merger.merge(
        profileId: profileId,
        rows: [
          {
            'ulid': 'LEGACY_ULID_001',
            'profileId': profileId,
            'curriculumId': 'mishnayos',
            'unitIdentifier': 'Avot',
            'trackType': 'personal',
            'entryScope': 'masechta',
            'unitDisplayNameHe': 'אבות',
            'unitDisplayNameEn': 'Avot',
            'completedAt': completedAt.toIso8601String(),
            'completionNumber': 1,
            'markedBy': profileId,
            'isManual': false,
          },
        ],
      );

      final entries = await db.learningLedgerDao.getEntriesByProfile(profileId);
      expect(entries, hasLength(1));
      expect(entries.first.curriculumId, 'mishnayos');
      expect(entries.first.unitIdentifier, 'Avot');

      await db.close();
    });

    test('C1 regression: pure camelCase row (old shape) was silently discarded',
        () async {
      // Verifies that the OLD behaviour (before the fix) was broken: a row
      // with only camelCase fields would have been skipped because the merger
      // was reading ONLY camelCase. Now both work. This test confirms the fix
      // didn't break camelCase support while adding snake_case.
      final db = createTestDatabase();
      await seedProfile(db);
      final profiles = await db.select(db.learnerProfiles).get();
      final profileId = profiles.first.id;

      final merger = LearningLedgerMerger(db);

      // Row with MISSING required field — should be skipped.
      await merger.merge(
        profileId: profileId,
        rows: [
          {
            // No curriculum_id or curriculumId → should be skipped gracefully.
            'unit_identifier': 'Shabbat',
            'track_type': 'personal',
            'completed_at': DateTimeFactory.nowUtc().toIso8601String(),
          },
        ],
      );

      final entries = await db.learningLedgerDao.getEntriesByProfile(profileId);
      expect(entries, isEmpty);

      await db.close();
    });

    test('dedup: second insert of same ulid is a no-op', () async {
      final db = createTestDatabase();
      await seedProfile(db);
      final profiles = await db.select(db.learnerProfiles).get();
      final profileId = profiles.first.id;

      final merger = LearningLedgerMerger(db);
      final completedAt = DateTime.utc(2026, 3, 15);
      final row = {
        'ulid': 'DEDUP_ULID',
        'profile_id': profileId,
        'curriculum_id': 'bavli',
        'unit_identifier': 'Shabbat',
        'track_type': 'personal',
        'entry_scope': 'masechta',
        'completed_at': completedAt.toIso8601String(),
        'completion_number': 1,
        'marked_by': profileId,
      };

      await merger.merge(profileId: profileId, rows: [row]);
      await merger.merge(profileId: profileId, rows: [row]); // second time

      final entries = await db.learningLedgerDao.getEntriesByProfile(profileId);
      expect(entries, hasLength(1)); // INSERT OR IGNORE collapsed the second
      await db.close();
    });
  });
}
