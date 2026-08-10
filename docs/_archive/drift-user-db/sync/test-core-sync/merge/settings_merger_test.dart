/// Unit tests for [SettingsMerger]: fake-store LWW unit tests plus Phase-3
/// LWW symmetry + persistUpdatedAt against a real [DriftMergeStore], and the
/// full wire-shaped decode() → merger → DB round-trip (including nested
/// stage_definitions materialisation).
///
/// AG-5 (AUD-app-05): consolidates test/core/sync/merge/mergers_test.dart's
/// SettingsMerger group, test/sync/merge/lww_symmetric_test.dart's
/// SettingsMerger group, test/sync/merge/persist_updated_at_test.dart's
/// SettingsMerger case, and test/sync/merge/settings_roundtrip_test.dart into
/// the single file mirroring lib/core/sync/merge/settings_merger.dart.
///
/// **Why the round-trip group below drives from raw payload maps, not
/// `SettingsCodec.encode()`:** unlike every sibling codec,
/// `SettingsCodec.encode()` has zero production call sites — nothing in
/// `lib/` ever builds a settings push payload (`SyncWriteFacade.pushSettings`
/// itself has no live caller; goals and stage definitions were split onto
/// their own dedicated push routes, see `sync_write_facade.dart`'s doc
/// comments). `decode()`, by contrast, is genuinely live: [SettingsMerger]
/// calls it on every pulled `settings` doc. So the accurate "round trip" for
/// this entity is the wire shape a real Firestore document would have →
/// decode() → merger → DB, exactly what [SettingsMerger] exercises in
/// production. (AUD-core-sync-38 tracks `encode()`'s dead-code status
/// separately.)
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/settings_codec.dart';
import 'package:learning_tracker/core/sync/codec/stage_definition_codec.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/settings_merger.dart';
import 'package:learning_tracker/data/firestore/conflict.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_database.dart';

const _roundtripCodec = SettingsCodec();
const _roundtripStageCodec = StageDefinitionCodec();
const _roundtripCurriculumId = 'bavli';
final _roundtripUpdatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _roundtripOlderUpdatedAt = DateTime.utc(2026, 6, 18, 9, 0, 0);

/// Build a raw wire-shaped settings payload the way a real Firestore
/// `settings/{curriculumId}` document looks — this is what [SettingsMerger]
/// actually receives on every pull, never a [SettingsCodec.encode] output.
Map<String, dynamic> _roundtripRawPayload({
  required int trackId,
  required DateTime updatedAt,
  required String stageName,
}) => {
  'curriculum_id': _roundtripCurriculumId,
  'track_id': trackId,
  'updated_at': updatedAt.toIso8601String(),
  'stages': [
    _roundtripStageCodec.encode(
      StageDefinitionRow(
        curriculumId: _roundtripCurriculumId,
        trackId: trackId,
        stageOrder: 1,
        stageName: stageName,
        schedule: '{"type":"delay","delay_days":0}',
        isDefault: true,
      ),
    ),
  ],
};

class _FakeMergeStore implements MergeStore {
  final _timestamps = <String, Map<int, Map<String, DateTime?>>>{};
  final _syncedAt = <String, Map<int, Map<String, DateTime?>>>{};
  final List<Map<String, dynamic>> upserted = [];

  void seedTimestamp({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime? at,
  }) {
    _timestamps
            .putIfAbsent(kind, () => {})
            .putIfAbsent(profileId, () => {})[naturalKey] =
        at;
  }

  @override
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async => _timestamps[kind]?[profileId]?[naturalKey];

  @override
  Future<DateTime?> currentSyncedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async => _syncedAt[kind]?[profileId]?[naturalKey];

