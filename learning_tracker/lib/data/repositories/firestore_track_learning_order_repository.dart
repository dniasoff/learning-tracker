/// Firestore implementation for the main-track learning order —
/// `users/{uid}/learner_profiles/{profileId}/track_learning_order/
/// {curriculumId}_{level}_{ref}` (`DocIds.trackLearningOrderDocId`), the
/// AD-38 governed entity `mainTrackOrder` (AD-33; R13: the retired
/// `learning_order` collection is merged into this one).
///
/// Each doc orders ONE ContentIndex node among its siblings: `level` (the
/// ContentIndex level name, e.g. `seder` / `masechta`), `ref` (its
/// sefariaRef), `user_sort_order`, the immutable `curriculum_id`, plus the
/// governed `last_change_id` / `ended_at`.
///
/// ## Reads
///
/// * [getSedarimOrder] / [getMasechtosOrder] (and their `watch*` twins)
///   feed the track order screen: the live docs, sorted by
///   `user_sort_order`, merged against the content tree for display
///   (masechtos grouped by the saved seder priority,
///   [MasechtaOrderingPolicy]).
/// * [orderedLeafRefs] is the planner's current-position read: the curriculum's
///   leaves in [orderedLeaves] order (AD-33, the only order function), or
///   an empty list when no live order doc exists (natural order).
///
/// Ended docs are skipped everywhere.
///
/// ## Writes — one logged `mainTrackOrder` change
///
/// A reorder ([saveSedarimOrder] / [saveMasechtosOrder]) and "reset to
/// default" ([resetToDefault], which sets `ended_at` on every live order
/// doc of the curriculum) are each ONE governed action handed to
/// `LearningCommands.applyGovernedChange` through the injected
/// [OwnerGovernedWriter] (Story 1.14, DNI-476): field-level merges with
/// `last_change_id` and one co-written `change_log` entry. Only the docs
/// whose value changes are part of the entity, so a small move stays an
/// offline-capable owner batch; an entity over the AD-54 budget
/// (10 docs) goes whole through the online-only `writeWithChangeLog` path
/// (Story 1.8) and is refused offline with nothing written. This class
/// never writes or deletes a document itself.
///
/// `curriculum_tracks.last_reorder_at` is no longer stamped: the AD-35
/// reorder-amnesty instant is the `mainTrackOrder` change-log entry.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/resilient_doc_stream.dart';
import 'package:learning_tracker/data/repositories/learner_state_firestore_values.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/governed_change.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/ordered_leaves.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_intents.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';
import 'package:learning_tracker/features/tracks/track_order/domain/services/masechta_ordering_policy.dart';
import 'package:learning_tracker/features/tracks/whole_curriculum_order/domain/models/learning_order_item.dart';

/// A live order doc, decoded for display: its node ref and sort order.
typedef _RawOrderRow = ({String ref, int userSortOrder});

/// A ref → (displayNameHe, displayNameEn, sortOrder) index.
typedef _RefIndex = Map<String, ({String he, String en, int sortOrder})>;

