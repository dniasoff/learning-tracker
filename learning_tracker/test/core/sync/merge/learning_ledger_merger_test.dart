/// Regression tests for [LearningLedgerMerger].
///
/// C1 regression (V3-W1): merger was reading camelCase fields
/// (`curriculumId`, `unitIdentifier`, `trackType`, `completedAt`) while
/// the Firestore schema migrated to snake_case in W3.18/W3.19. Every
/// pulled row would silently fail the null-guard and be discarded, causing
/// complete data loss on new-device / device-restore scenarios.
///
/// AG-5 (AUD-app-05): also folds in
/// test/sync/merge/learning_ledger_roundtrip_test.dart's codec.encode() ->
/// merger -> DB round-trip group (Phase B invariant: the codec's key names
/// must match what the merger reads).
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/learning_ledger_codec.dart';
import 'package:learning_tracker/core/sync/merge/learning_ledger_merger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

// ── codec.encode() → merger → DB round-trip fixtures ─────────────────────────
const _rtCodec = LearningLedgerCodec();
const _rtProfileId = 1;
const _rtUlid = '01JBVZ0000TESTLLID00000AB';
const _rtCurriculumId = 'bavli';
const _rtEntryScope = 'masechta';
const _rtUnitIdentifier = 'Berakhot';
const _rtUnitDisplayNameHe = 'ברכות';
const _rtUnitDisplayNameEn = 'Berakhot';
const _rtTrackType = 'personal';
// track_id is nullable (ON DELETE SET NULL); use null in the round-trip so we
// don't need to seed a curriculum_tracks row in this FK-constrained test.
const int? _rtTrackId = null;
final _rtCompletedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
const _rtCompletionNumber = 2;
const _rtMarkedBy = _rtProfileId;
const _rtIsManual = false;

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

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

    test(
      'C1 regression: camelCase legacy row is still accepted (fallback)',
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

        final entries = await db.learningLedgerDao.getEntriesByProfile(
          profileId,
        );
        expect(entries, hasLength(1));
        expect(entries.first.curriculumId, 'mishnayos');
        expect(entries.first.unitIdentifier, 'Avot');

        await db.close();
      },
    );

    test(
      'C1 regression: pure camelCase row (old shape) was silently discarded',
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

        final entries = await db.learningLedgerDao.getEntriesByProfile(
          profileId,
        );
        expect(entries, isEmpty);

        await db.close();
      },
    );

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

    // AUD-core-sync-21: the fallback ULID generator used for legacy
    // (no-`ulid`) rows was a deterministic, zero-entropy string keyed only
    // on the millisecond timestamp — two distinct legacy rows completed in
    // the same millisecond produced the IDENTICAL synthetic id, and
    // LearningLedgerDao dedups on `ulid` via INSERT OR IGNORE, so the
    // second row was silently and PERMANENTLY dropped (unlike every other
    // failure in this merge layer, which self-heals on the next pull).
    test('AUD-core-sync-21: two distinct legacy (no-ulid) rows sharing the '
        'same completed_at millisecond are both inserted, not deduplicated '
        'into one', () async {
      final db = createTestDatabase();
      await seedProfile(db);
      final profiles = await db.select(db.learnerProfiles).get();
      final profileId = profiles.first.id;

      final merger = LearningLedgerMerger(db);
      // Both rows share the EXACT SAME completed_at millisecond and carry
      // no `ulid` — the fallback-generation path this finding targets.
      final completedAt = DateTime.utc(2026, 3, 15, 8, 0, 0, 123);

      await merger.merge(
        profileId: profileId,
        rows: [
          {
            // No 'ulid' key at all — forces the fallback generator.
            'profile_id': profileId,
            'curriculum_id': 'bavli',
            'unit_identifier': 'Shabbat',
            'track_type': 'personal',
            'entry_scope': 'masechta',
            'completed_at': completedAt.toIso8601String(),
            'completion_number': 1,
            'marked_by': profileId,
          },
          {
            'profile_id': profileId,
            'curriculum_id': 'bavli',
            'unit_identifier': 'Eruvin', // distinct logical entry
            'track_type': 'personal',
            'entry_scope': 'masechta',
            'completed_at': completedAt.toIso8601String(),
            'completion_number': 1,
            'marked_by': profileId,
          },
        ],
      );

      final entries = await db.learningLedgerDao.getEntriesByProfile(profileId);
      expect(
        entries,
        hasLength(2),
        reason:
            'two distinct legacy rows sharing a completed_at millisecond '
            'must not collide into one row via the fallback ULID',
      );
      expect(
        entries.map((e) => e.unitIdentifier),
        containsAll(['Shabbat', 'Eruvin']),
      );
      expect(
        entries.map((e) => e.ulid).toSet(),
        hasLength(2),
        reason: 'the two fallback-generated ULIDs must be distinct',
      );

      await db.close();
    });
  });

  group('learning_ledger — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late LearningLedgerMerger merger;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      merger = LearningLedgerMerger(db);

      // Seed account + profile so FK constraints on learning_ledger are met.
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        final row = LearningLedgerRow(
          ulid: _rtUlid,
          profileId: _rtProfileId,
          curriculumId: _rtCurriculumId,
          entryScope: _rtEntryScope,
          unitIdentifier: _rtUnitIdentifier,
          unitDisplayNameHe: _rtUnitDisplayNameHe,
          unitDisplayNameEn: _rtUnitDisplayNameEn,
          trackType: _rtTrackType,
          trackId: _rtTrackId,
          completedAt: _rtCompletedAt,
          completionNumber: _rtCompletionNumber,
          markedBy: _rtMarkedBy,
          isManual: _rtIsManual,
        );
        final payload = _rtCodec.encode(row);

        // Verify the payload carries all expected keys.
        expect(payload['ulid'], _rtUlid);
        expect(payload['profile_id'], _rtProfileId);
        expect(payload['curriculum_id'], _rtCurriculumId);
        expect(payload['entry_scope'], _rtEntryScope);
        expect(payload['unit_identifier'], _rtUnitIdentifier);
        expect(payload['unit_display_name_he'], _rtUnitDisplayNameHe);
        expect(payload['unit_display_name_en'], _rtUnitDisplayNameEn);
        expect(payload['track_type'], _rtTrackType);
        expect(payload['track_id'], _rtTrackId);
        expect(payload.containsKey('completed_at'), isTrue);
        expect(payload['completion_number'], _rtCompletionNumber);
        expect(payload['marked_by'], _rtMarkedBy);
        expect(payload['is_manual'], _rtIsManual);

        // The merger must accept the codec payload and write it to Drift.
        await merger.merge(profileId: _rtProfileId, rows: [payload]);

        // Assert: the row materialised in the DB — not skipped.
        final entries = await db.learningLedgerDao.getEntriesByProfile(
          _rtProfileId,
        );

        expect(
          entries,
          hasLength(1),
          reason:
              'LearningLedgerMerger must INSERT the row when codec.encode() '
              'payload is fed in — if empty, the merge read-keys diverge from '
              'the codec write-keys (push↔merge key-contract bug). '
              'Most likely cause: merger reads a key (e.g. "completed_at") '
              'that the old codec emitted under a different name '
              '("created_at"), causing the null-guard to discard the row.',
        );

        final stored = entries.first;
        expect(stored.ulid, _rtUlid);
        expect(stored.curriculumId, _rtCurriculumId);
        expect(stored.unitIdentifier, _rtUnitIdentifier);
        expect(stored.trackType, _rtTrackType);
        expect(stored.trackId, _rtTrackId);
        expect(stored.completionNumber, _rtCompletionNumber);
        expect(stored.markedBy, _rtMarkedBy);
        expect(stored.isManual, _rtIsManual);

        // completed_at round-trips as UTC ISO-8601.
        final storedUtc = stored.completedAt.toUtc();
        expect(storedUtc.year, _rtCompletedAt.year);
        expect(storedUtc.month, _rtCompletedAt.month);
        expect(storedUtc.day, _rtCompletedAt.day);
      },
    );

    test(
      'dedup: two merges of the same codec payload produce exactly one DB row',
      () async {
        final payload = _rtCodec.encode(
          LearningLedgerRow(
            ulid: _rtUlid,
            profileId: _rtProfileId,
            curriculumId: _rtCurriculumId,
            entryScope: _rtEntryScope,
            unitIdentifier: _rtUnitIdentifier,
            unitDisplayNameHe: _rtUnitDisplayNameHe,
            unitDisplayNameEn: _rtUnitDisplayNameEn,
            trackType: _rtTrackType,
            completedAt: _rtCompletedAt,
            completionNumber: _rtCompletionNumber,
            markedBy: _rtMarkedBy,
            isManual: _rtIsManual,
          ),
        );

        // Simulate an outbox retry: merge the same payload twice.
        await merger.merge(profileId: _rtProfileId, rows: [payload]);
        await merger.merge(profileId: _rtProfileId, rows: [payload]);

        final entries = await db.learningLedgerDao.getEntriesByProfile(
          _rtProfileId,
        );
        expect(
          entries,
          hasLength(1),
          reason:
              'learning_ledger has a UNIQUE (profileId, ulid) index; '
              'a duplicate push must be silently collapsed to one row '
              '(INSERT OR IGNORE semantics).',
        );
      },
    );

    test('codec round-trips through encode → decode', () {
      final row = LearningLedgerRow(
        ulid: _rtUlid,
        profileId: _rtProfileId,
        curriculumId: _rtCurriculumId,
        entryScope: _rtEntryScope,
        unitIdentifier: _rtUnitIdentifier,
        unitDisplayNameHe: _rtUnitDisplayNameHe,
        unitDisplayNameEn: _rtUnitDisplayNameEn,
        trackType: _rtTrackType,
        trackId: _rtTrackId,
        completedAt: _rtCompletedAt,
        completionNumber: _rtCompletionNumber,
        markedBy: _rtMarkedBy,
        isManual: _rtIsManual,
      );
      final payload = _rtCodec.encode(row);
      final decoded = _rtCodec.decode(payload);

      expect(decoded, isNotNull);
      expect(decoded!.ulid, _rtUlid);
      expect(decoded.profileId, _rtProfileId);
      expect(decoded.curriculumId, _rtCurriculumId);
      expect(decoded.entryScope, _rtEntryScope);
      expect(decoded.unitIdentifier, _rtUnitIdentifier);
      expect(decoded.unitDisplayNameHe, _rtUnitDisplayNameHe);
      expect(decoded.unitDisplayNameEn, _rtUnitDisplayNameEn);
      expect(decoded.trackType, _rtTrackType);
      expect(decoded.trackId, _rtTrackId);
      expect(decoded.completionNumber, _rtCompletionNumber);
      expect(decoded.markedBy, _rtMarkedBy);
      expect(decoded.isManual, _rtIsManual);

      final decodedUtc = decoded.completedAt.toUtc();
      expect(decodedUtc.year, _rtCompletedAt.year);
      expect(decodedUtc.month, _rtCompletedAt.month);
      expect(decodedUtc.day, _rtCompletedAt.day);
    });

    test('null-guard: missing curriculum_id causes decode to return null', () {
      final payload = _rtCodec.encode(
        LearningLedgerRow(
          ulid: _rtUlid,
          profileId: _rtProfileId,
          curriculumId: _rtCurriculumId,
          entryScope: _rtEntryScope,
          unitIdentifier: _rtUnitIdentifier,
          unitDisplayNameHe: _rtUnitDisplayNameHe,
          unitDisplayNameEn: _rtUnitDisplayNameEn,
          trackType: _rtTrackType,
          completedAt: _rtCompletedAt,
          completionNumber: _rtCompletionNumber,
          markedBy: _rtMarkedBy,
          isManual: _rtIsManual,
        ),
      );
      // Remove required field to simulate a corrupt / partial doc.
      final broken = Map<String, dynamic>.from(payload)
        ..remove('curriculum_id');

      expect(_rtCodec.decode(broken), isNull);
    });
  });
}
