/// Firestore implementation for the whole-curriculum learning order — Epic B
/// (`docs/firestore-rewrite-map.md`), built to the shape
/// `lib/data/repositories/firestore_stage_definition_repository.dart`
/// establishes as the reference (resolved-handle constructor, `DocIds`-only
/// doc-ids, one-shot-read decode leniency, composite-index query). This doc
/// comment only calls out what is DIFFERENT for `learning_order`.
///
/// ## The collision finding — READ THIS FIRST
///
/// Two separate Drift tables map onto the single Firestore `learning_order`
/// collection:
///
/// - `LearningOrder` (curriculum-scoped) — unique on `(profileId,
///   curriculumId, sefariaRef)`. Repository: `LearningOrderRepository`
///   (`lib/features/tracks/whole_curriculum_order/`). **This is what this
///   class ports.**
/// - `TrackLearningOrder` (track-scoped, sedarim/masechtos reordering) —
///   unique on `(profileId, trackId, sefariaRef)`. Repository:
///   `TrackLearningOrderRepository`
///   (`lib/features/tracks/track_order/`). **This class does NOT port it —
///   see below.**
///
/// **Decision: only `LearningOrder` (curriculum-scoped) gets a Firestore
/// repository. `TrackLearningOrder` does not, and should not be given one
/// without an owner-approved rules change.** Three independent facts force
/// this, not a preference:
///
/// 1. **`TrackLearningOrder` has no Firestore presence today.**
///    `TrackLearningOrderRepositoryImpl` (`lib/features/tracks/track_order/
///    data/repositories/track_learning_order_repository_impl.dart`) talks
///    only to its Drift DAO — no `SyncWriteFacade` field, no push call, no
///    gateway method. `FirestoreGatewayImpl` has exactly ONE
///    `pushLearningOrder`, and its only caller is
///    `LearningOrderRepositoryImpl.saveOrder`/`.resetToDefault` (whole-
///    curriculum). So porting only the curriculum-scoped side is not a
///    narrowing of scope — it is porting exactly what is already wired to
///    Firestore in production, no more, no less.
/// 2. **The doc-id formula gives a track-scoped write nowhere else to go.**
///    `DocIds.learningOrderDocId` is `{curriculumId}_{ref}` (each component
///    percent-encoded — see that formula's own doc comment for why it no
///    longer mirrors `FirestoreGatewayImpl.pushLearningOrder` byte-for-byte,
///    a deliberate, unrelated fix). AD-25 retired the per-device
///    `TrackLearningOrder.trackId` int as a key component for this
///    migration; `curriculum_id` is the sole canonical stable track key, and
///    there is exactly one track per curriculum. A track-scoped write for
///    `(curriculumId, sefariaRef)` and a curriculum-scoped write for the
///    SAME pair therefore compute the IDENTICAL doc-id if they shared this
///    collection — there is no spare key component left to disambiguate
///    them.
///
///    **Resolution: a separate `track_learning_order` collection now
///    exists** (`firestore.rules` `match /track_learning_order/{orderId}`,
///    `DocIds.trackLearningOrderDocId`) — schema and doc-id only so far, not
///    yet backed by a repository. The collection PATH, not a doc-id
///    component, is what disambiguates the two orderings; see
///    `DocIds.trackLearningOrderDocId`'s doc comment for the full reasoning.
///    This class still does not build that repository — see point 1 above.
/// 3. **`firestore.rules` structurally forbids inventing a discriminator
///    field.** `match /learning_order/{orderId}` gates `create`/`update` on
///    `request.resource.data.keys().hasOnly(['curriculum_id', 'sefaria_ref',
///    'ref', 'user_sort_order', 'updated_at', 'synced_at'])` — a client
///    write carrying any extra field (e.g. `scope` or `track_id`) is
///    rejected outright. So this is not merely "no formula exists yet" —
///    the current rules make it impossible for a client to write a
///    self-describing discriminator into this collection at all without a
///    rules change (out of scope here; `firestore.rules` is shared across
///    every concurrently-built repository in this migration).
///
/// The domains genuinely overlap, too, not just hypothetically:
/// `TrackLearningOrderRepositoryImpl.saveMasechtosOrder` reorders level-2,
/// non-leaf `ContentItem`s (`MasechtaOrderingPolicy`) — the exact same
/// `sefariaRef` universe `LearningOrderRepositoryImpl.getOrder`'s
/// `_buildRefIndex` draws from (`item.level2 != null && !item.isLeaf`). A
/// masechta-level custom track order and a masechta-level custom
/// curriculum order for the same masechta are not just doc-id-colliding in
/// the abstract — they would routinely reference the very same ref string.
/// See the "doc-id collision" test group in this class's test file for a
/// concrete demonstration: two independent [saveOrder] calls for the same
/// `(curriculumId, sefariaRef)` silently overwrite one another with no
/// error, no merge, no signal — exactly the failure mode a second,
/// track-scoped writer through this same collection would hit on every
/// masechta-level overlap.
///
/// **Wired into the app — via `FirestoreBookmarkRepository`, not directly.**
/// `repository_providers.dart`'s `firestoreBookmarkRepositoryProvider`
/// constructs one of these inline for every bookmark resolution and passes
/// it to `FirestoreBookmarkRepository`, which calls [getCustomOrderRefs] on
/// it from `_getNextItemId`/`_getFirstItemId` (see that class's "Custom
/// learning order is honoured" doc section) — so that method already runs
/// in production on every bookmark advance. No feature reads [getOrder]/
/// [saveOrder]/[resetToDefault] (the write-side / full-list surface) yet.
/// The existing Drift-backed `LearningOrderRepositoryImpl`
/// (`lib/features/tracks/whole_curriculum_order/`) is untouched and still
/// serves the reorder screen and every other learning-order caller.
///
/// **No interface** — same reasoning as the reference repositories: the
/// Drift implementation is being deleted outright, not kept alongside this
/// one.
///
/// ## Doc-id and query shape
///
/// [_doc] resolves `DocIds.learningOrderDocId({'curriculum_id': …,
/// 'sefaria_ref': …})`. `DocIds.learningOrderDocId` now percent-encodes
/// each component via `encodeKeyComponent` — see that formula's own doc
/// comment — which means a native write through this class INTENTIONALLY
/// no longer lands on the same document as the live (not-yet-rewired)
/// gateway's raw, unencoded `pushLearningOrder` output for a `sefariaRef`
/// containing a literal `_`; every other `sefariaRef` still lands on the
/// same document either way, since percent-encoding is a no-op for the
/// unreserved character set. This closes what used to be a real production
/// collision surface (a `sefariaRef` containing `_` could collide with a
/// differently-split curriculum/ref pair) rather than merely documenting it
/// — acceptable because the app is greenfield with no back-compat
/// requirement (`docs/firestore-rewrite-map.md`).
///
/// [_queryForCurriculum] filters `curriculum_id` (equality) and orders by
/// `user_sort_order` (a different field) — like
/// `FirestoreStageDefinitionRepository`, this needs a composite index
/// (`curriculum_id` ASC + `user_sort_order` ASC on `learning_order`) that
/// this repository does NOT add to `firestore.indexes.json` (shared file,
/// out of scope for this change) — see the delivery report for the exact
/// JSON. Unlike `FirestoreGoalRepository`'s `target_date`, `user_sort_order`
/// is never absent from a row that exists, so this is a genuine composite-
/// index need, not the "nullable orderBy field drops documents" trap.
///
/// ## Content-item enrichment, not a plain codec
///
/// Unlike `StageDefinition`/`GoalEntity`, `LearningOrderItem` is not a
/// self-contained persisted row — `displayNameHe`/`displayNameEn` are never
/// stored (not in Drift, not in Firestore; `firestore.rules`' `.hasOnly()`
/// list above has no such fields). They are always injected from the
/// caller-supplied content tree, exactly like
/// `LearningOrderRepositoryImpl.getOrder`/`TrackLearningOrderRepositoryImpl
/// ._getOrderedItems`. So [getOrder]/[watchOrder] keep that same shape —
/// `List<ContentItem> allItems` in, enriched `LearningOrderItem`s out — and
/// there is no `toFirestore()`/`fromFirestore()` pair on `LearningOrderItem`
/// itself: the raw Firestore row (`sefariaRef`, `userSortOrder`,
/// `updatedAt`) is decoded into a private `_RawOrderRow` record and merged
/// against the content index here, mirroring how a Drift-generated row is
/// internal plumbing rather than the public domain type.
///
/// ## Trimmed from the Drift-era `LearningOrderRepository` interface — not
/// reimplemented
///
/// - **`saveOrder`'s `isChildRestricted` parameter / `ParentControlException`
///   do not exist on this class.** That guard is a domain/UI-layer parent-
///   lock policy, not a Firestore data-shape concern — nothing about it
///   depends on how the write reaches Firestore. Whoever rewires a feature
///   onto this repository should check the lock before calling [saveOrder],
///   the same way `FirestoreGoalRepository`'s callers are expected to
///   resolve `curriculumId`/`allItems` before calling in.
/// - **[repairStaleOrderVersion] does not exist on this class.** Its whole
///   job is managing the Drift-only `learningOrderVersion` staleness marker
///   (`LearningOrder.learningOrderVersion`) — a field that has no Firestore
///   counterpart at all (absent from the rules' `.hasOnly()` list above), and
///   its actual side effect (`TrackDao.stampReorderAt`, a local `tracks`-
///   table write) is local Drift bookkeeping unrelated to this collection.
///   There is nothing for a Firestore repository to own here.
/// - **No track-scoped methods** (`getSedarimOrder`/`getMasechtosOrder`/
///   `saveSedarimOrder`/`saveMasechtosOrder`/`TrackLearningOrderRepository
///   .resetToDefault`) — see "The collision finding" above.
///
/// ## [resetToDefault] — real delete, not a fixed-slot overwrite (T-33)
///
/// Unlike `stage_definitions` (`FirestoreStageDefinitionRepository
/// .resetToDefaults`, which overwrites 3 known `stage_order` slots because a
/// curriculum's custom order can touch an arbitrary, caller-chosen subset of
/// that curriculum's drag-level items, with no fixed universe to overwrite in
/// place), [resetToDefault] genuinely deletes: it queries every
/// `learning_order` document for the curriculum and batch-deletes them, so a
/// subsequent [getOrder]/[watchOrder] read falls back to natural content
/// order because no documents remain to override it. This was previously
/// unbuildable — `firestore.rules` denied `delete` on `learning_order`
/// unconditionally (`allow delete: if false`) — until T-33's rules change
/// (`allow delete: if isOwner(uid)`, matching the `goals` collection's
/// precedent: `create`/`update` were already owner-writable, so forbidding
/// removal protected nothing).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/firestore/write_ack.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