/// Firestore-backed main-track order repository (see the library doc
/// comment).
class FirestoreTrackLearningOrderRepository {
  FirestoreTrackLearningOrderRepository({
    required FirebaseFirestore firestore,
    required String uid,
    required String profileId,
    OwnerGovernedWriter? writer,
    AppLogger? logger,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _uid = uid,
       _profileId = profileId,
       _writer = writer,
       _logger = logger ?? AppLogger.instance,
       _clock = clock ?? DateTimeFactory.nowUtc;

  final FirebaseFirestore _firestore;
  final String _uid;
  final String _profileId;
  final OwnerGovernedWriter? _writer;
  final AppLogger _logger;
  final DateTime Function() _clock;

  /// The `list` cap the rules enforce on this collection (SR-4).
  static const _listLimit = 500;

  CollectionReference<Map<String, dynamic>> get _orders => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection(MainTrackOrderEntry.collection);

  /// Every order doc of [curriculumId] (live and ended). Equality-only, so
  /// no composite index; sorted client-side.
  Query<Map<String, dynamic>> _queryForCurriculum(CurriculumId curriculumId) =>
      _orders
          .where(GovernedKeys.curriculumId, isEqualTo: curriculumId.storageKey)
          .limit(_listLimit);

  /// The ContentIndex level name of hierarchy [depth] for [curriculumId]
  /// (the corpus adapter's [contentLevelName]).
  static String levelName(CurriculumId curriculumId, int depth) =>
      contentLevelName(CurriculumLabels.labelsEn(curriculumId), depth);

  static String _docId(CurriculumId curriculumId, String level, String ref) =>
      DocIds.trackLearningOrderDocId({
        'curriculum_id': curriculumId.storageKey,
        'level': level,
        'ref': ref,
      });

  static bool _isLive(Map<String, dynamic> data) =>
      data[GovernedKeys.endedAt] == null;

  /// Decodes one live order doc for display, or null for an ended one.
  _RawOrderRow? _decodeRawRow(Map<String, dynamic> data) {
    if (!_isLive(data)) return null;
    final ref = data[MainTrackOrderEntry.kRef];
    final userSortOrder = FirestoreCodec.parseInt(
      data[MainTrackOrderEntry.kUserSortOrder],
    );
    if (ref is! String || ref.isEmpty || userSortOrder == null) {
      throw FormatException(
        'track_learning_order doc missing ref/order: $data',
      );
    }
    return (ref: ref, userSortOrder: userSortOrder);
  }

  /// The live rows of [docs], sorted by `user_sort_order`; a malformed doc
  /// is skipped (and logged), never the whole list.
  List<_RawOrderRow> _decodeAllRows(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <_RawOrderRow>[];
    for (final doc in docs) {
      try {
        final row = _decodeRawRow(doc.data());
        if (row != null) results.add(row);
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_track_learning_order_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results..sort(_bySortOrder);
  }

  static int _bySortOrder(_RawOrderRow a, _RawOrderRow b) =>
      a.userSortOrder.compareTo(b.userSortOrder);

  /// The live order docs of [curriculumId] as AD-52 [MainTrackOrderEntry]s
  /// (the engine's `MainTrackIntent.order` shape); undecodable docs are
  /// skipped (and logged).
  Future<List<MainTrackOrderEntry>> getOrderEntries(
    CurriculumId curriculumId,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    final entries = <MainTrackOrderEntry>[];
    for (final doc in snapshot.docs) {
      if (!_isLive(doc.data())) continue;
      try {
        entries.add(
          MainTrackOrderEntry.fromStorage(doc.id, fromFirestoreMap(doc.data())),
        );
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_track_learning_order_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return entries;
  }

  /// The leaves of [curriculumId] in the learner's main-track order: the
  /// AD-33 [orderedLeaves] of the curriculum's ContentIndex corpus (built
  /// from [content], fetched only when needed) and its live order docs.
  /// Empty when the curriculum has no live order doc (natural order).
  Future<List<String>> orderedLeafRefs(
    CurriculumId curriculumId, {
    required Future<List<ContentItem>> Function() content,
  }) async {
    final entries = await getOrderEntries(curriculumId);
    if (entries.isEmpty) return const [];
    final corpus = contentIndexCorpus(
      curriculumId: curriculumId.storageKey,
      items: await content(),
      levelLabels: CurriculumLabels.labelsEn(curriculumId),
    );
    return orderedLeaves(corpus, entries);
  }

  /// `sefariaRef` → display info for the sedarim (depth-1 containers).
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

  /// Merges [rows] (sorted by `user_sort_order`) against [index]: the rows
  /// naming an indexed node, or natural content order when none does.
  List<LearningOrderItem> _mergeWithIndex(
    List<_RawOrderRow> rows,
    _RefIndex index,
  ) {
    final matchingRows = rows.where((r) => index.containsKey(r.ref));
    if (matchingRows.isNotEmpty) {
      return matchingRows.map((r) {
        final info = index[r.ref]!;
        return LearningOrderItem(
          sefariaRef: r.ref,
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

  /// The masechtos index, ordered by the saved seder priority derived
  /// from [rows] ([MasechtaOrderingPolicy]).
  _RefIndex _buildMasechtosIndexFromRows(
    List<_RawOrderRow> rows,
    List<ContentItem> allItems,
    _RefIndex sedarimIndex,
  ) {
    final savedSederOrder = rows
        .where((r) => sedarimIndex.containsKey(r.ref))
        .map((r) => r.ref)
        .toList();
    return const MasechtaOrderingPolicy().buildIndex(
      allItems: allItems,
      sedarimIndex: sedarimIndex,
      savedSederOrder: savedSederOrder,
    );
  }

  /// The ordered sedarim (depth-1 containers) of [curriculumId]: the saved
  /// order when any live doc names a seder, else natural content order.
  Future<List<LearningOrderItem>> getSedarimOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    final rows = _decodeAllRows(snapshot.docs);
    return _mergeWithIndex(rows, _buildSedarimIndex(allItems));
  }

  /// The ordered masechtos (depth-2 containers) of [curriculumId].
  Future<List<LearningOrderItem>> getMasechtosOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    final rows = _decodeAllRows(snapshot.docs);
    final sedarimIndex = _buildSedarimIndex(allItems);
    return _mergeWithIndex(
      rows,
      _buildMasechtosIndexFromRows(rows, allItems, sedarimIndex),
    );
  }

  Stream<List<_RawOrderRow>> _watchRows(
    CurriculumId curriculumId,
    String kind,
  ) => resilientQueryStream<_RawOrderRow?>(
    openStream: () => _queryForCurriculum(curriculumId).snapshots(),
    decode: (doc) => _decodeRawRow(doc.data()),
    onError: (error, stackTrace) => _logger.warning(
      event: 'firestore_track_learning_order_watch_error',
      exception: error,
      stackTrace: stackTrace,
      fields: {'curriculum_id': curriculumId.storageKey, 'kind': kind},
    ),
  ).map((rows) => rows.whereType<_RawOrderRow>().toList()..sort(_bySortOrder));

  /// Live updates of [getSedarimOrder].
  Stream<List<LearningOrderItem>> watchSedarimOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) {
    final index = _buildSedarimIndex(allItems);
    return _watchRows(
      curriculumId,
      'sedarim',
    ).map((rows) => _mergeWithIndex(rows, index));
  }

  /// Live updates of [getMasechtosOrder]; the masechtos index is re-derived
  /// from every emission (the saved seder order may change).
  Stream<List<LearningOrderItem>> watchMasechtosOrder(
    CurriculumId curriculumId,
    List<ContentItem> allItems,
  ) {
    final sedarimIndex = _buildSedarimIndex(allItems);
    return _watchRows(curriculumId, 'masechtos').map(
      (rows) => _mergeWithIndex(
        rows,
        _buildMasechtosIndexFromRows(rows, allItems, sedarimIndex),
      ),
    );
  }

  /// Saves [items] as [curriculumId]'s custom sedarim order (depth 1).
  Future<void> saveSedarimOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  ) => _saveOrder(curriculumId, levelName(curriculumId, 1), items);

  /// Saves [items] as [curriculumId]'s custom masechtos order (depth 2).
  Future<void> saveMasechtosOrder(
    CurriculumId curriculumId,
    List<LearningOrderItem> items,
  ) => _saveOrder(curriculumId, levelName(curriculumId, 2), items);

  /// One logged `mainTrackOrder` change: `user_sort_order` = the item's
  /// position in [items] on each node of [level], written only where it
  /// differs from the live doc (an ended doc is revived).
  Future<void> _saveOrder(
    CurriculumId curriculumId,
    String level,
    List<LearningOrderItem> items,
  ) async {
    final current = await _currentDocs(curriculumId);
    final docs = <String, Map<String, Object?>>{};
    for (var i = 0; i < items.length; i++) {
      final ref = items[i].sefariaRef;
      final id = _docId(curriculumId, level, ref);
      final existing = current[id];
      if (existing != null &&
          _isLive(existing) &&
          FirestoreCodec.parseInt(
                existing[MainTrackOrderEntry.kUserSortOrder],
              ) ==
              i) {
        continue;
      }
      docs[id] = {
        MainTrackOrderEntry.kLevel: level,
        MainTrackOrderEntry.kRef: ref,
        MainTrackOrderEntry.kUserSortOrder: i,
        GovernedKeys.endedAt: null,
      };
    }
    if (docs.isEmpty) return;
    await _apply(
      OwnerGovernedIntents.mainTrackDocs(
        entity: GovernedEntity.mainTrackOrder,
        curriculumId: curriculumId.storageKey,
        docs: docs,
      ),
    );
  }

  /// Resets [curriculumId]'s custom order (sedarim AND masechtos) to
  /// natural content order: ONE logged `mainTrackOrder` change setting
  /// `ended_at` on every live order doc of the curriculum. Other curricula
  /// are untouched. A no-op when there is no live doc.
  Future<void> resetToDefault(CurriculumId curriculumId) async {
    final current = await _currentDocs(curriculumId);
    final live = [
      for (final MapEntry(:key, :value) in current.entries)
        if (_isLive(value)) key,
    ];
    if (live.isEmpty) return;
    await _apply(
      OwnerGovernedIntents.endMainTrackDocs(
        entity: GovernedEntity.mainTrackOrder,
        curriculumId: curriculumId.storageKey,
        docIds: live,
        at: _clock(),
      ),
    );
  }

  Future<Map<String, Map<String, dynamic>>> _currentDocs(
    CurriculumId curriculumId,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    return {for (final doc in snapshot.docs) doc.id: doc.data()};
  }

  Future<void> _apply(GovernedEntityChange change) async {
    final writer = _writer;
    if (writer == null) throw const GovernedWriterNotReadyException();
    await applyOwnerAction(writer, GovernedAction([change]));
  }
}
