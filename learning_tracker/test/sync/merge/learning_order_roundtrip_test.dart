/// Round-trip test: the canonical write serializer (LearningOrderCodec.encode)
/// must produce a payload that LearningOrderMerger accepts and persists.
///
/// This test guards the Phase B invariant: if the codec's encode() ever drifts
/// from the key names the merger reads, learning-order rows will be silently
/// skipped on pull and cross-device sync breaks without any error. The test
/// MUST fail before the fix when there is a real mismatch, and pass after.
///
/// For learning_order the shapes were already consistent before Phase B, so
/// this test is simultaneously the regression gate and the proof of consistency.
@Tags(['unit', 'sync'])
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

import '../../helpers/test_database.dart';

const _codec = LearningOrderCodec();

const _profileId = 1;
const _curriculumId = 'bavli';

final _updatedAt = DateTime.utc(2026, 6, 18, 10, 0, 0);
final _olderUpdatedAt = DateTime.utc(2026, 6, 18, 9, 0, 0);
final _syncedAt = DateTime.utc(2026, 6, 18, 10, 0, 1);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

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
          curriculumId: _curriculumId,
          sefariaRef: 'Berakhot',
          userSortOrder: 0,
          updatedAt: _updatedAt,
          syncedAt: _syncedAt,
        );
        final payload = _codec.encode(row);

        // The merger must accept the payload and write it to Drift.
        await merger.merge(profileId: _profileId, rows: [payload]);

        // Assert: the row materialised in the DB — not skipped.
        final results = await db.learningOrderDao.getLearningOrderByCurriculum(
          _curriculumId,
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
          _updatedAt,
          reason:
              'updated_at must round-trip through the codec and be stored correctly',
        );
      },
    );

    test('currentUpdatedAt is persisted after a successful merge', () async {
      final row = LearningOrderRow(
        curriculumId: _curriculumId,
        sefariaRef: 'Berakhot',
        userSortOrder: 1,
        updatedAt: _updatedAt,
        syncedAt: _syncedAt,
      );
      await merger.merge(profileId: _profileId, rows: [_codec.encode(row)]);

      final persisted = await store.currentUpdatedAt(
        kind: EntityKind.learningOrder,
        profileId: _profileId,
        naturalKey: '$_curriculumId|Berakhot',
      );
      expect(
        persisted,
        _updatedAt,
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
          return _codec.encode(
            LearningOrderRow(
              curriculumId: _curriculumId,
              sefariaRef: e.value,
              userSortOrder: e.key,
              updatedAt: _updatedAt,
            ),
          );
        }).toList();

        await merger.merge(profileId: _profileId, rows: payloads);

        final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
          _curriculumId,
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
          curriculumId: _curriculumId,
          sefariaRef: 'Berakhot',
          userSortOrder: 0,
          updatedAt: _updatedAt,
        );
        await merger.merge(profileId: _profileId, rows: [_codec.encode(newer)]);

        // Then: try to merge an older row with a different sort order.
        final older = LearningOrderRow(
          curriculumId: _curriculumId,
          sefariaRef: 'Berakhot',
          userSortOrder: 99,
          updatedAt: _olderUpdatedAt,
        );
        await merger.merge(profileId: _profileId, rows: [_codec.encode(older)]);

        final rows = await db.learningOrderDao.getLearningOrderByCurriculum(
          _curriculumId,
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
