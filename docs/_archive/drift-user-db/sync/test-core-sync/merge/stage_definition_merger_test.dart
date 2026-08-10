/// Unit tests for [StageDefinitionMerger]: Phase-3 LWW symmetry +
/// persistUpdatedAt against a real [DriftMergeStore], and the
/// codec.encode() -> merger -> DB round-trip (Phase B invariant, including
/// the legacy Map-typed schedule back-compat path).
///
/// AG-5 (AUD-app-05): consolidates test/sync/merge/lww_symmetric_test.dart's
/// StageDefinitionMerger group, test/sync/merge/persist_updated_at_test.dart's
/// StageDefinitionMerger case, and
/// test/sync/merge/stage_definitions_roundtrip_test.dart into the single
/// file mirroring lib/core/sync/merge/stage_definition_merger.dart.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/stage_definition_codec.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/stage_definition_merger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
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
const _codec = StageDefinitionCodec();
const _curriculumId = 'bavli';
final _updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _olderUpdatedAt = DateTime.utc(2026, 6, 18, 9, 0, 0);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group(
    'StageDefinitionMerger — LWW symmetry + persistence (real DriftMergeStore)',
    () {
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

      group('StageDefinitionMerger', () {
        late StageDefinitionMerger merger;
        late int seededTrackId;

        setUp(() async {
          merger = StageDefinitionMerger(store: store);
          // stage_definitions.track_id FKs curriculum_tracks(id); seed one so
          // the merger's upsert doesn't fail with SqliteException(787).
          seededTrackId = await db
              .into(db.curriculumTracks)
              .insert(
                CurriculumTracksCompanion.insert(
                  profileId: profileId,
                  curriculumId: 'bavli',
                  stateChangedAt: _local,
                  activatedAt: _local,
                ),
              );
        });

        Map<String, dynamic> row({
          required DateTime updatedAt,
          DateTime? syncedAt,
        }) => {
          'curriculum_id': 'bavli',
          'track_id': seededTrackId,
          'stage_order': 0,
          'stage_name': 'learning',
          'is_default': true,
          'updated_at': updatedAt.toIso8601String(),
          if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
        };

        test('remote newer than local → applies', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.stageDefinition,
            profileId: profileId,
            naturalKey: 'bavli|$seededTrackId|0',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteNewer)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.stageDefinition,
            profileId: profileId,
            naturalKey: 'bavli|$seededTrackId|0',
          );
          expect(after, _remoteNewer);
        });

        test('local newer than remote → does NOT apply', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.stageDefinition,
            profileId: profileId,
            naturalKey: 'bavli|$seededTrackId|0',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteOlder)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.stageDefinition,
            profileId: profileId,
            naturalKey: 'bavli|$seededTrackId|0',
          );
          expect(after, _local);
        });

        test('within ±5 s — remote synced_at newer → applies', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.stageDefinition,
            profileId: profileId,
            naturalKey: 'bavli|$seededTrackId|0',
            updatedAt: _localSkew,
            syncedAt: _localSynced,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteSkew, syncedAt: _remoteSyncedNewer)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.stageDefinition,
            profileId: profileId,
            naturalKey: 'bavli|$seededTrackId|0',
          );
          expect(after, _remoteSkew);
        });
      });

      test('StageDefinitionMerger', () async {
        // stage_definitions.track_id FKs curriculum_tracks(id).
        final trackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: _profileId,
                curriculumId: 'bavli',
                stateChangedAt: _ts.subtract(const Duration(days: 1)),
                activatedAt: _ts.subtract(const Duration(days: 1)),
              ),
            );

        await StageDefinitionMerger(store: store).merge(
          profileId: _profileId,
          rows: [
            {
              'curriculum_id': 'bavli',
              'track_id': trackId,
              'stage_order': 0,
              'stage_name': 'learning',
              'is_default': true,
              'updated_at': _ts.toIso8601String(),
              'synced_at': _syncedAt.toIso8601String(),
            },
          ],
        );

        final updatedAt = await store.currentUpdatedAt(
          kind: EntityKind.stageDefinition,
          profileId: _profileId,
          naturalKey: 'bavli|$trackId|0',
        );
        expect(updatedAt, _ts);
      });
    },
  );

  group('stage_definitions — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late StageDefinitionMerger merger;
    late int trackId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      merger = StageDefinitionMerger(store: store);

      // Seed account + profile so FK constraints are satisfied.
      await seedProfile(db);

      // Seed a curriculum_tracks row — stage_definitions.track_id FKs this.
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
        // StageDefinitionRepositoryImpl now routes through after Phase B.
        final row = StageDefinitionRow(
          curriculumId: _curriculumId,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'לימוד',
          schedule: '{"type":"delay","delay_days":0}',
          isDefault: true,
          updatedAt: _updatedAt,
        );
        final payload = _codec.encode(row);

        // The merger must accept the payload and write it to Drift.
        await merger.merge(profileId: _profileId, rows: [payload]);

        // Assert: the row materialised in the DB — not skipped.
        final result =
            await (db.select(db.stageDefinitions)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId) &
                      t.trackId.equals(trackId) &
                      t.stageOrder.equals(1),
                ))
                .getSingleOrNull();

        expect(
          result,
          isNotNull,
          reason:
              'StageDefinitionMerger must INSERT the row when codec.encode() '
              'payload is fed in — if null, the merge read-keys diverge from '
              'the codec write-keys (the push↔merge key-contract bug).',
        );
        expect(result!.stageName, 'לימוד');
        expect(result.isDefault, isTrue);
        expect(result.schedule, '{"type":"delay","delay_days":0}');
        expect(
          result.updatedAt.toUtc(),
          _updatedAt,
          reason: 'updated_at must round-trip through the codec and be stored',
        );
      },
    );

    test(
      'all three default stages round-trip when codec payloads are merged in bulk',
      () async {
        final stages = [
          StageDefinitionRow(
            curriculumId: _curriculumId,
            trackId: trackId,
            stageOrder: 1,
            stageName: 'לימוד',
            schedule: '{"type":"delay","delay_days":0}',
            isDefault: true,
            updatedAt: _updatedAt,
          ),
          StageDefinitionRow(
            curriculumId: _curriculumId,
            trackId: trackId,
            stageOrder: 2,
            stageName: "חזרה א'",
            schedule: '{"type":"delay","delay_days":1}',
            isDefault: true,
            updatedAt: _updatedAt,
          ),
          StageDefinitionRow(
            curriculumId: _curriculumId,
            trackId: trackId,
            stageOrder: 3,
            stageName: "חזרה ב'",
            schedule: '{"type":"delay","delay_days":7}',
            isDefault: true,
            updatedAt: _updatedAt,
          ),
        ];

        final payloads = stages.map(_codec.encode).toList();
        await merger.merge(profileId: _profileId, rows: payloads);

        final rows =
            await (db.select(db.stageDefinitions)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId),
                ))
                .get();

        expect(
          rows.length,
          3,
          reason:
              'All 3 default stage rows must materialise from codec payloads',
        );

        final stage3 = rows.firstWhere((r) => r.stageOrder == 3);
        expect(stage3.schedule, '{"type":"delay","delay_days":7}');
      },
    );

    test(
      'a second merge with an older updated_at is skipped (LWW wins local)',
      () async {
        // First: merge a newer row.
        final newer = StageDefinitionRow(
          curriculumId: _curriculumId,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'לימוד — new',
          schedule: '{"type":"delay","delay_days":0}',
          isDefault: true,
          updatedAt: _updatedAt,
        );
        await merger.merge(profileId: _profileId, rows: [_codec.encode(newer)]);

        // Then: try to merge an older row with a different stageName.
        final older = StageDefinitionRow(
          curriculumId: _curriculumId,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'לימוד — old',
          schedule: '{"type":"delay","delay_days":0}',
          isDefault: true,
          updatedAt: _olderUpdatedAt,
        );
        await merger.merge(profileId: _profileId, rows: [_codec.encode(older)]);

        final result =
            await (db.select(db.stageDefinitions)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId) &
                      t.stageOrder.equals(1),
                ))
                .getSingleOrNull();

        expect(
          result?.stageName,
          'לימוד — new',
          reason:
              'LWW: older remote must not overwrite a newer local row — '
              'stageName should remain the newer value after the stale merge',
        );
      },
    );

    test('updated_at is persisted after a successful merge', () async {
      final row = StageDefinitionRow(
        curriculumId: _curriculumId,
        trackId: trackId,
        stageOrder: 1,
        stageName: 'לימוד',
        schedule: '{"type":"delay","delay_days":0}',
        isDefault: true,
        updatedAt: _updatedAt,
      );
      await merger.merge(profileId: _profileId, rows: [_codec.encode(row)]);

      final persisted = await store.currentUpdatedAt(
        kind: EntityKind.stageDefinition,
        profileId: _profileId,
        naturalKey: '$_curriculumId|$trackId|1',
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
      'schedule encoded as a JSON String (not a Map) in codec payload',
      () async {
        // Confirm that codec.encode() emits schedule as a String, not a Map.
        // This was the key pre-Phase-B divergence: _stagePushPayload used
        // jsonDecode(s.schedule) which produced a Map, while the codec produces
        // a canonical String. The merger handles both but the canonical writer
        // must be String.
        final row = StageDefinitionRow(
          curriculumId: _curriculumId,
          trackId: trackId,
          stageOrder: 2,
          stageName: "חזרה א'",
          schedule: '{"type":"delay","delay_days":1}',
          isDefault: false,
          updatedAt: _updatedAt,
        );
        final payload = _codec.encode(row);

        expect(
          payload['schedule'],
          isA<String>(),
          reason:
              'Phase B invariant: codec.encode() must emit schedule as a JSON '
              'String — not a Map. A Map payload was the pre-Phase-B form; '
              'the codec is now the single canonical writer.',
        );
        expect(payload['schedule'], '{"type":"delay","delay_days":1}');

        // No legacy quartet in the canonical payload.
        expect(
          payload.containsKey('delay_days'),
          isFalse,
          reason: 'codec must not emit legacy delay_days field',
        );
        expect(
          payload.containsKey('schedule_type'),
          isFalse,
          reason: 'codec must not emit legacy schedule_type field',
        );
        expect(
          payload.containsKey('days_of_week'),
          isFalse,
          reason: 'codec must not emit legacy days_of_week field',
        );
        expect(
          payload.containsKey('rolling_window_size'),
          isFalse,
          reason: 'codec must not emit legacy rolling_window_size field',
        );
      },
    );

    test(
      'back-compat: merger still handles a legacy Map-typed schedule field',
      () async {
        // Verify decode() accepts old Firestore docs that stored schedule as a
        // Map (pre-W3.27 or written by old _stagePushPayload). The merger's
        // _encodeSchedule handles `raw is Map` — confirm it still applies.
        final legacyPayload = <String, dynamic>{
          'curriculum_id': _curriculumId,
          'track_id': trackId,
          'stage_order': 1,
          'stage_name': 'לימוד',
          'schedule': {'type': 'delay', 'delay_days': 0}, // Map, not String
          'is_default': true,
          'updated_at': _updatedAt.toIso8601String(),
        };

        await merger.merge(profileId: _profileId, rows: [legacyPayload]);

        final result =
            await (db.select(db.stageDefinitions)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId) &
                      t.stageOrder.equals(1),
                ))
                .getSingleOrNull();

        expect(
          result,
          isNotNull,
          reason:
              'Back-compat: legacy Map-typed schedule must still be accepted by '
              'the merger and stored as a JSON String in the DB.',
        );
        // DB column always stores as String.
        expect(result!.schedule, contains('"type"'));
      },
    );
  });
}
