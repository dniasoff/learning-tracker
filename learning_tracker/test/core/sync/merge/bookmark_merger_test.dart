/// Unit tests for [BookmarkMerger]: Phase-3 LWW symmetry + persistUpdatedAt
/// against a real [DriftMergeStore], the legacy content_item_id vs.
/// canonical sefaria_ref key regression, and the codec.encode() -> merger
/// -> DB round-trip (Phase B invariant).
///
/// AG-5 (AUD-app-05): consolidates test/sync/merge/lww_symmetric_test.dart's
/// BookmarkMerger group, test/sync/merge/persist_updated_at_test.dart's
/// BookmarkMerger case, test/sync/merge/bookmark_content_item_id_test.dart,
/// and test/sync/merge/bookmarks_roundtrip_test.dart into the single file
/// mirroring lib/core/sync/merge/bookmark_merger.dart.
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

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group(
    'BookmarkMerger — LWW symmetry + persistence (real DriftMergeStore)',
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

      group('BookmarkMerger', () {
        late BookmarkMerger merger;

        setUp(() {
          merger = BookmarkMerger(store: store);
        });

        Map<String, dynamic> row({
          required DateTime updatedAt,
          DateTime? syncedAt,
        }) => {
          'curriculum_id': 'bavli',
          'sefaria_ref': 'Berakhot 1',
          'updated_at': updatedAt.toIso8601String(),
          if (syncedAt != null) 'synced_at': syncedAt.toIso8601String(),
        };

        Future<void> seedTrack() async {
          await db
              .into(db.curriculumTracks)
              .insert(
                CurriculumTracksCompanion.insert(
                  profileId: profileId,
                  curriculumId: 'bavli',
                  stateChangedAt: _local,
                  activatedAt: _local,
                ),
              );
        }

        test('remote newer than local → applies', () async {
          await seedTrack();
          await store.persistUpdatedAt(
            kind: EntityKind.bookmark,
            profileId: profileId,
            naturalKey: 'bavli',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteNewer)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.bookmark,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(after, _remoteNewer);
        });

        test('local newer than remote → does NOT apply', () async {
          await seedTrack();
          await store.persistUpdatedAt(
            kind: EntityKind.bookmark,
            profileId: profileId,
            naturalKey: 'bavli',
            updatedAt: _local,
          );

          await merger.merge(
            profileId: profileId,
            rows: [row(updatedAt: _remoteOlder)],
          );

          final after = await store.currentUpdatedAt(
            kind: EntityKind.bookmark,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(after, _local);
        });

        test('within ±5 s — remote synced_at newer → applies', () async {
          await seedTrack();
          await store.persistUpdatedAt(
            kind: EntityKind.bookmark,
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
            kind: EntityKind.bookmark,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(after, _remoteSkew);
        });

        test('same synced_at — remote wins (convergence)', () async {
          await seedTrack();
          await store.persistUpdatedAt(
            kind: EntityKind.bookmark,
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
            kind: EntityKind.bookmark,
            profileId: profileId,
            naturalKey: 'bavli',
          );
          expect(after, _remoteSkew);
        });
      });

      Future<void> seedTrack() async {
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
      }

      test('BookmarkMerger', () async {
        await seedTrack();
        await BookmarkMerger(store: store).merge(
          profileId: _profileId,
          rows: [
            {
              'curriculum_id': 'bavli',
              'sefaria_ref': 'Berakhot 1',
              'updated_at': _ts.toIso8601String(),
              'synced_at': _syncedAt.toIso8601String(),
            },
          ],
        );

        final updatedAt = await store.currentUpdatedAt(
          kind: EntityKind.bookmark,
          profileId: _profileId,
          naturalKey: 'bavli',
        );
        final syncedAt = await store.currentSyncedAt(
          kind: EntityKind.bookmark,
          profileId: _profileId,
          naturalKey: 'bavli',
        );
        expect(updatedAt, _ts);
        expect(syncedAt, _syncedAt);
      });
    },
  );

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
