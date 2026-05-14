// Extra coverage for TrackDao — upsertFromSync, getAllForProfile,
// activateTrack reactivation path, and resetPace were not fully exercised by
// the baseline test.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;

  setUp(() {
    db = inMemoryDb();
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // Helper — insert a track row directly (bypasses DAO public API)
  // ---------------------------------------------------------------------------

  Future<int> insertTrack({
    int profileId = 1,
    String curriculumId = 'bavli',
    String trackType = 'personal',
    bool isActive = true,
  }) {
    return db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: profileId,
            curriculumId: curriculumId,
            trackType: trackType,
            isActive: Value(isActive),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // activateTrack — reactivation path (existing inactive track)
  // ---------------------------------------------------------------------------

  group('TrackDao.activateTrack — reactivation path', () {
    test(
      'reactivates an inactive track without creating a duplicate',
      () async {
        // Insert an inactive personal track directly.
        await insertTrack(isActive: false);

        await db.trackDao.activateTrack(
          CurriculumId.bavli,
          TrackType.personal,
          profileId: 1,
        );

        final tracks = await db.trackDao.getAllTracks(CurriculumId.bavli);
        // Only one row should exist (no duplicate inserted).
        expect(tracks, hasLength(1));
        expect(tracks.first.isActive, isTrue);
      },
    );

    test('activateTrack on an already-active track is idempotent', () async {
      await insertTrack(isActive: true);

      await db.trackDao.activateTrack(
        CurriculumId.bavli,
        TrackType.personal,
        profileId: 1,
      );

      final tracks = await db.trackDao.getAllTracks(CurriculumId.bavli);
      expect(tracks, hasLength(1));
      expect(tracks.first.isActive, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // upsertFromSync
  // ---------------------------------------------------------------------------

  group('TrackDao.upsertFromSync', () {
    test('inserts a new row when none exists', () async {
      final activatedAt = DateTime.utc(2026, 3, 1);
      await db.trackDao.upsertFromSync(
        profileId: 5,
        curriculumId: CurriculumId.bavli,
        trackType: TrackType.personal,
        isActive: true,
        activatedAt: activatedAt,
      );

      final tracks = await db.trackDao.getAllForProfile(5);
      expect(tracks, hasLength(1));
      expect(tracks.first.isActive, isTrue);
      expect(
        tracks.first.activatedAt.millisecondsSinceEpoch,
        activatedAt.millisecondsSinceEpoch,
      );
    });

    test('updates an existing row when one already exists', () async {
      final t1 = DateTime.utc(2026, 1, 1);
      final t2 = DateTime.utc(2026, 6, 1);

      await db.trackDao.upsertFromSync(
        profileId: 5,
        curriculumId: CurriculumId.bavli,
        trackType: TrackType.personal,
        isActive: true,
        activatedAt: t1,
      );

      await db.trackDao.upsertFromSync(
        profileId: 5,
        curriculumId: CurriculumId.bavli,
        trackType: TrackType.personal,
        isActive: false,
        activatedAt: t1,
        deactivatedAt: t2,
      );

      final tracks = await db.trackDao.getAllForProfile(5);
      expect(tracks, hasLength(1)); // no duplicate
      expect(tracks.first.isActive, isFalse);
      expect(tracks.first.deactivatedAt, isNotNull);
    });

    test('stores paceResetDate when provided', () async {
      final paceReset = DateTime.utc(2026, 4, 15);
      await db.trackDao.upsertFromSync(
        profileId: 7,
        curriculumId: CurriculumId.bavli,
        trackType: TrackType.personal,
        isActive: true,
        activatedAt: DateTime.utc(2026, 1, 1),
        paceResetDate: paceReset,
      );

      final tracks = await db.trackDao.getAllForProfile(7);
      expect(
        tracks.first.paceResetDate?.millisecondsSinceEpoch,
        paceReset.millisecondsSinceEpoch,
      );
    });

    test('upsertFromSync across two curricula creates two rows', () async {
      await db.trackDao.upsertFromSync(
        profileId: 9,
        curriculumId: CurriculumId.bavli,
        trackType: TrackType.personal,
        isActive: true,
        activatedAt: DateTime.utc(2026, 1, 1),
      );
      await db.trackDao.upsertFromSync(
        profileId: 9,
        curriculumId: CurriculumId.mishnayos,
        trackType: TrackType.personal,
        isActive: true,
        activatedAt: DateTime.utc(2026, 2, 1),
      );

      final tracks = await db.trackDao.getAllForProfile(9);
      expect(tracks, hasLength(2));
    });
  });

  // ---------------------------------------------------------------------------
  // getAllForProfile
  // ---------------------------------------------------------------------------

  group('TrackDao.getAllForProfile', () {
    test('returns all rows including inactive ones', () async {
      await insertTrack(profileId: 3, isActive: true);
      // Insert inactive track with a different curriculum to avoid PK conflict.
      await insertTrack(
        profileId: 3,
        curriculumId: 'mishnayos',
        isActive: false,
      );

      final all = await db.trackDao.getAllForProfile(3);
      expect(all, hasLength(2));
    });

    test('is scoped to the given profile', () async {
      await insertTrack(profileId: 10);
      await insertTrack(profileId: 11, curriculumId: 'mishnayos');

      final forProfile10 = await db.trackDao.getAllForProfile(10);
      expect(forProfile10, hasLength(1));
    });

    test('returns empty list when profile has no tracks', () async {
      final tracks = await db.trackDao.getAllForProfile(99);
      expect(tracks, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // resetPace
  // ---------------------------------------------------------------------------

  group('TrackDao.resetPace', () {
    test('sets paceResetDate on the track row', () async {
      final trackId = await insertTrack();

      await db.trackDao.resetPace(trackId);

      final row = await db.trackDao.getTrackById(trackId);
      expect(row!.paceResetDate, isNotNull);
    });

    test('resetPace is a no-op for a non-existent track id', () async {
      // Should complete without error even when no row exists.
      await expectLater(db.trackDao.resetPace(9999), completes);
    });
  });
}
