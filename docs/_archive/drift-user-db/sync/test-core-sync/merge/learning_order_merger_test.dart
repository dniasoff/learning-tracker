/// Unit tests for [LearningOrderMerger]: Phase-3 LWW symmetry +
/// persistUpdatedAt against a real [DriftMergeStore], and the
/// codec.encode() -> merger -> DB round-trip (Phase B invariant).
///
/// AG-5 (AUD-app-05): consolidates test/sync/merge/lww_symmetric_test.dart's
/// LearningOrderMerger group, test/sync/merge/persist_updated_at_test.dart's
/// LearningOrderMerger case, and
/// test/sync/merge/learning_order_roundtrip_test.dart into the single file
/// mirroring lib/core/sync/merge/learning_order_merger.dart.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/learning_order_codec.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/learning_order_merger.dart';
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
const _rtCodec = LearningOrderCodec();
const _rtProfileId = 1;
const _rtCurriculumId = 'bavli';
final _rtUpdatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _rtOlderUpdatedAt = DateTime.utc(2026, 6, 18, 9, 0, 0);
final _rtSyncedAt = DateTime.utc(2026, 6, 18, 10, 0, 1);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group(
    'LearningOrderMerger — LWW symmetry + persistence (real DriftMergeStore)',
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

      group('LearningOrderMerger', () {
        late LearningOrderMerger merger;

        setUp(() {
          merger = LearningOrderMerger(store: store);
        });

        Map<String, dynamic> row({
          required DateTime updatedAt,
          DateTime? syncedAt,
        }) => {
          'curriculum_id': 'bavli',
          'sefaria_ref': 'Berakhot',
          'user_sort_order': 1,
          'updated_at': updatedAt.toIso8601String(),
          if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
        };

        test('remote newer than local → applies', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.learningOrder,
            profileId: profileId,
            naturalKey: 'bavli|Berakhot',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteNewer)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.learningOrder,
            profileId: profileId,
            naturalKey: 'bavli|Berakhot',
          );
          expect(after, _remoteNewer);
        });

        test('local newer than remote → does NOT apply', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.learningOrder,
            profileId: profileId,
            naturalKey: 'bavli|Berakhot',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteOlder)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.learningOrder,
            profileId: profileId,
            naturalKey: 'bavli|Berakhot',
          );
          expect(after, _local);
        });

        test('within ±5 s — remote synced_at newer → applies', () async {
          await store.persistUpdatedAt(
            kind: EntityKind.learningOrder,
            profileId: profileId,
            naturalKey: 'bavli|Berakhot',
            updatedAt: _localSkew,
            syncedAt: _localSynced,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteSkew, syncedAt: _remoteSyncedNewer)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.learningOrder,
            profileId: profileId,
            naturalKey: 'bavli|Berakhot',
          );
          expect(after, _remoteSkew);
        });
      });

      test('LearningOrderMerger', () async {
        await LearningOrderMerger(store: store).merge(
          profileId: _profileId,
          rows: [
            {
              'curriculum_id': 'bavli',
              'sefaria_ref': 'Berakhot',
              'user_sort_order': 1,
              'updated_at': _ts.toIso8601String(),
              'synced_at': _syncedAt.toIso8601String(),
            },
          ],
        );

        final updatedAt = await store.currentUpdatedAt(
          kind: EntityKind.learningOrder,
          profileId: _profileId,
          naturalKey: 'bavli|Berakhot',
        );
        expect(updatedAt, _ts);
      });
    },
  );

  group('learning_order — codec.encode() → merger → DB round-trip', () {
    late UserDatabase db;
    late DriftMergeStore store;
    late LearningOrderMerger merger;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      store = DriftMergeStore(db);
      merger = LearningOrderMerger(store: store);

      // Seed an account + profile so FK constraints on learner_profiles are met.
      await seedProfile(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'codec.encode() payload is accepted by the merger and the row lands in DB',
      () async {
        // Build the canonical write payload via the codec — exactly as the
        // Phase B unification routes through after consistency verification.
        final row = LearningOrderRow(
          curriculumId: _rtCurriculumId,
          sefariaRef: 'Berakhot',
          userSortOrder: 0,
          updatedAt: _rtUpdatedAt,
          syncedAt: _rtSyncedAt,
        );
        final payload = _rtCodec.encode(row);

        // The merger must accept the payload and write it to Drift.
        await merger.merge(profileId: _rtProfileId, rows: [payload]);

        // Assert: the row materialised in the DB — not skipped.
        final results = await db.learningOrderDao.getLearningOrderByCurriculum(
          _rtCurriculumId,
          profileId: _rtProfileId,
        );
        final result = results
            .where((r) => r.sefariaRef == 'Berakhot')
            .firstOrNull;

        expect(
          result,
          isNotNull,
          reason:
              'LearningOrderMerger must INSERT the row when codec.encode() '
              'payload is fed in — if null, the merge read-keys diverge from '
              'the codec write-keys (the push↔merge key-contract bug).',
        );
        expect(result!.userSortOrder, 0);
        expect(
          result.updatedAt.toUtc(),
          _rtUpdatedAt,
          reason:
              'updated_at must round-trip through the codec and be stored correctly',
        );
      },
    );

    test('currentUpdatedAt is persisted after a successful merge', () async {
      final row = LearningOrderRow(
        curriculumId: _rtCurriculumId,
        sefariaRef: 'Berakhot',
        userSortOrder: 1,
        updatedAt: _rtUpdatedAt,
        syncedAt: _rtSyncedAt,
      );
      await merger.merge(profileId: _rtProfileId, rows: [_rtCodec.encode(row)]);

      final persisted = await store.currentUpdatedAt(
        kind: EntityKind.learningOrder,
        profileId: _rtProfileId,
        naturalKey: '$_rtCurriculumId|Berakhot',
      );
      expect(
        persisted,
        _rtUpdatedAt,
        reason:
            'persistUpdatedAt must record the remote updated_at so subsequent '
            'pulls use LWW symmetrically',
      );
    });

    test(
      'multiple items round-trip when codec.encode() payloads are merged in bulk',
      () async {
        final refs = ['Berakhot', 'Shabbat', 'Eruvin'];
        final payloads = refs.asMap().entries.map((e) {
          return _rtCodec.encode(
            LearningOrderRow(
              curriculumId: _rtCurriculumId,
              sefariaRef: e.value,
              userSortOrder: e.key,
              updatedAt: _rtUpdatedAt,
            ),
          );
        }).toList();

        await merger.merge(profileId: _rtProfileId, rows: payloads);

        final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
          _rtCurriculumId,
          profileId: _rtProfileId,
        );
        expect(
          rows.length,
          3,
          reason:
              'All 3 learning-order rows must materialise from codec payloads',
        );
        expect(rows.map((r) => r.sefariaRef).toList(), containsAll(refs));
      },
    );

    test(
      'a second merge with an older updated_at is skipped (LWW wins local)',
      () async {
        // First: merge a newer row.
        final newer = LearningOrderRow(
          curriculumId: _rtCurriculumId,
          sefariaRef: 'Berakhot',
          userSortOrder: 0,
          updatedAt: _rtUpdatedAt,
        );
        await merger.merge(
          profileId: _rtProfileId,
          rows: [_rtCodec.encode(newer)],
        );

        // Then: try to merge an older row with a different sort order.
        final older = LearningOrderRow(
          curriculumId: _rtCurriculumId,
          sefariaRef: 'Berakhot',
          userSortOrder: 99,
          updatedAt: _rtOlderUpdatedAt,
        );
        await merger.merge(
          profileId: _rtProfileId,
          rows: [_rtCodec.encode(older)],
        );

        final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
          _rtCurriculumId,
          profileId: _rtProfileId,
        );
        final result = rows
            .where((r) => r.sefariaRef == 'Berakhot')
            .firstOrNull;

        expect(
          result?.userSortOrder,
          0,
          reason:
              'LWW: older remote must not overwrite a newer local row — '
              'userSortOrder should remain 0 after the stale "99" merge',
        );
      },
    );
  });
}
