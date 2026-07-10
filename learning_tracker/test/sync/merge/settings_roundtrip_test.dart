/// Round-trip test: [SettingsCodec.decode] must produce a shape that
/// [SettingsMerger] accepts and persists.
///
/// AUD-core-sync-16: settings_codec.dart had zero direct test coverage.
/// Every other non-trivial codec in this batch (bookmark, completion_event,
/// goal, learner_profile, learning_ledger, learning_order, profile_program,
/// stage_definition, streak_event, study_day_config, track) has a
/// `test/sync/merge/*_roundtrip_test.dart` sibling — this file closes that
/// gap for settings, adapted to the entity's real shape (see below).
///
/// **Why this test drives from raw payload maps, not `SettingsCodec.encode()`:**
/// unlike every sibling codec, `SettingsCodec.encode()` has zero production
/// call sites — nothing in `lib/` ever builds a settings push payload
/// (`SyncWriteFacade.pushSettings` itself has no live caller; goals and
/// stage definitions were split onto their own dedicated push routes, see
/// `sync_write_facade.dart`'s doc comments). `decode()`, by contrast, is
/// genuinely live: [SettingsMerger] calls it on every pulled `settings` doc.
/// So the accurate "round trip" for this entity is the wire shape a real
/// Firestore document would have → decode() → merger → DB, exactly what
/// [SettingsMerger] exercises in production. (AUD-core-sync-38 tracks
/// `encode()`'s dead-code status separately.)
///
/// Settings documents embed stage definitions under `stages: [...]`
/// (W3.32 note in settings_codec.dart) — [SettingsMerger] materialises them
/// by replacing all stage_definitions rows for the curriculum
/// (`DriftMergeStore._upsertSettings`), so the DB-observable effect of a
/// settings merge is rows landing in `stage_definitions`, not a dedicated
/// `settings` table (none exists).
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/settings_codec.dart';
import 'package:learning_tracker/core/sync/codec/stage_definition_codec.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/settings_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

const _codec = SettingsCodec();
const _stageCodec = StageDefinitionCodec();

const _profileId = 1;
const _curriculumId = 'bavli';

final _updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _olderUpdatedAt = DateTime.utc(2026, 6, 18, 9, 0, 0);

/// Build a raw wire-shaped settings payload the way a real Firestore
/// `settings/{curriculumId}` document looks — this is what [SettingsMerger]
/// actually receives on every pull, never a [SettingsCodec.encode] output.
Map<String, dynamic> _rawPayload({
  required int trackId,
  required DateTime updatedAt,
  required String stageName,
}) => {
  'curriculum_id': _curriculumId,
  'track_id': trackId,
  'updated_at': updatedAt.toIso8601String(),
  'stages': [
    _stageCodec.encode(
      StageDefinitionRow(
        curriculumId: _curriculumId,
        trackId: trackId,
        stageOrder: 1,
        stageName: stageName,
        schedule: '{"type":"delay","delay_days":0}',
        isDefault: true,
      ),
    ),
  ],
};

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

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
              curriculumId: _curriculumId,
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
        final payload = _rawPayload(
          trackId: trackId,
          updatedAt: _updatedAt,
          stageName: 'לימוד',
        );

        // Confirm decode() parses the payload correctly first.
        final decoded = _codec.decode(payload);
        expect(decoded, isNotNull);
        expect(decoded!.curriculumId, _curriculumId);
        expect(decoded.stages, hasLength(1));

        // The merger must accept the same payload and write it to Drift.
        await merger.merge(profileId: _profileId, rows: [payload]);

        final stages =
            await (db.select(db.stageDefinitions)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId) &
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
            _rawPayload(
              trackId: trackId,
              updatedAt: _updatedAt,
              stageName: 'לימוד — new',
            ),
          ],
        );

        await merger.merge(
          profileId: _profileId,
          rows: [
            _rawPayload(
              trackId: trackId,
              updatedAt: _olderUpdatedAt,
              stageName: 'לימוד — old',
            ),
          ],
        );

        final stages =
            await (db.select(db.stageDefinitions)..where(
                  (t) =>
                      t.profileId.equals(_profileId) &
                      t.curriculumId.equals(_curriculumId),
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
      final payload = _rawPayload(
        trackId: trackId,
        updatedAt: _updatedAt,
        stageName: "חזרה א'",
      );
      final decoded = _codec.decode(payload);

      expect(decoded, isNotNull);
      expect(decoded!.curriculumId, _curriculumId);
      expect(decoded.trackId, trackId);
      expect(decoded.updatedAt?.toUtc(), _updatedAt);
      expect(decoded.stages, hasLength(1));
      expect(decoded.stages.single.stageName, "חזרה א'");
      expect(decoded.stages.single.stageOrder, 1);
      expect(decoded.stages.single.isDefault, isTrue);
    });

    test('null-guard: missing curriculum_id causes decode to return null', () {
      final payload = _rawPayload(
        trackId: trackId,
        updatedAt: _updatedAt,
        stageName: 'לימוד',
      );
      final broken = Map<String, dynamic>.from(payload)
        ..remove('curriculum_id');

      expect(_codec.decode(broken), isNull);
    });
  });
}
