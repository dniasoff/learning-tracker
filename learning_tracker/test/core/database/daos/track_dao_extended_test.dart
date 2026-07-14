/// Extended [TrackDao] tests covering paths not hit by track_dao_test.dart.
///
/// Covers:
///  - deactivateTrack for an existing active track
///  - deactivateTrack is a no-op for non-existent track
///  - upsertFromSync (insert + update paths)
///  - resetPace
///  - getAllForProfile
///  - countActiveTracksForProfile
///  - getActiveTracksForProfile ordering
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart'
    show TrackState;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ─── Helper ───────────────────────────────────────────────────────────────

  Future<int> insertTrack({
    CurriculumId curriculum = CurriculumId.bavli,
    int profileId = 0,
  }) async {
    final row = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculum.storageKey,
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    return row.id;
  }

  Future<int> insertRawTrack({
    String curriculumId = 'bavli',
    String trackType = 'personal',
    int profileId = 0,
    bool isActive = true,
    DateTime? activatedAt,
  }) {
    // W3.28: isActive maps to state='active'; false maps to state='retired'.
    return db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion(
            profileId: Value(profileId),
            curriculumId: Value(curriculumId),
            state: Value(
              isActive
                  ? TrackState.active.storageKey
                  : TrackState.retired.storageKey,
            ),
            stateChangedAt: Value(activatedAt ?? DateTime.utc(2026, 1, 1)),
            activatedAt: Value(activatedAt ?? DateTime.utc(2026, 1, 1)),
          ),
        );
  }

  // ─── deactivateTrack ──────────────────────────────────────────────────────

  group('deactivateTrack', () {
    test('deactivates an existing active non-personal track', () async {
      // Insert an active track for profileId 0 (deactivateTrack's default).
      await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 0,
              curriculumId: CurriculumId.bavli.storageKey,
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      expect(await db.trackDao.getActiveTracks(CurriculumId.bavli), isNotEmpty);

      await db.trackDao.deactivateTrack(CurriculumId.bavli);

      expect(await db.trackDao.getActiveTracks(CurriculumId.bavli), isEmpty);
      final tracks = await db.trackDao.getAllTracks(CurriculumId.bavli);
      expect(tracks, hasLength(1));
      expect(tracks.first.state, TrackState.retired.storageKey);
    });

    test('deactivateTrack with non-existent track is a no-op', () async {
      await expectLater(
        db.trackDao.deactivateTrack(CurriculumId.bavli),
        completes,
      );

      // No row existed and none should have been created.
      expect(await db.trackDao.getAllTracks(CurriculumId.bavli), isEmpty);
    });
  });

  // ─── activateTrack — reactivation path ───────────────────────────────────

  group('TrackDao.activateTrack — reactivation path', () {
    test(
      'reactivates an inactive personal track instead of creating a new one',
      () async {
        // Insert a track as inactive.
        await insertRawTrack(
          curriculumId: 'bavli',
          trackType: 'personal',
          profileId: 0,
          isActive: false,
        );

        // Reactivate through activateTrack.
        await db.trackDao.activateTrack(CurriculumId.bavli);

        final tracks = await db.trackDao.getAllTracks(CurriculumId.bavli);
        // Should still be just one row, now active.
        expect(tracks, hasLength(1));
        expect(tracks.first.state, 'active');
      },
    );
  });

  // ─── upsertFromSync ───────────────────────────────────────────────────────

  group('upsertFromSync', () {
    final activatedAt = DateTime.utc(2026, 3, 10);

    test('inserts a new track when none exists', () async {
      await db.trackDao.upsertFromSync(
        profileId: 1,
        curriculumId: CurriculumId.mishnayos,
        state: 'active',
        stateChangedAt: activatedAt,
        activatedAt: activatedAt,
      );

      final tracks = await db.trackDao.getAllForProfile(1);
      expect(tracks, hasLength(1));
      expect(tracks.first.curriculumId, CurriculumId.mishnayos.storageKey);
      expect(tracks.first.state, 'active');
    });

    test(
      'updates existing track when one matches (profileId, curriculumId, trackType)',
      () async {
        // First insert via upsert
        await db.trackDao.upsertFromSync(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
          state: 'active',
          stateChangedAt: activatedAt,
          activatedAt: activatedAt,
        );

        // Now update via second upsert — should toggle isActive
        final laterDate = DateTime.utc(2026, 4, 1);
        await db.trackDao.upsertFromSync(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
          state: 'retired',
          stateChangedAt: laterDate,
          activatedAt: laterDate,
        );

        final tracks = await db.trackDao.getAllForProfile(1);
        // Should still be only one track (updated, not duplicated).
        expect(tracks, hasLength(1));
        expect(tracks.first.state, isNot('active'));
      },
    );

    test('stores stateChangedAt when retired', () async {
      final retiredAt = DateTime.utc(2026, 5, 1);
      await db.trackDao.upsertFromSync(
        profileId: 2,
        curriculumId: CurriculumId.bavli,
        state: 'retired',
        stateChangedAt: retiredAt,
        activatedAt: activatedAt,
      );

      final tracks = await db.trackDao.getAllForProfile(2);
      expect(tracks, hasLength(1));
      expect(
        tracks.first.stateChangedAt.millisecondsSinceEpoch,
        retiredAt.millisecondsSinceEpoch,
      );
    });

    test('two profiles each get their own track row', () async {
      await db.trackDao.upsertFromSync(
        profileId: 1,
        curriculumId: CurriculumId.chumash,
        state: 'active',
        stateChangedAt: activatedAt,
        activatedAt: activatedAt,
      );
      await db.trackDao.upsertFromSync(
        profileId: 2,
        curriculumId: CurriculumId.chumash,
        state: 'active',
        stateChangedAt: activatedAt,
        activatedAt: activatedAt,
      );

      expect(await db.trackDao.getAllForProfile(1), hasLength(1));
      expect(await db.trackDao.getAllForProfile(2), hasLength(1));
    });
  });

  group('TrackDao.upsertFromSync', () {
    test('inserts a new track when none exists', () async {
      final activatedAt = DateTime.utc(2026, 3, 1);

      await db.trackDao.upsertFromSync(
        profileId: 1,
        curriculumId: CurriculumId.bavli,
        state: 'active',
        stateChangedAt: activatedAt,
        activatedAt: activatedAt,
      );

      final tracks = await db.trackDao.getAllForProfile(1);
      expect(tracks, hasLength(1));
      expect(tracks.first.state, 'active');
      // Compare milliseconds to avoid UTC/local timezone mismatch.
      expect(
        tracks.first.activatedAt.millisecondsSinceEpoch,
        activatedAt.millisecondsSinceEpoch,
      );
    });

    test('updates an existing track when it already exists', () async {
      final original = DateTime.utc(2026, 1, 1);
      final updated = DateTime.utc(2026, 5, 1);

      await db.trackDao.upsertFromSync(
        profileId: 1,
        curriculumId: CurriculumId.bavli,
        state: 'active',
        stateChangedAt: original,
        activatedAt: original,
      );

      await db.trackDao.upsertFromSync(
        profileId: 1,
        curriculumId: CurriculumId.bavli,
        state: 'retired',
        stateChangedAt: updated,
        activatedAt: updated,
      );

      final tracks = await db.trackDao.getAllForProfile(1);
      expect(tracks, hasLength(1)); // no duplicate
      expect(tracks.first.state, isNot('active'));
      expect(
        tracks.first.activatedAt.millisecondsSinceEpoch,
        updated.millisecondsSinceEpoch,
      );
      expect(tracks.first.stateChangedAt, isNotNull);
    });

    test('stores paceResetDate when provided', () async {
      final paceReset = DateTime.utc(2026, 4, 15);
      final baseDate = DateTime.utc(2026, 1, 1);

      await db.trackDao.upsertFromSync(
        profileId: 1,
        curriculumId: CurriculumId.mishnayos,
        state: 'active',
        stateChangedAt: baseDate,
        activatedAt: baseDate,
        paceResetDate: paceReset,
      );

      final tracks = await db.trackDao.getAllForProfile(1);
      expect(tracks.first.paceResetDate, isNotNull);
      expect(
        tracks.first.paceResetDate!.millisecondsSinceEpoch,
        paceReset.millisecondsSinceEpoch,
      );
    });
  });

  // ─── resetPace ────────────────────────────────────────────────────────────

  group('resetPace', () {
    test('sets paceResetDate to a non-null value for the track', () async {
      final trackId = await insertTrack();
      // Verify paceResetDate starts as null.
      final before = await db.trackDao.getTrackById(trackId);
      expect(before!.paceResetDate, isNull);

      await db.trackDao.resetPace(trackId);

      final after = await db.trackDao.getTrackById(trackId);
      expect(after!.paceResetDate, isNotNull);
    });

    test('resetPace for non-existent track does not throw', () async {
      await expectLater(db.trackDao.resetPace(9999), completes);
    });
  });

  group('TrackDao.resetPace', () {
    test('stamps paceResetDate on the track row', () async {
      final trackId = await insertTrack(profileId: 1);

      await db.trackDao.resetPace(trackId);

      final track = await db.trackDao.getTrackById(trackId);
      expect(track, isNotNull);
      expect(track!.paceResetDate, isNotNull);
    });
  });

  // ─── getAllForProfile ─────────────────────────────────────────────────────

  group('getAllForProfile', () {
    test('returns all tracks (active and inactive) for a profile', () async {
      final trackId1 = await insertTrack(profileId: 10);
      await insertTrack(curriculum: CurriculumId.chumash, profileId: 10);

      // Soft-delete the first track.
      await db.trackDao.deleteTrackAndData(trackId1);

      // getAllForProfile includes soft-deleted rows.
      final all = await db.trackDao.getAllForProfile(10);
      expect(all, hasLength(2));

      // getActiveTracksForProfile excludes soft-deleted rows.
      final active = await db.trackDao.getActiveTracksForProfile(10);
      expect(active, hasLength(1));
    });

    test('returns empty list when no tracks exist for profile', () async {
      final tracks = await db.trackDao.getAllForProfile(99);
      expect(tracks, isEmpty);
    });
  });

  group('TrackDao.getAllForProfile', () {
    test('returns all tracks (active and inactive) for the profile', () async {
      await insertRawTrack(
        curriculumId: 'bavli',
        trackType: 'personal',
        profileId: 1,
        isActive: true,
      );
      await insertRawTrack(
        curriculumId: 'mishnayos',
        trackType: 'personal',
        profileId: 1,
        isActive: false,
      );
      await insertRawTrack(
        curriculumId: 'bavli',
        trackType: 'personal',
        profileId: 2,
        isActive: true,
      );

      final tracks = await db.trackDao.getAllForProfile(1);
      expect(tracks, hasLength(2));
      final curriculumIds = tracks.map((t) => t.curriculumId).toSet();
      expect(curriculumIds, containsAll(['bavli', 'mishnayos']));
    });

    test('returns empty list when profile has no tracks', () async {
      final tracks = await db.trackDao.getAllForProfile(99);
      expect(tracks, isEmpty);
    });
  });

  group('TrackDao.countActiveTracksForProfile', () {
    test('counts only active non-deleted tracks for profile', () async {
      await insertRawTrack(curriculumId: 'bavli', profileId: 3, isActive: true);
      await insertRawTrack(
        curriculumId: 'mishnayos',
        profileId: 3,
        isActive: false,
      );

      final count = await db.trackDao.countActiveTracksForProfile(3);
      expect(count, 1);
    });
  });

  group('TrackDao.getActiveTracksForProfile', () {
    test('returns tracks ordered by curriculumId ascending', () async {
      await insertRawTrack(
        curriculumId: 'mishnayos',
        profileId: 10,
        isActive: true,
      );
      await insertRawTrack(
        curriculumId: 'bavli',
        profileId: 10,
        isActive: true,
      );

      final tracks = await db.trackDao.getActiveTracksForProfile(10);
      expect(tracks, hasLength(2));
      // 'bavli' comes before 'mishnayos' alphabetically.
      expect(tracks.first.curriculumId, 'bavli');
      expect(tracks.last.curriculumId, 'mishnayos');
    });
  });
}
