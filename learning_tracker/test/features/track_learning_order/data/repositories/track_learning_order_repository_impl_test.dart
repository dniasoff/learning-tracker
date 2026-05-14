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
import 'package:learning_tracker/features/learning_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/track_learning_order/data/repositories/track_learning_order_repository_impl.dart';

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
  }) async =>
      _items.where((i) => i.sefariaRef == sefariaRef).firstOrNull;
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

LearningOrderItem _item(String ref, int order) => LearningOrderItem(
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = inMemoryDb();
    final track = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 0,
            curriculumId: CurriculumId.mishnayos.storageKey,
            trackType: 'personal',
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

      final result = await repo.getSedarimOrder(trackId, CurriculumId.mishnayos);

      expect(
        result.map((i) => i.sefariaRef).toList(),
        ['Zeraim', 'Moed', 'Nashim'],
      );
      expect(result.every((i) => !i.isCustomOrdered), isTrue);
    });

    test('returns empty list when content has no sedarim containers', () async {
      final repo = _makeRepo(db, []);
      final result = await repo.getSedarimOrder(trackId, CurriculumId.mishnayos);
      expect(result, isEmpty);
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

      final result = await repo.getSedarimOrder(trackId, CurriculumId.mishnayos);
      expect(
        result.map((i) => i.sefariaRef).toList(),
        ['Nashim', 'Moed', 'Zeraim'],
      );
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
  });

  // ─── saveSedarimOrder / saveMasechtosOrder ─────────────────────────────────

  group('saveSedarimOrder', () {
    test('persists refs so subsequent dao query returns them', () async {
      final items = [
        _seder('Moed', sortOrder: 1),
        _seder('Zeraim', sortOrder: 0),
      ];
      final repo = _makeRepo(db, items);

      await repo.saveSedarimOrder(trackId, [
        _item('Moed', 0),
        _item('Zeraim', 1),
      ]);

      final stored = await db.trackLearningOrderDao.getByTrack(trackId);
      final refs = stored.map((r) => r.sefariaRef).toSet();
      expect(refs, containsAll(['Moed', 'Zeraim']));
    });
  });

  group('saveMasechtosOrder', () {
    test('persists masechta refs via dao', () async {
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

      final stored = await db.trackLearningOrderDao.getByTrack(trackId);
      expect(
        stored.map((r) => r.sefariaRef).toSet(),
        containsAll(['Peah', 'Berakhot']),
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
      expect(
        (await db.trackLearningOrderDao.getByTrack(trackId)).length,
        2,
      );

      await repo.resetToDefault(trackId);
      expect(
        (await db.trackLearningOrderDao.getByTrack(trackId)).length,
        0,
      );
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
      final result = await repo.getSedarimOrder(trackId, CurriculumId.mishnayos);
      expect(
        result.map((i) => i.sefariaRef).toList(),
        ['Zeraim', 'Moed'],
      );
      expect(result.every((i) => !i.isCustomOrdered), isTrue);
    });
  });
}
