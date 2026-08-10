import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int trackId;
  const profileId = 1;

  setUp(() async {
    db = inMemoryDb();
    // AUD-t-cross-06: track_learning_order.profileId is now a real FK to
    // learner_profiles(id) — seed the owning profile (id = 1) first.
    await seedProfile(db);
    trackId = await seedTrack(
      db,
      profileId: profileId,
      curriculumId: 'bavli',
      activatedAt: DateTime.utc(2026, 1, 1),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TrackLearningOrderDao', () {
    group('upsertOrder', () {
      test('inserts rows with sequential sortOrder indices', () async {
        await db.trackLearningOrderDao.upsertOrder(profileId, trackId, [
          'Berakhot 2a',
          'Berakhot 2b',
          'Berakhot 3a',
        ]);

        final rows = await db.trackLearningOrderDao.getByTrack(
          profileId,
          trackId,
        );
        expect(rows, hasLength(3));
        expect(rows.map((r) => r.sefariaRef), [
          'Berakhot 2a',
          'Berakhot 2b',
          'Berakhot 3a',
        ]);
        expect(rows.map((r) => r.sortOrder), [0, 1, 2]);
      });

      test('re-running with the same refs is idempotent', () async {
        final refs = ['Berakhot 2a', 'Berakhot 2b'];
        await db.trackLearningOrderDao.upsertOrder(profileId, trackId, refs);
        await db.trackLearningOrderDao.upsertOrder(profileId, trackId, refs);
        final rows = await db.trackLearningOrderDao.getByTrack(
          profileId,
          trackId,
        );
        expect(rows, hasLength(2));
      });

      test('updates sortOrder on conflict with a new order', () async {
        await db.trackLearningOrderDao.upsertOrder(profileId, trackId, [
          'a',
          'b',
          'c',
        ]);
        // Now swap a and c — same refs, different order. The unique key is
        // (profileId, trackId, sefariaRef) so this should update sortOrder
        // in place.
        await db.trackLearningOrderDao.upsertOrder(profileId, trackId, [
          'c',
          'b',
          'a',
        ]);

        final rows = await db.trackLearningOrderDao.getByTrack(
          profileId,
          trackId,
        );
        expect(rows, hasLength(3));
        expect(rows.map((r) => r.sefariaRef), ['c', 'b', 'a']);
      });

      test('empty list is a no-op', () async {
        await db.trackLearningOrderDao.upsertOrder(
          profileId,
          trackId,
          const [],
        );
        final rows = await db.trackLearningOrderDao.getByTrack(
          profileId,
          trackId,
        );
        expect(rows, isEmpty);
      });

      test('is all-or-nothing: a failure partway through leaves zero new rows '
          '(AUD-core-database-05, DB-2/DB-3)', () async {
        // A genuine SQLite failure injected via a trigger on a poison
        // sefariaRef value — not a fake/mocked exception — so this proves
        // real atomicity of whatever write strategy upsertOrder uses. If
        // upsertOrder is an awaited per-row loop (the pre-fix shape), the
        // two refs preceding the poison ref are already committed
        // individually before the loop reaches — and throws on — the
        // third; this assertion catches that.
        await db.customStatement('''
            CREATE TRIGGER poison_track_learning_order
            BEFORE INSERT ON track_learning_order
            WHEN NEW.sefaria_ref = 'BOOM'
            BEGIN
              SELECT RAISE(ABORT, 'injected failure for atomicity test');
            END;
          ''');

        await expectLater(
          db.trackLearningOrderDao.upsertOrder(profileId, trackId, [
            'Berakhot 2a',
            'Berakhot 2b',
            'BOOM',
            'Berakhot 3a',
          ]),
          throwsA(anything),
        );

        final rows = await db.trackLearningOrderDao.getByTrack(
          profileId,
          trackId,
        );
        expect(
          rows,
          isEmpty,
          reason:
              'a failure partway through upsertOrder must leave zero rows '
              'written — a per-row awaited loop instead leaves the refs '
              'before the failing one committed',
        );
      });
    });

    group('getByTrack', () {
      test('returns empty for an unknown track', () async {
        final rows = await db.trackLearningOrderDao.getByTrack(profileId, 9999);
        expect(rows, isEmpty);
      });

      test('orders rows by sortOrder ascending', () async {
        await db.trackLearningOrderDao.upsertOrder(profileId, trackId, [
          'z',
          'a',
          'm',
        ]);
        final rows = await db.trackLearningOrderDao.getByTrack(
          profileId,
          trackId,
        );
        // upsertOrder writes sortOrder=0..n-1 in the list order, so
        // the result must echo that.
        expect(rows.map((r) => r.sefariaRef), ['z', 'a', 'm']);
      });

      test('AUD-t-cross-06: returns empty when profileId does not match the '
          "track's owning profile, even though trackId matches — the "
          'schema-level isolation guard the finding closed', () async {
        await db.trackLearningOrderDao.upsertOrder(profileId, trackId, [
          'Berakhot 2a',
        ]);

        final otherProfileId = await db
            .into(db.learnerProfiles)
            .insert(
              LearnerProfilesCompanion.insert(
                accountId: 1,
                displayName: 'Other Profile',
                mode: 'adult',
                createdAt: DateTime.utc(2026, 1, 1),
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );

        final rows = await db.trackLearningOrderDao.getByTrack(
          otherProfileId,
          trackId,
        );
        expect(
          rows,
          isEmpty,
          reason:
              'a stale/confused trackId must never surface another '
              "profile's custom ordering",
        );
      });
    });

    group('deleteByTrack', () {
      test('removes all rows for the given track only', () async {
        final otherTrackId = await seedTrack(
          db,
          profileId: profileId,
          curriculumId: 'mishnayos',
          activatedAt: DateTime.utc(2026, 1, 1),
        );
        await db.trackLearningOrderDao.upsertOrder(profileId, trackId, [
          'a',
          'b',
        ]);
        await db.trackLearningOrderDao.upsertOrder(profileId, otherTrackId, [
          'x',
          'y',
        ]);

        await db.trackLearningOrderDao.deleteByTrack(profileId, trackId);

        expect(
          await db.trackLearningOrderDao.getByTrack(profileId, trackId),
          isEmpty,
        );
        expect(
          (await db.trackLearningOrderDao.getByTrack(
            profileId,
            otherTrackId,
          )).map((r) => r.sefariaRef),
          ['x', 'y'],
        );
      });

      test('AUD-t-cross-06: does not delete rows when profileId does not '
          'match, even though trackId matches', () async {
        await db.trackLearningOrderDao.upsertOrder(profileId, trackId, [
          'a',
          'b',
        ]);

        final otherProfileId = await db
            .into(db.learnerProfiles)
            .insert(
              LearnerProfilesCompanion.insert(
                accountId: 1,
                displayName: 'Other Profile',
                mode: 'adult',
                createdAt: DateTime.utc(2026, 1, 1),
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            );

        await db.trackLearningOrderDao.deleteByTrack(otherProfileId, trackId);

        expect(
          await db.trackLearningOrderDao.getByTrack(profileId, trackId),
          hasLength(2),
          reason:
              'a delete scoped to a non-owning profileId must not touch '
              "another profile's rows, even when trackId matches",
        );
      });
    });
  });
}
