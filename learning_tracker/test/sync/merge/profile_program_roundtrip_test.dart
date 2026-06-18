/// Round-trip test: the canonical write serializer (ProfileProgramCodec.encode)
/// must produce a payload that ProfileProgramMerger accepts and persists.
///
/// This test guards the Phase B invariant: if the codec's encode() ever drifts
/// from the key names the merger reads, profile-program assignments will be
/// silently skipped on pull and cross-device sync breaks without any error.
///
/// Before Phase B, codec.encode() did NOT emit `updated_at`, so the merger
/// fell back to `trackingStartDate` for LWW. After Phase B, encode() emits
/// `updated_at` and the merger uses it directly. This test verifies the
/// full round-trip and that the LWW field is honoured.
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/profile_program_codec.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/profile_program_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

const _codec = ProfileProgramCodec();

const _profileId = 1;
const _curriculumId = 'bavli';
const _programId = 2;

final _updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _olderUpdatedAt = DateTime.utc(2026, 6, 18, 9, 0, 0);
final _trackingStart = DateTime.utc(2026, 1, 1);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('profile_program — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late ProfileProgramMerger merger;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      merger = ProfileProgramMerger(store: store);

      // Seed account + profile so FK constraints on profile_programs are met.
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        final row = ProfileProgramRow(
          profileId: _profileId,
          curriculumId: _curriculumId,
          programId: _programId,
          trackingStartDate: _trackingStart,
          trackingStartRef: 'Berakhot 2a',
          updatedAt: _updatedAt,
        );
        final payload = _codec.encode(row);

        // The merger must accept the codec payload and write it to Drift.
        await merger.merge(profileId: _profileId, rows: [payload]);

        // Assert: the row materialised in the DB — not skipped.
        final result = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(_profileId, _curriculumId);

        expect(
          result,
          isNotNull,
          reason:
              'ProfileProgramMerger must INSERT the row when codec.encode() '
              'payload is fed in — if null, the merge read-keys diverge from '
              'the codec write-keys (the push↔merge key-contract bug).',
        );
        expect(result!.programId, _programId);
        expect(result.curriculumType, _curriculumId);
        expect(
          result.trackingStartDate?.toUtc(),
          _trackingStart,
          reason: 'tracking_start_date must round-trip through codec',
        );
        expect(result.trackingStartRef, 'Berakhot 2a');
      },
    );

    test('updated_at is persisted after a successful merge', () async {
      final row = ProfileProgramRow(
        profileId: _profileId,
        curriculumId: _curriculumId,
        programId: _programId,
        updatedAt: _updatedAt,
      );
      await merger.merge(profileId: _profileId, rows: [_codec.encode(row)]);

      final persisted = await store.currentUpdatedAt(
        kind: EntityKind.profileProgram,
        profileId: _profileId,
        // R3-6: natural key is curriculumId only; profileId is scoped by
        // _scopedKey inside currentUpdatedAt/persistUpdatedAt.
        naturalKey: _curriculumId,
      );
      expect(
        persisted,
        _updatedAt,
        reason:
            'persistUpdatedAt must record updated_at so subsequent pulls '
            'arbitrate LWW symmetrically',
      );
    });

    test(
      'a second merge with an older updated_at is skipped (LWW wins local)',
      () async {
        // First: merge a newer row with programId=2.
        final newer = ProfileProgramRow(
          profileId: _profileId,
          curriculumId: _curriculumId,
          programId: _programId,
          updatedAt: _updatedAt,
        );
        await merger.merge(profileId: _profileId, rows: [_codec.encode(newer)]);

        // Then: try to merge an older row with programId=99 — must be ignored.
        final older = ProfileProgramRow(
          profileId: _profileId,
          curriculumId: _curriculumId,
          programId: 99,
          updatedAt: _olderUpdatedAt,
        );
        await merger.merge(profileId: _profileId, rows: [_codec.encode(older)]);

        final result = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(_profileId, _curriculumId);

        expect(
          result?.programId,
          _programId,
          reason:
              'LWW: older remote must not overwrite a newer local row — '
              'programId should remain $_programId after the stale merge',
        );
      },
    );

    test(
      'row without updated_at falls back to trackingStartDate for LWW '
      '(legacy payload compatibility)',
      () async {
        // A legacy Firestore doc with no updated_at but with tracking_start_date.
        // The merger must still apply it on first sync (no local row).
        const legacyPayload = <String, dynamic>{
          'profile_id': _profileId,
          'curriculum_id': _curriculumId,
          'program_id': _programId,
          'tracking_start_date': '2026-01-01T00:00:00.000Z',
          // no updated_at
        };

        await merger.merge(profileId: _profileId, rows: [legacyPayload]);

        final result = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(_profileId, _curriculumId);

        expect(
          result,
          isNotNull,
          reason:
              'Legacy payload without updated_at must still land in DB on '
              'first sync (no local row exists to beat)',
        );
        expect(result!.programId, _programId);
      },
    );
  });
}