  @override
  Future<void> persistUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime updatedAt,
    DateTime? syncedAt,
  }) async {
    _timestamps
            .putIfAbsent(kind, () => {})
            .putIfAbsent(profileId, () => {})[naturalKey] =
        updatedAt;
    _syncedAt
            .putIfAbsent(kind, () => {})
            .putIfAbsent(profileId, () => {})[naturalKey] =
        syncedAt;
  }

  // AUD-t-cross-68 / AD-7: delegates to the single canonical predicate
  // instead of re-deriving it by hand, so this fake cannot drift from D15
  // semantics.
  @override
  bool remoteIsNewer({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    DateTime? localSyncedAt,
    DateTime? remoteSyncedAt,
  }) => canonicalRemoteIsNewer(
    localUpdatedAt: localUpdatedAt,
    remoteUpdatedAt: remoteUpdatedAt,
    localSyncedAt: localSyncedAt,
    remoteSyncedAt: remoteSyncedAt,
  );

  @override
  Future<void> upsert({
    required String kind,
    required int profileId,
    required Map<String, dynamic> fields,
  }) async {
    upserted.add({...fields, '__kind': kind, '__profileId': profileId});
  }

  @override
  Future<void> insertIfAbsent({
    required String kind,
    required int profileId,
    required String naturalKey,
    required Map<String, dynamic> fields,
  }) async {}

  @override
  Future<T> runInTransaction<T>(Future<T> Function() body) => body();
}

