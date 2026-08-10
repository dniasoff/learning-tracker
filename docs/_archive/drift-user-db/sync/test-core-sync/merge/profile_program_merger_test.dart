/// Unit tests for [ProfileProgramMerger]: Phase-3 LWW symmetry +
/// persistUpdatedAt against a real [DriftMergeStore], and the
/// codec.encode() -> merger -> DB round-trip (Phase B invariant, including
/// the legacy no-updated_at fallback-to-trackingStartDate path).
///
/// AG-5 (AUD-app-05): consolidates test/sync/merge/lww_symmetric_test.dart's
/// ProfileProgramMerger group, test/sync/merge/persist_updated_at_test.dart's
/// ProfileProgramMerger case, and
/// test/sync/merge/profile_program_roundtrip_test.dart into the single file
/// mirroring lib/core/sync/merge/profile_program_merger.dart.
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

import '../../../helpers/test_database.dart';

// ── Phase 3 LWW-symmetry / persistUpdatedAt fixtures ────────────────────────
final _local = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _remoteNewer = DateTime.utc(2026, 5, 21, 13, 0, 0);
final _remoteOlder = DateTime.utc(2026, 5, 21, 11, 0, 0);
final _localSkew = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _remoteSkew = DateTime.utc(2026, 5, 21, 12, 0, 2);
final _localSynced = DateTime.utc(2026, 5, 21, 12, 0, 5);
final _remoteSyncedNewer = DateTime.utc(2026, 5, 21, 12, 0, 10);
const _profileId = 1;
final _ts = DateTime.utc(2026, 5, 21, 12, 0, 0);
final _syncedAt = DateTime.utc(2026, 5, 21, 12, 0, 30);

