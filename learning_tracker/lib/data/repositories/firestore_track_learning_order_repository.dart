/// Firestore implementation for the per-track (sedarim/masechtos) learning
/// order — the collection `docs/firestore-rewrite-map.md`'s "OPEN" section
/// and `firestore_learning_order_repository.dart`'s class doc comment both
/// flag as missing: `TrackLearningOrder` (Drift) had no Firestore home at
/// all until `track_learning_order` was added to `firestore.rules` and
/// `DocIds.trackLearningOrderDocId`. This class is that missing repository.
///
/// Built to the shape `firestore_learning_order_repository.dart` (the
/// closest sibling — same doc-id family, same content-enrichment pattern)
/// establishes. This doc comment only calls out what is DIFFERENT here.
///
/// ## Same collision finding, opposite conclusion
///
/// `DocIds.trackLearningOrderDocId` and `DocIds.learningOrderDocId` compute
/// the **identical doc-id STRING** for the same `(curriculumId, sefariaRef)`
/// pair — both formulas are `[encodeKeyComponent(curriculumId),
/// encodeKeyComponent(ref)].join('_')`, byte-for-byte. That is not a bug
/// here: see [DocIds.trackLearningOrderDocId]'s doc comment — it is the
/// COLLECTION PATH (`track_learning_order` vs. `learning_order`), not the
/// doc-id formula, that disambiguates the two orderings. This repository
/// therefore points at its own collection
/// (`.../learner_profiles/{profileId}/track_learning_order`), never
/// `learning_order`. The "doc-id collision" test group in this class's test
/// file proves the two collections coexist for an identical
/// `(curriculumId, sefariaRef)` pair without clobbering each other —
/// mirroring, and resolving, the RED-DEMO in
/// `firestore_learning_order_repository_test.dart`.
///
/// ## `curriculumId` replaces the Drift `int trackId`
///
/// `TrackLearningOrderRepositoryImpl` (Drift) is keyed by the per-device
/// autoincrement `trackId`. AD-25 retired that as a key component for this
/// migration — `curriculum_id` is the sole canonical stable track key (one
/// track per curriculum) — so every method here takes a [CurriculumId]
/// instead. There is no `_resolveProfileId` step either:
/// `TrackLearningOrderRepositoryImpl._resolveProfileId` exists only to map
/// a Drift-local `trackId` back to its owning `profileId`; this repository
/// is already constructed scoped to one `profileId` (same pattern as every
/// other repository in this ring), so there is nothing to resolve.
///
/// ## One read instead of two for the masechtos ordering
///
/// `TrackLearningOrderRepositoryImpl._buildMasechtosIndex` and
/// `._getOrderedItems` each issue their own `trackLearningOrderDao.getByTrack`
/// call — two separate DAO reads for one logical
/// [getMasechtosOrder]/[watchMasechtosOrder] answer. A Firestore repository
/// doing the same would risk a torn read (a write landing between the two
/// round trips changes the answer). [getMasechtosOrder] and
/// [watchMasechtosOrder] instead issue exactly one query and derive both the
/// saved-seder-order (fed into [MasechtaOrderingPolicy]) and the final
/// merged list from that single snapshot — [MasechtaOrderingPolicy.buildIndex]
/// is a pure, synchronous function, so nothing about combining the two steps
/// needs a second network round trip.
///
/// ## Reorder-amnesty and reset
///
/// - **No `saveOrder`'s parent-lock guard** — a UI-layer policy concern, not
///   a Firestore data-shape concern; see the sibling's "Trimmed" section.
/// - Every order mutation uses one [WriteBatch] spanning
///   `track_learning_order` and `curriculum_tracks`; the batch also writes
///   `last_reorder_at` through [FirestoreCurriculumTrackRepository].
///   Firestore batches are atomic across these collections, including when
///   the offline-aware commit is queued.
/// - [resetToDefault] uses field tombstones because the rules deny document
///   deletes. Removing `user_sort_order` makes the existing ordered query
///   exclude those rows, so reads fall back to natural content order.
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
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/services/masechta_ordering_policy.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