/// A decoded `learning_order` document, before content-item enrichment.
/// Internal plumbing only — never exposed outside this file; see the class
/// doc comment's "Content-item enrichment, not a plain codec" section.
typedef _RawOrderRow = ({String sefariaRef, int userSortOrder});

/// Firestore-backed whole-curriculum learning-order repository:
/// `users/{uid}/learner_profiles/{profileId}/learning_order/
/// {curriculumId}_{sefariaRef}` (`docs/firestore-rewrite-map.md`,
/// `firestore.rules` `match /learning_order/{orderId}`). See the class doc
/// comment for the collision finding, the doc-id/query shape, and exactly
/// what is trimmed or flagged rather than silently reimplemented.
class FirestoreLearningOrderRepository {
  FirestoreLearningOrderRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    AppLogger? logger,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _logger = logger ?? AppLogger.instance;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final AppLogger _logger;

  CollectionReference<Map<String, dynamic>> get _orders => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('learning_order');

  DocumentReference<Map<String, dynamic>> _doc(
    CurriculumId curriculumId,
    String sefariaRef,
  ) => _orders.doc(
    DocIds.learningOrderDocId({
      'curriculum_id': curriculumId.storageKey,
      'sefaria_ref': sefariaRef,
    }),
  );

  /// The composite-index-requiring query behind [getOrder] and [watchOrder]
  /// — see the class doc comment's "Doc-id and query shape" section.
  Query<Map<String, dynamic>> _queryForCurriculum(CurriculumId curriculumId) =>
      _orders
          .where('curriculum_id', isEqualTo: curriculumId.storageKey)
          .orderBy('user_sort_order');

