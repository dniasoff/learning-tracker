/// Tests for [TrackLearningOrderRepositoryImpl].
///
/// Covers:
///  - getSedarimOrder: default sort (no user order), custom sort via dao
///  - getMasechtosOrder: default sort, custom sort respecting seder grouping
///  - saveSedarimOrder / saveMasechtosOrder: persists refs via dao
///  - resetToDefault: clears stored order
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/network/sefaria/models/curriculum_hierarchy_config.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/data/repositories/track_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

import '../../../../helpers/drift_memory.dart';

// ---------------------------------------------------------------------------
// Minimal stub for ContentRepository — returns whatever items are provided.
// ---------------------------------------------------------------------------

class _StubContentRepository implements ContentRepository {
  _StubContentRepository(this._items);
  final List<ContentItem> _items;

  @override
  Future<List<ContentItem>> getContentForCurriculum(CurriculumId _) async =>
      _items;

  @override
  Future<CurriculumHierarchyConfig> getHierarchyConfig(
    CurriculumId curriculumId,
  ) async => CurriculumHierarchyConfig(
    curriculumId: curriculumId.storageKey,
    levelLabels: const ['Seder', 'Masechta', 'Perek', 'Mishna'],
    totalItems: 0,
  );

  @override
  Future<List<ContentItem>> filterByLevel({
    required CurriculumId curriculumId,
    String? level1,
    String? level2,
    String? level3,
    String? level4,
  }) async => _items;

  @override
  Future<List<ContentItem>> getScopedContent({
    required CurriculumId curriculumId,
    required int scopeLevel,
    required List<String> scopeValues,
  }) async => _items;

  @override
  Future<List<ContentItem>> search({
    required CurriculumId curriculumId,
    required String query,
  }) async => _items;

  @override
  Future<ContentItem?> getContentByRef({
    required CurriculumId curriculumId,
    required String sefariaRef,
  }) async => _items.where((i) => i.sefariaRef == sefariaRef).firstOrNull;
}

// ---------------------------------------------------------------------------
// Helpers for building content items
// ---------------------------------------------------------------------------

ContentItem _seder(String ref, {int sortOrder = 0}) => ContentItem(
  sefariaRef: ref,
  displayNameEn: ref,
  displayNameHe: ref,
  curriculumId: CurriculumId.mishnayos.storageKey,
  sortOrder: sortOrder,
  isLeaf: false,
  level1: ref,
  level2: null,
  level3: null,
  level4: null,
);

ContentItem _masechta(String seder, String ref, {int sortOrder = 0}) =>
    ContentItem(
      sefariaRef: ref,
      displayNameEn: ref,
      displayNameHe: ref,
      curriculumId: CurriculumId.mishnayos.storageKey,
      sortOrder: sortOrder,
      isLeaf: false,
      level1: seder,
      level2: ref,
      level3: null,
      level4: null,
    );

/// Builds a leaf item — should be excluded from seder/masechta index building.
ContentItem _leaf(String ref, {required String seder, String? masechta}) =>
    ContentItem(
      sefariaRef: ref,
      displayNameEn: ref,
      displayNameHe: ref,
      curriculumId: CurriculumId.mishnayos.storageKey,
      sortOrder: 0,
      isLeaf: true,
      level1: seder,
      level2: masechta,
      level3: ref,
      level4: null,
    );

LearningOrderItem _item(String ref, [int order = 0]) => LearningOrderItem(
  sefariaRef: ref,
  displayNameHe: ref,
  displayNameEn: ref,
  userSortOrder: order,
);

TrackLearningOrderRepositoryImpl _makeRepo(
  UserDatabase db,
  List<ContentItem> items,
) => TrackLearningOrderRepositoryImpl(
  database: db,
  contentRepository: _StubContentRepository(items),
);

