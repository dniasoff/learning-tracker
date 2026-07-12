import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

import '../../../helpers/drift_memory.dart';

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    trackId = await db
        .into(db.curriculumTracks)
        .insert(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('TrackLearningOrderDao', () {
    group('upsertOrder', () {
      test('inserts rows with sequential sortOrder indices', () async {
        await db.trackLearningOrderDao.upsertOrder(trackId, [
          'Berakhot 2a',
          'Berakhot 2b',
          'Berakhot 3a',
        ]);

        final rows = await db.trackLearningOrderDao.getByTrack(trackId);
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
        await db.trackLearningOrderDao.upsertOrder(trackId, refs);
        await db.trackLearningOrderDao.upsertOrder(trackId, refs);
        final rows = await db.trackLearningOrderDao.getByTrack(trackId);
        expect(rows, hasLength(2));
      });

      test('updates sortOrder on conflict with a new order', () async {
        await db.trackLearningOrderDao.upsertOrder(trackId, ['a', 'b', 'c']);
        // Now swap a and c — same refs, different order. The unique key is
        // (trackId, sefariaRef) so this should update sortOrder in place.
        await db.trackLearningOrderDao.upsertOrder(trackId, ['c', 'b', 'a']);

        final rows = await db.trackLearningOrderDao.getByTrack(trackId);
        expect(rows, hasLength(3));
        expect(rows.map((r) => r.sefariaRef), ['c', 'b', 'a']);
      });

      test('empty list is a no-op', () async {
        await db.trackLearningOrderDao.upsertOrder(trackId, const []);
        final rows = await db.trackLearningOrderDao.getByTrack(trackId);
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
          db.trackLearningOrderDao.upsertOrder(trackId, [
            'Berakhot 2a',
            'Berakhot 2b',
            'BOOM',
            'Berakhot 3a',
          ]),
          throwsA(anything),
        );

        final rows = await db.trackLearningOrderDao.getByTrack(trackId);
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
        final rows = await db.trackLearningOrderDao.getByTrack(9999);
        expect(rows, isEmpty);
      });

      test('orders rows by sortOrder ascending', () async {
        await db.trackLearningOrderDao.upsertOrder(trackId, ['z', 'a', 'm']);
        final rows = await db.trackLearningOrderDao.getByTrack(trackId);
        // upsertOrder writes sortOrder=0..n-1 in the list order, so
        // the result must echo that.
        expect(rows.map((r) => r.sefariaRef), ['z', 'a', 'm']);
      });
    });

    group('deleteByTrack', () {
      test('removes all rows for the given track only', () async {
        final otherTrackId = await db
            .into(db.curriculumTracks)
            .insert(
              CurriculumTracksCompanion.insert(
                profileId: 1,
                curriculumId: 'mishnayos',
                stateChangedAt: DateTime.utc(2026, 1, 1),
                activatedAt: DateTime.utc(2026, 1, 1),
              ),
            );
        await db.trackLearningOrderDao.upsertOrder(trackId, ['a', 'b']);
        await db.trackLearningOrderDao.upsertOrder(otherTrackId, ['x', 'y']);

        await db.trackLearningOrderDao.deleteByTrack(trackId);

        expect(await db.trackLearningOrderDao.getByTrack(trackId), isEmpty);
        expect(
          (await db.trackLearningOrderDao.getByTrack(
            otherTrackId,
          )).map((r) => r.sefariaRef),
          ['x', 'y'],
        );
      });
    });
  });
}
