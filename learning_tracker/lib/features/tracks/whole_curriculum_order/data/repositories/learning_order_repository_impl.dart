import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/repositories/learning_order_repository.dart'
    show LearningOrderRepository, ParentControlException;

/// AUD-tracks-15 (SM-8): this repository only talks to its own DAO
/// (`UserDatabase.learningOrderDao` / `.trackDao`). It no longer holds a
/// `ContentRepository` dependency — the content-fetch orchestration lives in
/// `learning_order_providers.dart`, which resolves the curriculum's content
/// list and passes it in as `allItems` on every `getOrder` call. Mirrors the
/// same fix applied to `TrackLearningOrderRepositoryImpl`.
class LearningOrderRepositoryImpl implements LearningOrderRepository {
  LearningOrderRepositoryImpl({
    required UserDatabase database,
    SyncWriteFacade? syncEngine,
    int profileId = 0,
    int currentContentVersion = 1,
  }) : _database = database,
       _syncEngine = syncEngine,
       _profileId = profileId,
       _currentContentVersion = currentContentVersion;

  final UserDatabase _database;
  final SyncWriteFacade? _syncEngine;
  final int _profileId;
  final int _currentContentVersion;

  /// Returns a map from sefariaRef → (displayNameHe, displayNameEn, sortOrder)
  /// for all drag-level (level2, non-leaf) items of a curriculum.
  Map<String, ({String he, String en, int sortOrder})> _buildRefIndex(
    List<ContentItem> allItems,
  ) {
    final index = <String, ({String he, String en, int sortOrder})>{};
    for (final item in allItems) {
      if (item.level2 != null && !item.isLeaf) {
        index.putIfAbsent(
          item.sefariaRef,
          () => (
            he: item.displayNameHe,
            en: item.displayNameEn,
            sortOrder: item.sortOrder,
          ),
        );
      }
    }
    return index;
  }

