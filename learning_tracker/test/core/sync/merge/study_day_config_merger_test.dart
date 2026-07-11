/// Round-trip test: the canonical write serializer (StudyDayConfigCodec.encode)
/// must produce a payload that StudyDayConfigMerger accepts and persists.
///
/// This test guards the Phase B invariant: if the codec's encode() ever drifts
/// from the key names the merger reads, study-day configs will be silently
/// skipped on pull and cross-device sync breaks without any error. The test
/// MUST fail before the fix when there is a real mismatch, and pass after.
///
/// For study_day_configs the shapes were already consistent before Phase B, so
/// this test is simultaneously the regression gate and the proof of consistency.
///
/// AG-5 (AUD-app-05): relocated from
/// test/sync/merge/study_day_config_roundtrip_test.dart to its mirrored
/// path; also folds in test/sync/merge/lww_symmetric_test.dart's
/// StudyDayConfigMerger group (AUD-core-sync-03).
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/study_day_config_codec.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/study_day_config_merger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

const _codec = StudyDayConfigCodec();

const _profileId = 1;
const _curriculumId = 'bavli';

final _updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _olderUpdatedAt = DateTime.utc(2026, 6, 18, 9, 0, 0);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('study_day_config — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late StudyDayConfigMerger merger;
    late int trackId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      merger = StudyDayConfigMerger(db, store: DriftMergeStore(db));

      // Seed the account + profile so FK constraints on learner_profiles are met.
      await seedProfile(db);

      // Seed a curriculum_tracks row — study_day_configs.track_id FKs this table.
      trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: _profileId,
              curriculumId: _curriculumId,
              stateChangedAt: DateTimeFactory.nowUtc().subtract(
                const Duration(days: 1),
              ),
              activatedAt: DateTimeFactory.nowUtc().subtract(
                const Duration(days: 1),
              ),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        // Build the canonical write payload via the codec — exactly as
        // study_day_config_screen.dart and curriculum_activation_service.dart
        // now route through after Phase B unification.
        final row = StudyDayConfigRow(
          profileId: _profileId,
          curriculumId: _curriculumId,
          trackId: trackId,
          dayOfWeek: 1, // Monday
          dayType: 'study',
          updatedAt: _updatedAt,
        );
        final payload = _codec.encode(row);

        // The merger must accept the payload and write it to Drift.
        await merger.merge(profileId: _profileId, rows: [payload]);

        // Assert: the row materialised in the DB — not skipped.
        final result =
            await (db.select(db.studyDayConfigs)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId) &
                      t.dayOfWeek.equals(1) &
                      t.trackId.equals(trackId),
                ))
                .getSingleOrNull();

        expect(
          result,
          isNotNull,
          reason:
              'StudyDayConfigMerger must INSERT the row when codec.encode() '
              'payload is fed in — if null, the merge read-keys diverge from '
              'the codec write-keys (the push↔merge key-contract bug).',
        );
        expect(result!.dayType, 'study');
        expect(
          result.updatedAt.toUtc(),
          _updatedAt,
          reason:
              'updated_at must round-trip through the codec and be stored correctly',
        );
      },
    );

    test(
      'all 7 days round-trip when codec.encode() payloads are merged in bulk',
      () async {
        final payloads = List.generate(7, (i) {
          final dow = i + 1; // 1..7
          return _codec.encode(
            StudyDayConfigRow(
              profileId: _profileId,
              curriculumId: _curriculumId,
              trackId: trackId,
              dayOfWeek: dow,
              dayType: dow == 7 ? 'review' : 'study', // Sunday = review
              updatedAt: _updatedAt,
            ),
          );
        });

        await merger.merge(profileId: _profileId, rows: payloads);

        final rows =
            await (db.select(db.studyDayConfigs)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId),
                ))
                .get();

        expect(
          rows.length,
          7,
          reason: 'All 7 day-of-week rows must materialise from codec payloads',
        );

        final sunday = rows.firstWhere((r) => r.dayOfWeek == 7);
        expect(sunday.dayType, 'review');

        final monday = rows.firstWhere((r) => r.dayOfWeek == 1);
        expect(monday.dayType, 'study');
      },
    );

    test(
      'a second merge with an older updated_at is skipped (LWW wins local)',
      () async {
        // First: merge a newer row.
        final newer = StudyDayConfigRow(
          profileId: _profileId,
          curriculumId: _curriculumId,
          trackId: trackId,
          dayOfWeek: 3, // Wednesday
          dayType: 'study',
          updatedAt: _updatedAt,
        );
        await merger.merge(profileId: _profileId, rows: [_codec.encode(newer)]);

        // Then: try to merge an older row with a different dayType.
        final older = StudyDayConfigRow(
          profileId: _profileId,
          curriculumId: _curriculumId,
          trackId: trackId,
          dayOfWeek: 3,
          dayType: 'review',
          updatedAt: _olderUpdatedAt,
        );
        await merger.merge(profileId: _profileId, rows: [_codec.encode(older)]);

        final result =
            await (db.select(db.studyDayConfigs)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId) &
                      t.dayOfWeek.equals(3) &
                      t.trackId.equals(trackId),
                ))
                .getSingleOrNull();

        expect(
          result?.dayType,
          'study',
          reason:
              'LWW: older remote must not overwrite a newer local row — '
              'dayType should remain "study" after the stale "review" merge',
        );
      },
    );

    test('row with mismatched profileId is rejected', () async {
      // Encode with a different profileId — the merger must reject it.
      const wrongProfileId = 99;
      final row = StudyDayConfigRow(
        profileId: wrongProfileId,
        curriculumId: _curriculumId,
        trackId: trackId,
        dayOfWeek: 2,
        dayType: 'study',
        updatedAt: _updatedAt,
      );
      final payload = _codec.encode(row);

      // Merge with profileId=1 while the payload claims profileId=99.
      await merger.merge(profileId: _profileId, rows: [payload]);

      final result =
          await (db.select(db.studyDayConfigs)..where(
                (t) =>
                    t.profileId.equals(_profileId) &
                    t.curriculumId.equals(_curriculumId) &
                    t.dayOfWeek.equals(2),
              ))
              .getSingleOrNull();

      expect(
        result,
        isNull,
        reason:
            'A payload whose profile_id does not match the merge scope must '
            'be rejected — the merger must not insert it under the wrong profile',
      );
    });
  });

  // AUD-core-sync-03: StudyDayConfigMerger was the one remaining LWW merger
  // comparing raw `remote.isAfter(local)` via merge_rules.dart with zero
  // clock-skew tolerance; now routed through DriftMergeStore.remoteIsNewer
  // like every sibling merger.
  group('StudyDayConfigMerger — LWW symmetry (real DriftMergeStore)', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late StudyDayConfigMerger merger;
    late int seededTrackId;
    const profileId = _profileId;

    final local = DateTime.utc(2026, 5, 21, 12, 0, 0);
    final remoteNewer = DateTime.utc(2026, 5, 21, 13, 0, 0);
    final remoteOlder = DateTime.utc(2026, 5, 21, 11, 0, 0);
    final localSkew = DateTime.utc(2026, 5, 21, 12, 0, 0);
    final remoteSkew = DateTime.utc(2026, 5, 21, 12, 0, 2);
    final localSynced = DateTime.utc(2026, 5, 21, 12, 0, 5);
    final remoteSyncedNewer = DateTime.utc(2026, 5, 21, 12, 0, 10);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      merger = StudyDayConfigMerger(db, store: store);

      await seedProfile(db);
      seededTrackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: _curriculumId,
              stateChangedAt: local,
              activatedAt: local,
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    Map<String, dynamic> row({required DateTime updatedAt, DateTime? syncedAt}) => {
      'profile_id': profileId,
      'curriculum_id': _curriculumId,
      'track_id': seededTrackId,
      'day_of_week': 3,
      'day_type': 'study',
      'updated_at': updatedAt.toIso8601String(),
      if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
    };

    // Natural key is scoped by the REMOTE track id carried on the row
    // (== seededTrackId here, own-data sync), matching the merger's key
    // derivation.
    String naturalKey() => '$_curriculumId|3|$seededTrackId';

    test('remote newer than local → applies', () async {
      await store.persistUpdatedAt(
        kind: EntityKind.studyDayConfig,
        profileId: profileId,
        naturalKey: naturalKey(),
        updatedAt: local,
      );

      await merger.merge(
        profileId: profileId,
        rows: [row(updatedAt: remoteNewer)],
      );

      final after = await store.currentUpdatedAt(
        kind: EntityKind.studyDayConfig,
        profileId: profileId,
        naturalKey: naturalKey(),
      );
      expect(after, remoteNewer);
    });

    test('local newer than remote → does NOT apply', () async {
      await store.persistUpdatedAt(
        kind: EntityKind.studyDayConfig,
        profileId: profileId,
        naturalKey: naturalKey(),
        updatedAt: local,
      );

      await merger.merge(
        profileId: profileId,
        rows: [row(updatedAt: remoteOlder)],
      );

      final after = await store.currentUpdatedAt(
        kind: EntityKind.studyDayConfig,
        profileId: profileId,
        naturalKey: naturalKey(),
      );
      expect(after, local);
    });

    test('within ±5 s — remote synced_at newer → applies', () async {
      await store.persistUpdatedAt(
        kind: EntityKind.studyDayConfig,
        profileId: profileId,
        naturalKey: naturalKey(),
        updatedAt: localSkew,
        syncedAt: localSynced,
      );

      await merger.merge(
        profileId: profileId,
        rows: [row(updatedAt: remoteSkew, syncedAt: remoteSyncedNewer)],
      );

      final after = await store.currentUpdatedAt(
        kind: EntityKind.studyDayConfig,
        profileId: profileId,
        naturalKey: naturalKey(),
      );
      expect(after, remoteSkew);
    });

    // AUD-core-sync-03 AC1 — D15 clock-skew group: a fresh, newer,
    // un-pushed local edit (inside the ±5 s window, no synced_at) must NOT
    // be clobbered by a REMOTE whose client clock runs fast — the exact
    // scenario AUD-core-sync-03 names: "a device whose clock runs even a
    // few seconds fast will have its study-day-config edits always win".
    // Before the fix this merger compared raw `remote.isAfter(local)` via
    // merge_rules.dart with NO clock-skew tolerance and NO synced_at
    // fallback whatsoever, so it could not see that the server (the only
    // trustworthy clock) recorded the remote push as happening BEFORE the
    // local one.
    test(
      'D15: a fast-clocked remote must not win via raw isAfter — the '
      'server timestamp says it was pushed before the local edit',
      () async {
        // Local: edited AND pushed; server recorded synced_at = 12:00:05.
        final localUpdatedAt = DateTime.utc(2026, 5, 21, 12, 0, 0);
        final localSyncedAt = DateTime.utc(2026, 5, 21, 12, 0, 5);
        await store.persistUpdatedAt(
          kind: EntityKind.studyDayConfig,
          profileId: profileId,
          naturalKey: naturalKey(),
          updatedAt: localUpdatedAt,
          syncedAt: localSyncedAt,
        );

        // Remote: a device whose clock runs ~2 s fast. Its own updated_at
        // (12:00:02) LOOKS newer than local's raw updated_at (12:00:00),
        // but the Firestore server timestamp (synced_at = 11:59:50) proves
        // it was actually pushed BEFORE the local edit synced.
        final remoteUpdatedAt = DateTime.utc(2026, 5, 21, 12, 0, 2);
        final remoteSyncedAt = DateTime.utc(2026, 5, 21, 11, 59, 50);

        // Sanity check: a naive isAfter comparison alone would say remote
        // wins — this is precisely the pre-fix bug.
        expect(remoteUpdatedAt.isAfter(localUpdatedAt), isTrue);

        await merger.merge(
          profileId: profileId,
          rows: [row(updatedAt: remoteUpdatedAt, syncedAt: remoteSyncedAt)],
        );

        final after = await store.currentUpdatedAt(
          kind: EntityKind.studyDayConfig,
          profileId: profileId,
          naturalKey: naturalKey(),
        );
        expect(
          after,
          localUpdatedAt,
          reason:
              'a fast-clocked remote must not win via raw isAfter — the '
              'server timestamp says it was pushed before the local edit',
        );
      },
    );
  });
}