  /// Decodes one `learning_order` document. Accepts the legacy `ref` alias
  /// for `sefaria_ref` — mirrors `DocIds.learningOrderDocId`'s own
  /// `sefaria_ref ?? ref` fallback exactly, so a document this repository
  /// can resolve a doc-id for can also always be decoded.
  _RawOrderRow _decodeRawRow(Map<String, dynamic> data) {
    final ref =
        data['sefaria_ref']?.toString() ?? data['ref']?.toString() ?? '';
    if (ref.isEmpty) {
      throw FormatException(
        'learning_order document missing sefaria_ref/ref: $data',
      );
    }
    final userSortOrder = FirestoreCodec.parseInt(data['user_sort_order']);
    if (userSortOrder == null) {
      throw FormatException(
        'learning_order document missing user_sort_order: $data',
      );
    }
    return (sefariaRef: ref, userSortOrder: userSortOrder);
  }

  /// Decodes every document in [docs], skipping (and logging) any single
  /// document whose decode fails rather than letting one malformed row
  /// fail the WHOLE read — same "one bad document should not blank the
  /// list" treatment as `FirestoreStageDefinitionRepository._decodeAll` /
  /// `FirestoreGoalRepository._decodeAll`.
  List<_RawOrderRow> _decodeAllRows(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <_RawOrderRow>[];
    for (final doc in docs) {
      try {
        results.add(_decodeRawRow(doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_learning_order_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Returns a map from `sefariaRef` → (displayNameHe, displayNameEn,
  /// sortOrder) for all drag-level (level2, non-leaf) items of a
  /// curriculum — mirrors `LearningOrderRepositoryImpl._buildRefIndex`
  /// exactly (same level filter, same fallback semantics).
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

  /// Merges decoded [rows] against the content [index], falling back to
  /// natural content order when [rows] is empty — mirrors
  /// `LearningOrderRepositoryImpl.getOrder`'s two-branch behavior exactly.
  /// [rows] is expected pre-sorted by `user_sort_order` (the Firestore
  /// query in [_queryForCurriculum] already orders server-side).
  List<LearningOrderItem> _mergeWithContent(
    List<_RawOrderRow> rows,
    Map<String, ({String he, String en, int sortOrder})> index,
  ) {
    if (rows.isNotEmpty) {
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

  /// Returns the ordered drag-level items for [curriculumId]. Returns the
  /// custom order if any `learning_order` documents exist; otherwise falls
  /// back to [ContentItem.sortOrder] (natural Sefaria order). [allItems] is
  /// the full flat content tree for [curriculumId] — callers resolve it
  /// before calling in, same as `LearningOrderRepositoryImpl.getOrder`
  /// (AUD-tracks-15/SM-8: this repository never talks to a content
  /// repository directly).
  Future<List<LearningOrderItem>> getOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    final rows = _decodeAllRows(snapshot.docs);
    return _mergeWithContent(rows, _buildRefIndex(allItems));
  }

  /// The raw saved custom order for [curriculumId]: every `learning_order`
  /// document's `sefaria_ref`, ordered by `user_sort_order` (server-side).
  ///
  /// An EMPTY list means "no custom order has ever been saved for this
  /// curriculum" — never a synthesized natural order. This is the ONE method
  /// on this class whose emptiness is a truthful "is there a custom order?"
  /// signal: [getOrder]/[watchOrder] deliberately fall back to natural
  /// content order and therefore return a NON-EMPTY list even with zero
  /// stored rows (see [_mergeWithContent]). Callers that must distinguish
  /// "custom order exists" from "no custom order" — e.g. the bookmark
  /// repository's next-item resolution, which mirrors the Drift DAO's raw
  /// `getLearningOrderByCurriculum` — use this, not [getOrder]. (A caller
  /// that does use [getOrder] must gate on
  /// `order.isNotEmpty && order.first.isCustomOrdered`, never on emptiness.)
  ///
  /// No content tree is needed: this returns refs only, so it costs one
  /// Firestore read and does not force a full-curriculum content fetch.
  Future<List<String>> getCustomOrderRefs(CurriculumId curriculumId) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    return _decodeAllRows(snapshot.docs).map((r) => r.sefariaRef).toList();
  }

  /// Live updates for [curriculumId]'s ordered item list, merged against
  /// [allItems] on every emission. Resubscribes with bounded exponential
  /// backoff if the underlying listener errors (`resilientQueryStream`) —
  /// see `FirestoreStageDefinitionRepository`'s class doc comment for how a
  /// per-document decode failure is handled.
  Stream<List<LearningOrderItem>> watchOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) {
    final index = _buildRefIndex(allItems);
    return resilientQueryStream<_RawOrderRow>(
      openStream: () => _queryForCurriculum(curriculumId).snapshots(),
      decode: (doc) => _decodeRawRow(doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_learning_order_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey},
      ),
    ).map((rows) => _mergeWithContent(rows, index));
  }

  /// Saves a new custom order for [curriculumId]. Writes one document per
  /// item with `user_sort_order` = index in [items] — mirrors
  /// `LearningOrderRepositoryImpl.saveOrder` exactly, including using the
  /// LIST POSITION rather than each item's own `userSortOrder` field as the
  /// value written (the incoming list order IS the new order). Does not
  /// enforce a parent-control lock — see the class doc comment's "Trimmed"
  /// section for why that check belongs to the caller.
  Future<void> saveOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  ) async {
    final updatedAt = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final batch = _firestore.batch();
    for (var i = 0; i < items.length; i++) {
      batch.set(_doc(curriculumId, items[i].sefariaRef), {
        'curriculum_id': curriculumId.storageKey,
        'sefaria_ref': items[i].sefariaRef,
        'user_sort_order': i,
        'updated_at': FirestoreCodec.encodeDateTime(updatedAt),
      }, SetOptions(merge: true));
    }
    await batch.commit().orQueuedOffline;
  }

  /// Resets [curriculumId]'s custom order to natural content order by
  /// deleting every `learning_order` document for [curriculumId] — mirrors
  /// `LearningOrderRepositoryImpl.resetToDefault`'s Drift DELETE exactly
  /// (delete every row for the curriculum so a subsequent read falls back to
  /// natural content order, since [getOrder]/[watchOrder] treat an empty
  /// result set as "no custom order"). See the class doc comment's "Kept,
  /// still flagged" section for why this was previously unbuildable
  /// (`firestore.rules` denied owner delete on `learning_order`) and T-33 for
  /// the rules change that closed the gap (`allow delete: if isOwner(uid)`,
  /// matching the `goals` collection's precedent).
  Future<void> resetToDefault(CurriculumId curriculumId) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    if (snapshot.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit().orQueuedOffline;
  }
}