  @override
  // AUD-tracks-06: getOrder is a pure read — no DB writes. It is invoked
  // directly from learningOrderProvider's FutureProvider.family `build`
  // callback (SM-2: provider build must stay pure). The §10.1
  // version-mismatch re-amnesty write used to live here as a side effect
  // of reading; it now lives in [repairStaleOrderVersion], an explicit,
  // idempotent, one-shot step callers invoke outside of provider build.
  Future<List<LearningOrderItem>> getOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) async {
    final rows = await _database.learningOrderDao.getLearningOrderByCurriculum(
      curriculumId.storageKey,
      profileId: _profileId,
    );
    final index = _buildRefIndex(allItems);

    if (rows.isNotEmpty) {
      // Custom order exists — return sorted by userSortOrder, enriched with display names
      return rows.map((r) {
        final info = index[r.sefariaRef];
        return LearningOrderItem(
          sefariaRef: r.sefariaRef,
          displayNameHe: info?.he ?? r.sefariaRef,
          displayNameEn: info?.en ?? r.sefariaRef,
          userSortOrder: r.userSortOrder,
          isCustomOrdered: true,
        );
      }).toList();
    }

    // No custom order — fall back to ContentItem.sortOrder at drag level
    final sorted = index.entries.toList()
      ..sort((a, b) => a.value.sortOrder.compareTo(b.value.sortOrder));

    return sorted
        .asMap()
        .entries
        .map(
          (e) => LearningOrderItem(
            sefariaRef: e.value.key,
            displayNameHe: e.value.value.he,
            displayNameEn: e.value.value.en,
            userSortOrder: e.key,
            isCustomOrdered: false,
          ),
        )
        .toList();
  }

  @override
  Future<void> repairStaleOrderVersion(CurriculumId curriculumId) async {
    final rows = await _database.learningOrderDao.getLearningOrderByCurriculum(
      curriculumId.storageKey,
      profileId: _profileId,
    );
    if (rows.isEmpty) return;

    // §10.1 — Version guard: if any saved rows carry a different content
    // version, the order was saved against a different seed. Re-amnesty the
    // track so stale overdue tasks are cleared; the order items themselves
    // are still returned by [getOrder] unaffected (matched by sefariaRef) so
    // the user keeps their customisation where refs survived the reseed.
    final savedVersion = rows.first.learningOrderVersion;
    if (savedVersion == _currentContentVersion) return;

    AppLogger.instance.warning(
      event:
          'learning_order_version_mismatch: saved=$savedVersion '
          'current=$_currentContentVersion for ${curriculumId.storageKey} '
          '(profile=$_profileId); re-amnestying track.',
    );
    await _stampReorderAt(curriculumId, DateTimeFactory.nowUtc());

    // AUD-tracks-06: mark the rows repaired so this is a genuine one-shot —
    // a second call against the same stale rows now sees the version
    // already matches and no-ops, instead of re-stamping lastReorderAt on
    // every invocation.
    await _database.learningOrderDao.markLearningOrderVersionRepaired(
      curriculumId.storageKey,
      profileId: _profileId,
      version: _currentContentVersion,
    );
  }

  @override
  Future<void> saveOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items, {
    bool isChildRestricted = false,
  }) async {
    // Parent-control guard enforced at repository, not UI.
    if (isChildRestricted) {
      throw const ParentControlException();
    }

    final updatedAt = DateTimeFactory.nowUtc();

    // Wrap all upserts AND the reorder-amnesty stamp in a single transaction
    // so a mid-loop crash cannot leave a half-shuffled state (D7, T2.10), nor
    // commit the new order without the amnesty stamp that clears overdue
    // items scheduled before it (AUD-tracks-16 — DB-2).
    await _database.transaction(() async {
      for (var i = 0; i < items.length; i++) {
        await _database.learningOrderDao.upsertLearningOrder(
          LearningOrderCompanion.insert(
            curriculumId: curriculumId.storageKey,
            sefariaRef: items[i].sefariaRef,
            userSortOrder: i,
            profileId: _profileId,
            updatedAt: Value(updatedAt),
            // §10.1: stamp the current content version so a future reseed
            // can detect that the order was saved against a different seed.
            learningOrderVersion: Value(_currentContentVersion),
          ),
        );
      }

      // Reorder-amnesty: stamp lastReorderAt on the affected track so the
      // projection filter clears overdue items that were scheduled before
      // this reorder. This is a content-order change — not a
      // pace/stage/bookmark change — so amnesty applies (architecture
      // §10.1). Must be inside the same transaction as the upserts above:
      // a crash between the two would otherwise commit the new order with
      // no amnesty stamp (AUD-tracks-16).
      await _stampReorderAt(curriculumId, updatedAt);
    });

    // Push to Firestore (offline-queued, retry on reconnect).
    await _syncEngine?.pushLearningOrder(
      profileId: _profileId,
      curriculumId: curriculumId.storageKey,
      items: items.asMap().entries.map((e) {
        return {'sefaria_ref': e.value.sefariaRef, 'user_sort_order': e.key};
      }).toList(),
      updatedAt: updatedAt,
    );
  }

  @override
  Future<void> resetToDefault(CurriculumId curriculumId) async {
    final now = DateTimeFactory.nowUtc();

    // Wrap the delete AND the reorder-amnesty stamp in a single transaction
    // so a mid-op crash cannot commit the delete without the amnesty stamp
    // (AUD-tracks-16 — DB-2).
    await _database.transaction(() async {
      await _database.learningOrderDao.deleteAllForCurriculum(
        curriculumId.storageKey,
        profileId: _profileId,
      );

      // Reorder-amnesty: a reset-to-default is a content-order change.
      await _stampReorderAt(curriculumId, now);
    });

    // Push empty order to Firestore so other devices know custom ordering
    // has been cleared (each device falls back to natural content sort).
    await _syncEngine?.pushLearningOrder(
      profileId: _profileId,
      curriculumId: curriculumId.storageKey,
      items: const [],
      updatedAt: now,
    );
  }

  /// Stamp [lastReorderAt] on the active track for [curriculumId] / [profileId].
  ///
  /// Looks up the track id first; no-ops silently when no active track is
  /// found (e.g. during setup before the track is created).
  Future<void> _stampReorderAt(CurriculumId curriculumId, DateTime at) async {
    final activeTracks = await _database.trackDao.getActiveTracks(curriculumId);
    final track = activeTracks
        .where((t) => t.profileId == _profileId)
        .firstOrNull;
    if (track != null) {
      await _database.trackDao.stampReorderAt(track.id, at: at);
    }
  }
}
