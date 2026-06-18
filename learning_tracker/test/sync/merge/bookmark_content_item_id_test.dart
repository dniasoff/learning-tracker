/// Regression: cross-device bookmark sync must accept the LIVE write shape.
///
/// The live writers (BookmarkEntity.toFirestore, LocalDataUploadService,
/// TrackCreationService) persist the bookmark ref under `content_item_id`, but
/// the pull-side merge (`DriftMergeStore._upsertBookmark`) historically read
/// only `sefaria_ref` — so every live-written bookmark was dropped on pull as
/// 'malformed_fields' and never replicated to other devices. Both keys are in
/// the bookmarks hasOnly() allowlist, so the rules tests + Oracle #1 (push⊆rules)
/// could not catch it: it is a push↔merge key-contract bug, not a rules bug.
///
/// This test feeds the EXACT live shape (content_item_id, no sefaria_ref) through
/// the merge and asserts the bookmark lands.
@Tags(['unit', 'sync'])
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/merge/bookmark_merger.dart';
import 'package:learning_tracker/core/sync/merge/drift_merge_store.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

const _profileId = 1;
final _ts = DateTime.utc(2026, 6, 18, 12, 0, 0);

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('bookmark merge — live content_item_id shape', () {
    late UserDatabase db;
    late DriftMergeStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = UserDatabase(NativeDatabase.memory());
      await seedProfile(db);
      store = DriftMergeStore(db);
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

    tearDown(() async {
      await db.close();
    });

    test('a bookmark written under content_item_id (live shape) replicates, '
        'not dropped as malformed', () async {
      await BookmarkMerger(store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'curriculum_id': 'bavli',
            // LIVE shape — BookmarkEntity.toFirestore() writes the ref here, not
            // under `sefaria_ref`.
            'content_item_id': 'Berakhot 2a',
            'updated_at': _ts.toIso8601String(),
          },
        ],
      );

      // If the merge dropped it (the bug), currentUpdatedAt is null.
      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.bookmark,
        profileId: _profileId,
        naturalKey: 'bavli',
      );
      expect(
        updatedAt,
        _ts,
        reason:
            'bookmark written under content_item_id must be persisted on '
            'pull (cross-device replication), not skipped as malformed',
      );
    });

    test('the canonical sefaria_ref shape still works', () async {
      await BookmarkMerger(store: store).merge(
        profileId: _profileId,
        rows: [
          {
            'curriculum_id': 'bavli',
            'sefaria_ref': 'Berakhot 2a',
            'updated_at': _ts.toIso8601String(),
          },
        ],
      );
      final updatedAt = await store.currentUpdatedAt(
        kind: EntityKind.bookmark,
        profileId: _profileId,
        naturalKey: 'bavli',
      );
      expect(updatedAt, _ts);
    });
  });
}
