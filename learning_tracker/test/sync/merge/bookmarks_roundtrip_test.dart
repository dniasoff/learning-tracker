/// Phase B — write→merge round-trip for the `bookmarks` entity.
///
/// Verifies that the NEW canonical write serializer (BookmarkCodec.encode)
/// produces a payload that the BookmarkMerger (and DriftMergeStore._upsertBookmark)
/// can round-trip: after calling codec.encode() and feeding the result through
/// the merger, the bookmark row is present in the DB (NOT skipped).
///
/// This test would FAIL before the Phase B fix because BookmarkEntity.toFirestore()
/// wrote `content_item_id` while the codec decode() expected `sefaria_ref` as
/// the primary key — causing every live-written bookmark to be treated as
/// 'malformed_fields' on pull and dropped.
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/bookmark_codec.dart';
import 'package:learning_tracker/core/sync/merge/bookmark_merger.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

const _profileId = 1;
final _ts = DateTime.utc(2026, 6, 18, 14, 0, 0);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('bookmarks — write→merge round-trip (Phase B)', () {
    late UserDatabase db;
    late DriftMergeStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      await seedProfile(db);
      store = DriftMergeStore(db);
      // Seed a curriculum_tracks row so the bookmark FK resolves.
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: _profileId,
              curriculumId: 'bavli',
              stateChangedAt: _ts.subtract(const Duration(days: 1)),
              activatedAt: _ts.subtract(const Duration(days: 1)),
            ),
          );
    });

    tearDown(() async => db.close());

    test('codec.encode() payload merges and lands in DB (not skipped)', () async {
      // Build the payload using the CANONICAL write serializer — the same
      // path BookmarkEntity.toFirestore() and LocalDataUploadService now use.
      const codec = BookmarkCodec();
      final payload = codec.encode(
        BookmarkRow(
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot 2a',
          updatedAt: _ts,
        ),
      );

      // Sanity: codec must emit sefaria_ref (not content_item_id).
      expect(
        payload['sefaria_ref'],
        'Berakhot 2a',
        reason:
            'Phase B canonical key is sefaria_ref; content_item_id must not '
            'appear in fresh writes.',
      );
      expect(
        payload.containsKey('content_item_id'),
        isFalse,
        reason: 'content_item_id is the legacy key; codec must not emit it.',
      );

      // Feed the codec-encoded payload through the merger.
      await BookmarkMerger(
        store: store,
      ).merge(profileId: _profileId, rows: [payload]);

      // If merge skipped the row (push↔merge key mismatch), currentUpdatedAt
      // is null.  It must equal _ts after a successful apply.
      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.bookmark,
        profileId: _profileId,
        naturalKey: 'bavli',
      );
      expect(
        updatedAt,
        _ts,
        reason:
            'codec-encoded bookmark must materialise in DB after merge; '
            'null means it was dropped as malformed (push↔merge key mismatch).',
      );
    });

    test('codec.decode() round-trips through codec.encode()', () async {
      const codec = BookmarkCodec();
      final row = BookmarkRow(
        curriculumId: 'bavli',
        sefariaRef: 'Berakhot 2a',
        updatedAt: _ts,
      );
      final encoded = codec.encode(row);
      final decoded = codec.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.curriculumId, row.curriculumId);
      expect(decoded.sefariaRef, row.sefariaRef);
      expect(decoded.updatedAt, row.updatedAt);
    });

    test(
      'legacy content_item_id key still accepted on pull (backward compat)',
      () async {
        // Old Firestore documents written before Phase B still use content_item_id.
        // The pull-side dual-key fallback must continue to accept them.
        await BookmarkMerger(store: store).merge(
          profileId: _profileId,
          rows: [
            {
              'curriculum_id': 'bavli',
              'content_item_id': 'Berakhot 3a',
              'updated_at': _ts.add(const Duration(hours: 1)).toIso8601String(),
            },
          ],
        );

        final updatedAt = await store.currentUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: _profileId,
          naturalKey: 'bavli',
        );
        expect(
          updatedAt,
          _ts.add(const Duration(hours: 1)),
          reason:
              'Legacy content_item_id docs must still replicate on pull '
              '(backward-compat dual-key fallback).',
        );
      },
    );
  });
}