// ── codec.encode() → merger → DB round-trip fixtures ─────────────────────────
const _rtCodec = ProfileProgramCodec();
const _rtProfileId = 1;
const _rtCurriculumId = 'bavli';
const _rtProgramId = 2;
final _rtUpdatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _rtOlderUpdatedAt = DateTime.utc(2026, 6, 18, 9, 0, 0);
final _rtTrackingStart = DateTime.utc(2026, 1, 1);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('ProfileProgramMerger — LWW symmetry + persistence (real DriftMergeStore)', () {
    late UserDatabase db;
    late DriftMergeStore store;
    const profileId = 1;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      await seedProfile(db);
      store = DriftMergeStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    group('ProfileProgramMerger', () {
      late ProfileProgramMerger merger;

      setUp(() {
        merger = ProfileProgramMerger(store: store);
      });

      Map<String, dynamic> row({
        required DateTime updatedAt,
        DateTime? syncedAt,
      }) => {
        'profile_id': profileId,
        'curriculum_id': 'bavli',
        'program_id': 1,
        'tracking_start_date': _local.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
      };

      // R3-6 fix: naturalKey is just curriculumId — profileId is added by
      // _scopedKey inside the store; using '$profileId|bavli' here was the
      // same double-scoping bug that the merger had. All four tests below now
      // use 'bavli' directly, matching the TrackConfigMerger pattern.

      test('remote newer than local → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _remoteNewer);
      });

      test('local newer than remote → does NOT apply', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _local,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteOlder)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _local);
      });

      test('within ±5 s — remote synced_at newer → applies', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _localSkew,
          syncedAt: _localSynced,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteSkew, syncedAt: _remoteSyncedNewer)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _remoteSkew);
      });

      test('same synced_at — remote wins (convergence)', () async {
        await store.persistUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
          updatedAt: _localSkew,
          syncedAt: _localSynced,
        );

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: _remoteSkew, syncedAt: _localSynced)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.profileProgram,
          profileId: profileId,
          naturalKey: 'bavli',
        );
        expect(after, _remoteSkew);
      });

      // R3-6 regression: verify that the key written by the merger on a
      // successful apply is exactly the key that currentUpdatedAt reads back.
      // Before the fix the merger wrote '$profileId|$profileId|$curriculumId'
      // while the test read '$profileId|$curriculumId' — a permanent key miss
      // that made every subsequent remote pull look "new".
      test(
        'R3-6 regression — key written by merger matches key read back',
        () async {
          // Start with no local timestamp for this (profileId, curriculumId).
          final before = await store.currentUpdatedAt(
            kind: EntityKind.profileProgram,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(
            before,
            isNull,
            reason: 'no local timestamp before first merge',
          );

          // First merge: remote is applied because there is no local record.
          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteNewer)],
          );

          // The timestamp the merger persisted must be readable under the same
          // (profileId, 'bavli') natural key.
          final afterFirst = await store.currentUpdatedAt(
            kind: EntityKind.profileProgram,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(
            afterFirst,
            _remoteNewer,
            reason:
                'merger must write the scoped key that currentUpdatedAt reads',
          );

          // Second merge with an older remote: should NOT overwrite because local
          // is newer. This only passes if the key used by merge() == the key
          // used by currentUpdatedAt() — i.e., no double-scoping.
          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteOlder)],
          );

          final afterSecond = await store.currentUpdatedAt(
            kind: EntityKind.profileProgram,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(
            afterSecond,
            _remoteNewer,
            reason:
                'older remote must NOT overwrite the newer local — key mismatch '
                'would make every merge look new and allow silent overwrites',
          );
        },
      );
    });

    test('ProfileProgramMerger', () async {
      await ProfileProgramMerger(store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'profile_id': _profileId,
            'curriculum_id': 'bavli',
            'program_id': 1,
            'tracking_start_date': _ts.toIso8601String(),
            'updated_at': _ts.toIso8601String(),
            'synced_at': _syncedAt.toIso8601String(),
          },
        ],
      );

      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.profileProgram,
        // R3-6: natural key is the entity key only ('bavli'); profileId is added
        // by _scopedKey. Previously this was double-scoped ('$profileId|bavli').
        naturalKey: 'bavli',
        profileId: _profileId,
      );
      expect(updatedAt, _ts);
    });
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
          profileId: _rtProfileId,
          curriculumId: _rtCurriculumId,
          programId: _rtProgramId,
          trackingStartDate: _rtTrackingStart,
          trackingStartRef: 'Berakhot 2a',
          updatedAt: _rtUpdatedAt,
        );
        final payload = _rtCodec.encode(row);

        // The merger must accept the codec payload and write it to Drift.
        await merger.merge(profileId: _rtProfileId, rows: [payload]);

        // Assert: the row materialised in the DB — not skipped.
        final result = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(_rtProfileId, _rtCurriculumId);

        expect(
          result,
          isNotNull,
          reason:
              'ProfileProgramMerger must INSERT the row when codec.encode() '
              'payload is fed in — if null, the merge read-keys diverge from '
              'the codec write-keys (the push↔merge key-contract bug).',
        );
        expect(result!.programId, _rtProgramId);
        expect(result.curriculumType, _rtCurriculumId);
        expect(
          result.trackingStartDate?.toUtc(),
          _rtTrackingStart,
          reason: 'tracking_start_date must round-trip through codec',
        );
        expect(result.trackingStartRef, 'Berakhot 2a');
      },
    );

    test('updated_at is persisted after a successful merge', () async {
      final row = ProfileProgramRow(
        profileId: _rtProfileId,
        curriculumId: _rtCurriculumId,
        programId: _rtProgramId,
        updatedAt: _rtUpdatedAt,
      );
      await merger.merge(profileId: _rtProfileId, rows: [_rtCodec.encode(row)]);

      final persisted = await store.currentUpdatedAt(
        kind: EntityKind.profileProgram,
        profileId: _rtProfileId,
        // R3-6: natural key is curriculumId only; profileId is scoped by
        // _scopedKey inside currentUpdatedAt/persistUpdatedAt.
        naturalKey: _rtCurriculumId,
      );
      expect(
        persisted,
        _rtUpdatedAt,
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
          profileId: _rtProfileId,
          curriculumId: _rtCurriculumId,
          programId: _rtProgramId,
          updatedAt: _rtUpdatedAt,
        );
        await merger.merge(
          profileId: _rtProfileId,
          rows: [_rtCodec.encode(newer)],
        );

        // Then: try to merge an older row with programId=99 — must be ignored.
        final older = ProfileProgramRow(
          profileId: _rtProfileId,
          curriculumId: _rtCurriculumId,
          programId: 99,
          updatedAt: _rtOlderUpdatedAt,
        );
        await merger.merge(
          profileId: _rtProfileId,
          rows: [_rtCodec.encode(older)],
        );

        final result = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(_rtProfileId, _rtCurriculumId);

        expect(
          result?.programId,
          _rtProgramId,
          reason:
              'LWW: older remote must not overwrite a newer local row — '
              'programId should remain $_rtProgramId after the stale merge',
        );
      },
    );

    test('row without updated_at falls back to trackingStartDate for LWW '
        '(legacy payload compatibility)', () async {
      // A legacy Firestore doc with no updated_at but with tracking_start_date.
      // The merger must still apply it on first sync (no local row).
      const legacyPayload = <String, dynamic>{
        'profile_id': _rtProfileId,
        'curriculum_id': _rtCurriculumId,
        'program_id': _rtProgramId,
        'tracking_start_date': '2026-01-01T00:00:00.000Z',
        // no updated_at
      };

      await merger.merge(profileId: _rtProfileId, rows: [legacyPayload]);

      final result = await db.profileProgramDao
          .getProgramForProfileAndCurriculum(_rtProfileId, _rtCurriculumId);

      expect(
        result,
        isNotNull,
        reason:
            'Legacy payload without updated_at must still land in DB on '
            'first sync (no local row exists to beat)',
      );
      expect(result!.programId, _rtProgramId);
    });
  });
}