DateTime _dt(int year, [int month = 1, int day = 1]) =>
    DateTime.utc(year, month, day);

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

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // ── SettingsMerger — fake-store unit tests ───────────────────────────────
  group('SettingsMerger', () {
    late _FakeMergeStore store;
    late SettingsMerger merger;

    setUp(() {
      store = _FakeMergeStore();
      merger = SettingsMerger(store: store);
    });

    test('kind is "settings"', () {
      expect(merger.kind, EntityKind.settings);
    });

    test('upserts when remote is newer', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'mishnayos',
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
      );

      expect(store.upserted, hasLength(1));
    });

    test('skips when remote is older than local', () async {
      store.seedTimestamp(
        kind: EntityKind.settings,
        profileId: 1,
        naturalKey: 'mishnayos',
        at: _dt(2027),
      );

      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'mishnayos',
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
      );

      expect(store.upserted, isEmpty);
    });

    test('skips row when curriculum_id is missing', () async {
      // SettingsCodec.decode returns null when curriculum_id is absent.
      // The merger skips null-decode rows; no upsert occurs.
      await merger.merge(
        profileId: 1,
        rows: [
          {
            // No curriculum_id — codec returns null → skip
            'updated_at': _dt(2026).toIso8601String(),
          },
        ],
      );
      expect(store.upserted, isEmpty);
    });

    test('accepts DateTime object as updated_at', () async {
      await merger.merge(
        profileId: 1,
        rows: [
          {
            'curriculum_id': 'bavli',
            'updated_at': _dt(2026), // DateTime
          },
        ],
      );
      expect(store.upserted, hasLength(1));
    });
  });

  group(
    'SettingsMerger — LWW symmetry + persistence (real DriftMergeStore)',
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

      group('SettingsMerger', () {
        late SettingsMerger merger;
        late int settingsTrackId;

        setUp(() async {
          merger = SettingsMerger(store: store);
          // SettingsMerger materialises nested stage_definitions which FK
          // curriculum_tracks(id) — seed a track first.
          settingsTrackId = await db
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
          'track_id': settingsTrackId,
          'updated_at': updatedAt.toIso8601String(),
          if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
          'stages': [
            {
              'track_id': settingsTrackId,
              'stage_order': 0,
              'stage_name': 'learning',
              'is_default': true,
            },
          ],
        };

        test('remote newer than local → applies', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.settings,
            profileId: profileId,
            naturalKey: 'bavli',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteNewer)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.settings,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(after, _remoteNewer);
        });

        test('local newer than remote → does NOT apply', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.settings,
            profileId: profileId,
            naturalKey: 'bavli',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteOlder)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.settings,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(after, _local);
        });

        test('within ±5 s — remote synced_at newer → applies', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.settings,
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
            kind: EntityKind.settings,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(after, _remoteSkew);
        });

        test('same synced_at — remote wins', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.settings,
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
            kind: EntityKind.settings,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(after, _remoteSkew);
        });
      });

      test('SettingsMerger', () async {
        // SettingsMerger materialises nested stage_definitions which FK
        // curriculum_tracks(id) — seed a track first.
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

        await SettingsMerger(store: store).merge(
          profileId: _profileId,
          rows: [
            {
              'curriculum_id': 'bavli',
              'track_id': trackId,
              'updated_at': _ts.toIso8601String(),
              'synced_at': _syncedAt.toIso8601String(),
              'stages': [
                {
                  'track_id': trackId,
                  'stage_order': 0,
                  'stage_name': 'learning',
                  'is_default': true,
                },
              ],
            },
          ],
        );

        final updatedAt = await store.currentUpdatedAt(
          kind: EntityKind.settings,
          profileId: _profileId,
          naturalKey: 'bavli',
        );
        expect(updatedAt, _ts);
      });
    },
  );

  group('settings — decode() → merger → DB round-trip', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late SettingsMerger merger;
    late int trackId;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      merger = SettingsMerger(store: store);

      // Seed account + profile so FK constraints hold.
      await seedProfile(db);

      // Seed a curriculum_tracks row — _upsertSettings resolves the LOCAL
      // track id from (profile, curriculumId) before materialising stages.
      trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: _profileId,
              curriculumId: _roundtripCurriculumId,
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'a wire-shaped settings payload is accepted by the merger and stage rows land in DB',
      () async {
        final payload = _roundtripRawPayload(
          trackId: trackId,
          updatedAt: _roundtripUpdatedAt,
          stageName: 'לימוד',
        );

        // Confirm decode() parses the payload correctly first.
        final decoded = _roundtripCodec.decode(payload);
        expect(decoded, isNotNull);
        expect(decoded!.curriculumId, _roundtripCurriculumId);
        expect(decoded.stages, hasLength(1));

        // The merger must accept the same payload and write it to Drift.
        await merger.merge(profileId: _profileId, rows: [payload]);

        final stages =
            await (db.select(db.stageDefinitions)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_roundtripCurriculumId) &
                      t.trackId.equals(trackId),
                ))
                .get();

        expect(
          stages,
          hasLength(1),
          reason:
              'SettingsMerger must materialise the embedded stages when a '
              'wire-shaped payload is fed in — if empty, the merger\'s read '
              'keys diverge from what decode() actually parses.',
        );
        expect(stages.single.stageName, 'לימוד');
        expect(stages.single.isDefault, isTrue);
        expect(stages.single.schedule, '{"type":"delay","delay_days":0}');
      },
    );

    test(
      'a second merge with an older updated_at is skipped (LWW wins local)',
      () async {
        await merger.merge(
          profileId: _profileId,
          rows: [
            _roundtripRawPayload(
              trackId: trackId,
              updatedAt: _roundtripUpdatedAt,
              stageName: 'לימוד — new',
            ),
          ],
        );

        await merger.merge(
          profileId: _profileId,
          rows: [
            _roundtripRawPayload(
              trackId: trackId,
              updatedAt: _roundtripOlderUpdatedAt,
              stageName: 'לימוד — old',
            ),
          ],
        );

        final stages =
            await (db.select(db.stageDefinitions)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_roundtripCurriculumId),
                ))
                .get();

        expect(
          stages.single.stageName,
          'לימוד — new',
          reason:
              'LWW: older remote must not overwrite a newer local row — '
              'stageName should remain the newer value after the stale merge',
        );
      },
    );

    test('decode() parses nested stage definitions correctly', () {
      final payload = _roundtripRawPayload(
        trackId: trackId,
        updatedAt: _roundtripUpdatedAt,
        stageName: "חזרה א'",
      );
      final decoded = _roundtripCodec.decode(payload);

      expect(decoded, isNotNull);
      expect(decoded!.curriculumId, _roundtripCurriculumId);
      expect(decoded.trackId, trackId);
      expect(decoded.updatedAt?.toUtc(), _roundtripUpdatedAt);
      expect(decoded.stages, hasLength(1));
      expect(decoded.stages.single.stageName, "חזרה א'");
      expect(decoded.stages.single.stageOrder, 1);
      expect(decoded.stages.single.isDefault, isTrue);
    });

    test('null-guard: missing curriculum_id causes decode to return null', () {
      final payload = _roundtripRawPayload(
        trackId: trackId,
        updatedAt: _roundtripUpdatedAt,
        stageName: 'לימוד',
      );
      final broken = Map<String, dynamic>.from(payload)
        ..remove('curriculum_id');

      expect(_roundtripCodec.decode(broken), isNull);
    });
  });
}