/// A decoded `track_learning_order` document, before content-item
/// enrichment. Internal plumbing only — never exposed outside this file;
/// same treatment as `firestore_learning_order_repository.dart`'s
/// `_RawOrderRow`. Unlike that sibling, there is no legacy `ref` field
/// alias to accept on read: `track_learning_order` is a brand-new
/// collection with no prior payload shape to stay compatible with (see
/// `DocIds.trackLearningOrderDocId`'s doc comment), and its rules
/// `.hasOnly()` whitelist only ever lists `sefaria_ref`.
typedef _RawOrderRow = ({String sefariaRef, int userSortOrder});

/// A ref → (displayNameHe, displayNameEn, sortOrder) index — the shape both
/// [_buildSedarimIndex] and [MasechtaOrderingPolicy.buildIndex] produce,
/// and [_mergeWithIndex] consumes.
typedef _RefIndex = Map<String, ({String he, String en, int sortOrder})>;

/// Firestore-backed per-track (sedarim/masechtos) learning-order repository:
/// `users/{uid}/learner_profiles/{profileId}/track_learning_order/
/// {curriculumId}_{sefariaRef}` (`docs/firestore-rewrite-map.md`,
/// `firestore.rules` `match /track_learning_order/{orderId}`). See the
/// class doc comment for how this coexists with `learning_order` despite
/// identical doc-id strings, and for what is trimmed or flagged rather than
/// silently reimplemented.
class FirestoreTrackLearningOrderRepository {
  FirestoreTrackLearningOrderRepository({
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
  late final FirestoreCurriculumTrackRepository _curriculumTrackRepository =
      FirestoreCurriculumTrackRepository(
        firestore: _firestore,
        uid: _uid,
        profileId: _profileId,
        logger: _logger,
      );

  CollectionReference<Map<String, dynamic>> get _orders => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('track_learning_order');

  DocumentReference<Map<String, dynamic>> _doc(
    CurriculumId curriculumId,
    String sefariaRef,
  ) => _orders.doc(
    DocIds.trackLearningOrderDocId({
      'curriculum_id': curriculumId.storageKey,
      'sefaria_ref': sefariaRef,
    }),
  );

  /// The composite-index-requiring query behind every read/watch method —
  /// same shape as `FirestoreLearningOrderRepository._queryForCurriculum`.
  /// Returns EVERY row for [curriculumId] regardless of whether it is a
  /// sedarim-level or masechtos-level ref — the two orderings share this
  /// one collection, distinguished only by which `sefariaRef`s the caller's
  /// index recognises (see the class doc comment), never by a stored
  /// discriminator field, so there is no server-side way to filter one
  /// ordering out of the other.
  Query<Map<String, dynamic>> _queryForCurriculum(CurriculumId curriculumId) =>
      _orders
          .where('curriculum_id', isEqualTo: curriculumId.storageKey)
          .orderBy('user_sort_order')
          .limit(500);

  /// Decodes one `track_learning_order` document.
  _RawOrderRow _decodeRawRow(Map<String, dynamic> data) {
    final ref = data['sefaria_ref']?.toString() ?? '';
    if (ref.isEmpty) {
      throw FormatException(
        'track_learning_order document missing sefaria_ref: $data',
      );
    }
    final userSortOrder = FirestoreCodec.parseInt(data['user_sort_order']);
    if (userSortOrder == null) {
      throw FormatException(
        'track_learning_order document missing user_sort_order: $data',
      );
    }
    return (sefariaRef: ref, userSortOrder: userSortOrder);
  }

  /// Decodes every document in [docs], skipping (and logging) any single
  /// document whose decode fails — same "one bad document should not blank
  /// the list" treatment as the sibling repository's `_decodeAllRows`.
  List<_RawOrderRow> _decodeAllRows(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <_RawOrderRow>[];
    for (final doc in docs) {
      try {
        results.add(_decodeRawRow(doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_track_learning_order_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Returns a map from `sefariaRef` → (displayNameHe, displayNameEn,
  /// sortOrder) for all sedarim (level1 containers: `level2 == null`,
  /// non-leaf) of a curriculum — mirrors
  /// `TrackLearningOrderRepositoryImpl._buildSedarimIndex` exactly.
  _RefIndex _buildSedarimIndex(List<ContentItem> allItems) {
    final index = <String, ({String he, String en, int sortOrder})>{};
    for (final item in allItems) {
      if (item.level2 == null && !item.isLeaf) {
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
  /// natural content order when no row in [rows] matches [index] — mirrors
  /// `TrackLearningOrderRepositoryImpl._getOrderedItems`'s two-branch
  /// behavior exactly, including using each row's OWN `userSortOrder`
  /// (already server-ordered by [_queryForCurriculum]) rather than its
  /// position within the filtered subset.
  List<LearningOrderItem> _mergeWithIndex(
    List<_RawOrderRow> rows,
    _RefIndex index,
  ) {
    final matchingRows = rows.where((r) => index.containsKey(r.sefariaRef));
    if (matchingRows.isNotEmpty) {
      return matchingRows.map((r) {
        final info = index[r.sefariaRef]!;
        return LearningOrderItem(
          sefariaRef: r.sefariaRef,
          displayNameHe: info.he,
          displayNameEn: info.en,
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

  /// Derives the masechtos [_RefIndex] from one already-fetched [rows] set
  /// — the saved-seder-order [MasechtaOrderingPolicy] needs is just [rows]
  /// filtered down to sedarim-level refs, in their already-server-sorted
  /// order. See the class doc comment's "One read instead of two" section
  /// for why this is derived from a snapshot already in hand rather than a
  /// second query.
  _RefIndex _buildMasechtosIndexFromRows(
    List<_RawOrderRow> rows,
    List<ContentItem> allItems,
    _RefIndex sedarimIndex,
  ) {
    final savedSederOrder = rows
        .where((r) => sedarimIndex.containsKey(r.sefariaRef))
        .map((r) => r.sefariaRef)
        .toList();
    return const MasechtaOrderingPolicy().buildIndex(
      allItems: allItems,
      sedarimIndex: sedarimIndex,
      savedSederOrder: savedSederOrder,
    );
  }

  /// Returns the ordered sedarim (level1 containers) for [curriculumId].
  /// Returns the custom order if any saved rows match a sedarim ref;
  /// otherwise falls back to [ContentItem.sortOrder] (natural Sefaria
  /// order). [allItems] is the full flat content tree for [curriculumId] —
  /// callers resolve it before calling in, same as
  /// `TrackLearningOrderRepositoryImpl.getSedarimOrder`
  /// (AUD-tracks-15/SM-8: this repository never talks to a content
  /// repository directly).
  Future<List<LearningOrderItem>> getSedarimOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    final rows = _decodeAllRows(snapshot.docs);
    return _mergeWithIndex(rows, _buildSedarimIndex(allItems));
  }

  /// Returns the ordered masechtos (level2 containers) for [curriculumId],
  /// ordered by the saved seder priority first, then canonical sort_order
  /// within a seder — see [MasechtaOrderingPolicy]. [allItems] — see
  /// [getSedarimOrder].
  Future<List<LearningOrderItem>> getMasechtosOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    final rows = _decodeAllRows(snapshot.docs);
    final sedarimIndex = _buildSedarimIndex(allItems);
    final masechtosIndex = _buildMasechtosIndexFromRows(
      rows,
      allItems,
      sedarimIndex,
    );
    return _mergeWithIndex(rows, masechtosIndex);
  }

  /// Live updates for [curriculumId]'s ordered sedarim list, merged against
  /// [allItems] on every emission. Resubscribes with bounded exponential
  /// backoff if the underlying listener errors (`resilientQueryStream`) —
  /// see `FirestoreStageDefinitionRepository`'s class doc comment for how a
  /// per-document decode failure is handled.
  Stream<List<LearningOrderItem>> watchSedarimOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) {
    final index = _buildSedarimIndex(allItems);
    return resilientQueryStream<_RawOrderRow>(
      openStream: () => _queryForCurriculum(curriculumId).snapshots(),
      decode: (doc) => _decodeRawRow(doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_track_learning_order_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey, 'kind': 'sedarim'},
      ),
    ).map((rows) => _mergeWithIndex(rows, index));
  }

  /// Live updates for [curriculumId]'s ordered masechtos list. Unlike
  /// [watchSedarimOrder], the masechtos index is re-derived from EVERY
  /// emitted snapshot (not just once, outside the stream) — the saved seder
  /// order it depends on can itself change between emissions, and
  /// [MasechtaOrderingPolicy.buildIndex] is a pure, synchronous function, so
  /// there is no second query needed to keep it current. [allItems] — see
  /// [getSedarimOrder].
  Stream<List<LearningOrderItem>> watchMasechtosOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) {
    final sedarimIndex = _buildSedarimIndex(allItems);
    return resilientQueryStream<_RawOrderRow>(
      openStream: () => _queryForCurriculum(curriculumId).snapshots(),
      decode: (doc) => _decodeRawRow(doc.data()),
      onError: (error, stackTrace) => _logger.warning(
        event: 'firestore_track_learning_order_watch_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'curriculum_id': curriculumId.storageKey, 'kind': 'masechtos'},
      ),
    ).map((rows) {
      final masechtosIndex = _buildMasechtosIndexFromRows(
        rows,
        allItems,
        sedarimIndex,
      );
      return _mergeWithIndex(rows, masechtosIndex);
    });
  }

  /// Writes one document per item with `user_sort_order` = index in [items]
  /// — the shared save path behind both [saveSedarimOrder] and
  /// [saveMasechtosOrder], mirroring how `TrackLearningOrderRepositoryImpl`
  /// routes both through the identical `trackLearningOrderDao.upsertOrder`
  /// call: the two orderings share one table/collection, distinguished only
  /// by which refs the caller passes in, never by a stored discriminator.
  /// Uses the LIST POSITION rather than each item's own `userSortOrder`
  /// field as the written value (the incoming list order IS the new order)
  /// — same as the sibling's `saveOrder`. Co-writes
  /// `curriculum_tracks.last_reorder_at` in the same atomic batch.
  Future<void> _saveOrder(
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
    _curriculumTrackRepository.addReorderStampToBatch(
      batch,
      curriculumId,
      updatedAt,
    );
    await batch.commit().orQueuedOffline;
  }

  /// Saves a new custom sedarim order for [curriculumId]. See [_saveOrder].
  Future<void> saveSedarimOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  ) => _saveOrder(curriculumId, items);

  /// Saves a new custom masechtos order for [curriculumId]. See
  /// [_saveOrder].
  Future<void> saveMasechtosOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  ) => _saveOrder(curriculumId, items);

  /// Resets [curriculumId]'s custom track order (sedarim AND masechtos) to
  /// natural content order.
  ///
  /// `track_learning_order` denies document deletion, so each matching row is
  /// tombstoned by removing its `user_sort_order` field. The existing query
  /// orders by that field and therefore excludes the tombstoned rows; reads
  /// then take their normal natural-order fallback. The track stamp is added
  /// to the same batch as the tombstones.
  Future<void> resetToDefault(CurriculumId curriculumId) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    if (snapshot.docs.isEmpty) return;

    final updatedAt = DateTimeFactory.nowUtc(); // P5: UTC timestamps
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'user_sort_order': FieldValue.delete(),
        'updated_at': FirestoreCodec.encodeDateTime(updatedAt),
      });
    }
    _curriculumTrackRepository.addReorderStampToBatch(
      batch,
      curriculumId,
      updatedAt,
    );
    await batch.commit().orQueuedOffline;
  }
}