/// Creates a hierarchy:
///   Seder Zeraim (L1 container, no L2)
///     └── Berakhot (L2 container, no L3)
///           └── Berakhot 1:1 (leaf)
List<ContentItem> _mishnaItems() => [
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Zeraim',
    displayNameHe: 'סדר זרעים',
    displayNameEn: 'Seder Zeraim',
    sefariaRef: 'Seder Zeraim',
    sortOrder: 0,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Zeraim',
    level2: 'Berakhot',
    displayNameHe: 'ברכות',
    displayNameEn: 'Berakhot',
    sefariaRef: 'Berakhot',
    sortOrder: 1,
    isLeaf: false,
  ),
  const ContentItem(
    curriculumId: 'mishnayos',
    level1: 'Seder Zeraim',
    level2: 'Berakhot',
    level3: '1',
    level4: '1',
    displayNameHe: 'ברכות א׃א',
    displayNameEn: 'Berakhot 1:1',
    sefariaRef: 'Mishnah Berakhot 1:1',
    sortOrder: 2,
    isLeaf: true,
  ),
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    // AUD-t-cross-06: track_learning_order.profileId is now a real FK to
    // learner_profiles(id) — seed the owning profile (id = 0, matching the
    // track's profileId below) first.
    await seedProfileZero(db);
    final track = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos.storageKey,
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    trackId = track.id;
  });

  tearDown(() async => db.close());

  // ─── getSedarimOrder — default ordering ────────────────────────────────────

  group('getSedarimOrder — default (no user order saved)', () {
    test('returns sedarim sorted by sortOrder ascending', () async {
      final items = [
        _seder('Nashim', sortOrder: 2),
        _seder('Zeraim', sortOrder: 0),
        _seder('Moed', sortOrder: 1),
      ];
      final repo = _makeRepo(db, items);

      final result = await repo.getSedarimOrder(
        trackId,
        CurriculumId.mishnayos,
      );

      expect(result.map((i) => i.sefariaRef).toList(), [
        'Zeraim',
        'Moed',
        'Nashim',
      ]);
      expect(result.every((i) => !i.isCustomOrdered), isTrue);
    });

    test('returns empty list when content has no sedarim containers', () async {
      final repo = _makeRepo(db, []);
      final result = await repo.getSedarimOrder(
        trackId,
        CurriculumId.mishnayos,
      );
      expect(result, isEmpty);
    });

    test('excludes masechtos and leaves from seder list', () async {
      final items = [
        _seder('Zeraim', sortOrder: 0),
        _masechta('Zeraim', 'Berakhot', sortOrder: 0),
        _leaf('Berakhot 1:1', seder: 'Zeraim', masechta: 'Berakhot'),
      ];
      final repo = _makeRepo(db, items);

      final result = await repo.getSedarimOrder(
        trackId,
        CurriculumId.mishnayos,
      );

      expect(result, hasLength(1));
      expect(result.first.sefariaRef, 'Zeraim');
    });
  });

  // ─── getSedarimOrder — custom user order ───────────────────────────────────

  group('getSedarimOrder — with saved user order', () {
    test('respects saved order when refs are present', () async {
      final items = [
        _seder('Zeraim', sortOrder: 0),
        _seder('Moed', sortOrder: 1),
        _seder('Nashim', sortOrder: 2),
      ];
      final repo = _makeRepo(db, items);

      // Save reverse order: Nashim, Moed, Zeraim.
      await repo.saveSedarimOrder(trackId, [
        _item('Nashim', 0),
        _item('Moed', 1),
        _item('Zeraim', 2),
      ]);

      final result = await repo.getSedarimOrder(
        trackId,
        CurriculumId.mishnayos,
      );
      expect(result.map((i) => i.sefariaRef).toList(), [
        'Nashim',
        'Moed',
        'Zeraim',
      ]);
      expect(result.every((i) => i.isCustomOrdered), isTrue);
    });

    test('returns custom sedarim order when rows exist in DAO', () async {
      final items = [
        _seder('Zeraim', sortOrder: 0),
        _seder('Moed', sortOrder: 1),
      ];
      final repo = _makeRepo(db, items);

      // Store custom order: Moed first
      await db.trackLearningOrderDao.upsertOrder(0, trackId, [
        'Moed',
        'Zeraim',
      ]);

      final result = await repo.getSedarimOrder(
        trackId,
        CurriculumId.mishnayos,
      );

      expect(result.map((i) => i.sefariaRef).toList(), ['Moed', 'Zeraim']);
      expect(result.every((i) => i.isCustomOrdered), isTrue);
    });
  });

  // ─── getMasechtosOrder ─────────────────────────────────────────────────────

  group('getMasechtosOrder — default ordering', () {
    test('returns masechtos sorted by sortOrder', () async {
      final items = [
        _seder('Zeraim', sortOrder: 0),
        _masechta('Zeraim', 'Berakhot', sortOrder: 0),
        _masechta('Zeraim', 'Peah', sortOrder: 1),
      ];
      final repo = _makeRepo(db, items);

      final result = await repo.getMasechtosOrder(
        trackId,
        CurriculumId.mishnayos,
      );
      expect(result.map((i) => i.sefariaRef).toList(), ['Berakhot', 'Peah']);
      expect(result.every((i) => !i.isCustomOrdered), isTrue);
    });

    test('returns empty list when no masechtos present', () async {
      final repo = _makeRepo(db, [_seder('Zeraim')]);
      final result = await repo.getMasechtosOrder(
        trackId,
        CurriculumId.mishnayos,
      );
      expect(result, isEmpty);
    });

    test('excludes level-3/leaf rows from masechtos index', () async {
      final items = [
        _seder('Zeraim', sortOrder: 0),
        _masechta('Zeraim', 'Berakhot', sortOrder: 0),
        _leaf('Berakhot 1:1', seder: 'Zeraim', masechta: 'Berakhot'),
      ];
      final repo = _makeRepo(db, items);

      final result = await repo.getMasechtosOrder(
        trackId,
        CurriculumId.mishnayos,
      );

      expect(result, hasLength(1));
      expect(result.first.sefariaRef, 'Berakhot');
    });

    test('returns custom masechtos order when DAO rows exist', () async {
      final items = [
        _seder('Zeraim', sortOrder: 0),
        _masechta('Zeraim', 'Berakhot', sortOrder: 0),
        _masechta('Zeraim', 'Peah', sortOrder: 1),
      ];
      final repo = _makeRepo(db, items);

      // Custom: Peah first
      await db.trackLearningOrderDao.upsertOrder(0, trackId, [
        'Peah',
        'Berakhot',
      ]);

      final result = await repo.getMasechtosOrder(
        trackId,
        CurriculumId.mishnayos,
      );

      expect(result.map((i) => i.sefariaRef).toList(), ['Peah', 'Berakhot']);
      expect(result.every((i) => i.isCustomOrdered), isTrue);
    });
  });

  // ─── saveSedarimOrder / saveMasechtosOrder ─────────────────────────────────

  group('saveSedarimOrder', () {
    test('persists refs via DAO in the given order', () async {
      final items = [
        _seder('Moed', sortOrder: 1),
        _seder('Zeraim', sortOrder: 0),
      ];
      final repo = _makeRepo(db, items);

      await repo.saveSedarimOrder(trackId, [
        _item('Moed', 0),
        _item('Zeraim', 1),
      ]);

      // AUD-app-04: folded the former "(F2 variant)" duplicate's stronger,
      // order-verifying assertion into this test (both exercised the same
      // saveSedarimOrder(trackId, [2 items]) path; this one now checks both
      // ref membership AND the persisted order/sortOrder, which the variant
      // additionally checked and this one previously did not).
      final rows = await db.trackLearningOrderDao.getByTrack(0, trackId);
      expect(rows.map((r) => r.sefariaRef).toList(), ['Moed', 'Zeraim']);
      expect(rows.map((r) => r.sortOrder).toList(), [0, 1]);
    });

    test('upserts on second call (does not duplicate)', () async {
      final items = [_seder('Zeraim')];
      final repo = _makeRepo(db, items);
      await repo.saveSedarimOrder(trackId, [_item('Zeraim')]);
      // Call again with same item.
      await repo.saveSedarimOrder(trackId, [_item('Zeraim', 0)]);

      final rows = await db.trackLearningOrderDao.getByTrack(0, trackId);
      expect(rows, hasLength(1));
    });

    test('saves empty list without error', () async {
      final repo = _makeRepo(db, []);
      await repo.saveSedarimOrder(trackId, []);
      final rows = await db.trackLearningOrderDao.getByTrack(0, trackId);
      expect(rows, isEmpty);
    });
  });

  group('saveMasechtosOrder', () {
    test('persists masechta refs via DAO in the given order', () async {
      final items = [
        _seder('Zeraim', sortOrder: 0),
        _masechta('Zeraim', 'Berakhot', sortOrder: 0),
        _masechta('Zeraim', 'Peah', sortOrder: 1),
      ];
      final repo = _makeRepo(db, items);

      await repo.saveMasechtosOrder(trackId, [
        _item('Peah', 0),
        _item('Berakhot', 1),
      ]);

      // AUD-app-04: folded the former "(F2 variant)" duplicate's stronger,
      // order-verifying assertion into this test (both exercised the same
      // saveMasechtosOrder(trackId, [2 items]) path; this one now checks the
      // persisted order too, which the variant additionally checked and this
      // one previously did not — via containsAll only).
      final rows = await db.trackLearningOrderDao.getByTrack(0, trackId);
      expect(rows.map((r) => r.sefariaRef).toList(), ['Peah', 'Berakhot']);
    });
  });

  // ─── DB-2 atomicity (AUD-core-database-05) ─────────────────────────────────

  group('reorder-write + stampReorderAt atomicity (AUD-core-database-05)', () {
    test('saveSedarimOrder rolls back the order write when the stampReorderAt '
        'update fails, leaving the pre-reorder order intact', () async {
      final repo = _makeRepo(db, [
        _seder('Zeraim', sortOrder: 0),
        _seder('Moed', sortOrder: 1),
      ]);

      // Seed a pre-existing order — this is what must survive a failed
      // reorder attempt untouched.
      await db.trackLearningOrderDao.upsertOrder(0, trackId, ['Zeraim']);

      // Inject a genuine SQLite failure on the SECOND write of the pair
      // (stampReorderAt's UPDATE) via a real trigger — not a fake/mocked
      // exception — so this exercises the actual transaction boundary.
      await db.customStatement('''
          CREATE TRIGGER poison_curriculum_tracks_stamp
          BEFORE UPDATE ON curriculum_tracks
          WHEN NEW.id = $trackId
          BEGIN
            SELECT RAISE(ABORT, 'injected failure for atomicity test');
          END;
        ''');

      await expectLater(
        repo.saveSedarimOrder(trackId, [_item('Moed', 0), _item('Zeraim', 1)]),
        throwsA(anything),
      );

      final rows = await db.trackLearningOrderDao.getByTrack(0, trackId);
      expect(
        rows.map((r) => r.sefariaRef).toList(),
        ['Zeraim'],
        reason:
            'a failed stampReorderAt must roll back the order write too — '
            'the pre-reorder order (["Zeraim"]) must be exactly what is '
            'still stored, not the new (possibly partial) order and not '
            'an empty table',
      );
    });

    test('resetToDefault rolls back deleteByTrack when the stampReorderAt '
        'update fails, leaving the pre-reset order intact', () async {
      final repo = _makeRepo(db, []);
      await db.trackLearningOrderDao.upsertOrder(0, trackId, ['Zeraim']);

      await db.customStatement('''
          CREATE TRIGGER poison_curriculum_tracks_reset
          BEFORE UPDATE ON curriculum_tracks
          WHEN NEW.id = $trackId
          BEGIN
            SELECT RAISE(ABORT, 'injected failure for atomicity test');
          END;
        ''');

      await expectLater(repo.resetToDefault(trackId), throwsA(anything));

      final rows = await db.trackLearningOrderDao.getByTrack(0, trackId);
      expect(
        rows.map((r) => r.sefariaRef).toList(),
        ['Zeraim'],
        reason:
            'a failed stampReorderAt must roll back the deleteByTrack too '
            '— the pre-reset row must still be present',
      );
    });
  });

  // ─── resetToDefault ────────────────────────────────────────────────────────

  group('resetToDefault', () {
    test('clears all stored learning order rows for the track', () async {
      final repo = _makeRepo(db, [
        _seder('Zeraim', sortOrder: 0),
        _seder('Moed', sortOrder: 1),
      ]);

      await repo.saveSedarimOrder(trackId, [
        _item('Moed', 0),
        _item('Zeraim', 1),
      ]);
      expect((await db.trackLearningOrderDao.getByTrack(0, trackId)).length, 2);

      await repo.resetToDefault(trackId);
      expect((await db.trackLearningOrderDao.getByTrack(0, trackId)).length, 0);
    });

    test('is a no-op when no custom order exists', () async {
      final repo = _makeRepo(db, []);
      await repo.resetToDefault(trackId);
      expect(await db.trackLearningOrderDao.getByTrack(0, trackId), isEmpty);
    });

    test('after reset getSedarimOrder returns default content order', () async {
      final items = [
        _seder('Moed', sortOrder: 1),
        _seder('Zeraim', sortOrder: 0),
      ];
      final repo = _makeRepo(db, items);

      // Save reverse so Moed comes first.
      await repo.saveSedarimOrder(trackId, [
        _item('Moed', 0),
        _item('Zeraim', 1),
      ]);

      await repo.resetToDefault(trackId);

      // Default is by sortOrder: Zeraim (0) then Moed (1).
      final result = await repo.getSedarimOrder(
        trackId,
        CurriculumId.mishnayos,
      );
      expect(result.map((i) => i.sefariaRef).toList(), ['Zeraim', 'Moed']);
      expect(result.every((i) => !i.isCustomOrdered), isTrue);
    });

    // AUD-app-04: removed the former "(F2 variant)" duplicate here — it
    // re-verified the same clear-on-reset behavior as
    // 'clears all stored learning order rows for the track' above (seeding
    // rows via the DAO directly instead of via saveSedarimOrder makes no
    // difference: resetToDefault/deleteByTrack never consult the repo's
    // ContentRepository, as confirmed by TrackLearningOrderRepositoryImpl —
    // resetToDefault only calls trackLearningOrderDao.deleteByTrack +
    // trackDao.stampReorderAt, neither of which reads `items`).

    test('does not affect rows for a different track', () async {
      await seedProfile(db); // profile id 1, owner of the other track below.
      final otherTrackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'bavli',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await db.trackLearningOrderDao.upsertOrder(0, trackId, ['Zeraim']);
      await db.trackLearningOrderDao.upsertOrder(1, otherTrackId, ['Moed']);

      final repo = _makeRepo(db, []);
      await repo.resetToDefault(trackId);

      expect(await db.trackLearningOrderDao.getByTrack(0, trackId), isEmpty);
      expect(
        await db.trackLearningOrderDao.getByTrack(1, otherTrackId),
        hasLength(1),
      );
    });
  });

  // ─── F1 additional tests using _mishnaItems() ─────────────────────────────

  group(
    'TrackLearningOrderRepositoryImpl.getSedarimOrder (mishna hierarchy)',
    () {
      test(
        'returns sedarim in default sort order when no custom order saved',
        () async {
          final repo = _makeRepo(db, _mishnaItems());
          final result = await repo.getSedarimOrder(
            trackId,
            CurriculumId.mishnayos,
          );

          // The fake content has "Seder Zeraim" as the only L1-only container.
          expect(result, hasLength(1));
          expect(result.first.sefariaRef, 'Seder Zeraim');
          expect(result.first.isCustomOrdered, isFalse);
        },
      );

      test('returns sedarim in custom order after saveSedarimOrder', () async {
        final repo = _makeRepo(db, _mishnaItems());
        // Our fake only has one seder so we just verify the ref is present.
        await repo.saveSedarimOrder(trackId, [_item('Seder Zeraim')]);

        final result = await repo.getSedarimOrder(
          trackId,
          CurriculumId.mishnayos,
        );

        expect(result, hasLength(1));
        expect(result.first.isCustomOrdered, isTrue);
      });
    },
  );

  group(
    'TrackLearningOrderRepositoryImpl.getMasechtosOrder (mishna hierarchy)',
    () {
      test(
        'returns masechtos in default sort order when no custom order saved',
        () async {
          final repo = _makeRepo(db, _mishnaItems());
          final result = await repo.getMasechtosOrder(
            trackId,
            CurriculumId.mishnayos,
          );

          // The fake content has "Berakhot" as the only L2 container.
          expect(result, hasLength(1));
          expect(result.first.sefariaRef, 'Berakhot');
          expect(result.first.isCustomOrdered, isFalse);
        },
      );

      test(
        'returns masechtos in custom order after saveMasechtosOrder',
        () async {
          final repo = _makeRepo(db, _mishnaItems());
          await repo.saveMasechtosOrder(trackId, [_item('Berakhot')]);

          final result = await repo.getMasechtosOrder(
            trackId,
            CurriculumId.mishnayos,
          );

          expect(result, hasLength(1));
          expect(result.first.isCustomOrdered, isTrue);
        },
      );
    },
  );

  // AUD-app-04: removed the former "(F1 extra)" groups here — they re-ran
  // saveSedarimOrder / saveMasechtosOrder / resetToDefault against the
  // _mishnaItems() fixture, but those three methods never consult
  // ContentRepository/the content-item list at all (see
  // TrackLearningOrderRepositoryImpl.saveSedarimOrder,
  // .saveMasechtosOrder, .resetToDefault — each only calls
  // trackLearningOrderDao.upsertOrder/deleteByTrack + trackDao
  // .stampReorderAt), so persisting/resetting 1-2 refs against the
  // _mishnaItems() fixture exercises byte-for-byte the same DAO code path
  // already covered by the 'saveSedarimOrder' / 'saveMasechtosOrder' /
  // 'resetToDefault' groups above using the simpler _seder()/_masechta()
  // fixtures — a repeat, not a genuinely new path. The _mishnaItems()
  // hierarchy IS still exercised (and remains) in the getSedarimOrder /
  // getMasechtosOrder (mishna hierarchy) groups above, where it's
  // genuinely load-bearing: those two methods DO walk the nested
  // level1/level2/isLeaf hierarchy via ContentRepository.
}
