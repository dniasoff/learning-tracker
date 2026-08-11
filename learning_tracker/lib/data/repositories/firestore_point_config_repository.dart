/// Firestore implementation for per-curriculum-per-stage point-value
/// overrides (Phase 3 task #4) — structurally the third application of the
/// `FirestoreStageDefinitionRepository` pattern (composite `curriculum_id`
/// + `stage_order` key, same query/decode/batch-write shape); read that
/// class's doc comment first, this one only calls out what differs.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/write_ack.dart';
import 'package:learning_tracker/features/gamification/domain/models/point_config.dart';

/// Default point ladder seeded when a curriculum has no overrides yet —
/// mirrors `FirestoreCompletionPointsAwarder.pointsForStage`'s hardcoded
/// fallback exactly (Learn=10, Chazara1=5, Chazara2=3, else 1), so seeding
/// defaults never changes what a learner already earns.
int defaultPointsForStage(int stageOrder) => switch (stageOrder) {
  1 => 10,
  2 => 5,
  3 => 3,
  _ => 1,
};

/// Firestore-backed point-configs repository: `users/{uid}/
/// learner_profiles/{profileId}/point_configs/{curriculumId}_{stageOrder}`
/// (`firestore.rules` `match /point_configs/{configId}`).
class FirestorePointConfigRepository {
  FirestorePointConfigRepository({
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

  CollectionReference<Map<String, dynamic>> get _configs => _firestore
      .collection('users')
      .doc(_uid)
      .collection('learner_profiles')
      .doc(_profileId)
      .collection('point_configs');

  DocumentReference<Map<String, dynamic>> _doc({
    required CurriculumId curriculumId,
    required int stageOrder,
  }) => _configs.doc(
    DocIds.pointConfigDocId({
      'curriculum_id': curriculumId.storageKey,
      'stage_order': stageOrder,
    }),
  );

  Query<Map<String, dynamic>> _queryForCurriculum(CurriculumId curriculumId) =>
      _configs.where('curriculum_id', isEqualTo: curriculumId.storageKey);

  /// Returns every configured override for [curriculumId] (no ordering
  /// guarantee beyond Firestore's default document-id order — callers that
  /// need `stageOrder`-sorted output should sort client-side, same as
  /// every other small in-memory list in this migration).
  Future<List<PointConfigEntity>> getConfigsForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final snapshot = await _queryForCurriculum(curriculumId).get();
    return _decodeAll(snapshot.docs);
  }

  /// The configured point value for one `(curriculumId, stageOrder)`, or
  /// `null` if no override exists — callers fall back to their own default
  /// ladder (D-E: configuration-shaped, an absent override is a legitimate
  /// "use the default" signal, not a not-ready state).
  Future<int?> getPointsForStage({
    required CurriculumId curriculumId,
    required int stageOrder,
  }) async {
    final snapshot = await _doc(
      curriculumId: curriculumId,
      stageOrder: stageOrder,
    ).get();
    final data = snapshot.data();
    if (data == null) return null;
    try {
      return pointConfigFromFirestore(data).points;
    } catch (error, stackTrace) {
      _logger.warning(
        event: 'firestore_point_configs_decode_error',
        exception: error,
        stackTrace: stackTrace,
        fields: {'doc_id': snapshot.id},
      );
      return null;
    }
  }

  List<PointConfigEntity> _decodeAll(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final results = <PointConfigEntity>[];
    for (final doc in docs) {
      try {
        results.add(pointConfigFromFirestore(doc.data()));
      } catch (error, stackTrace) {
        _logger.warning(
          event: 'firestore_point_configs_decode_error',
          exception: error,
          stackTrace: stackTrace,
          fields: {'doc_id': doc.id},
        );
      }
    }
    return results;
  }

  /// Upserts a single override.
  Future<void> upsertConfig({
    required CurriculumId curriculumId,
    required int stageOrder,
    required int points,
  }) async {
    final now = DateTimeFactory.nowUtc();
    final entry = PointConfigEntity(
      curriculumId: curriculumId,
      stageOrder: stageOrder,
      points: points,
    );
    await _doc(curriculumId: curriculumId, stageOrder: stageOrder)
        .set(entry.toFirestore(updatedAt: now))
        .orQueuedOffline;
  }

  /// Seeds default overrides (matching [defaultPointsForStage]) for every
  /// stage in [stageOrders] that has no override yet. Idempotent — a stage
  /// that already has a configured value is left untouched.
  Future<void> ensureDefaultConfigs({
    required CurriculumId curriculumId,
    required List<int> stageOrders,
  }) async {
    final existing = await getConfigsForCurriculum(curriculumId);
    final existingOrders = existing.map((c) => c.stageOrder).toSet();
    final missing = stageOrders.where((o) => !existingOrders.contains(o));
    if (missing.isEmpty) return;

    final now = DateTimeFactory.nowUtc();
    final batch = _firestore.batch();
    for (final stageOrder in missing) {
      final entry = PointConfigEntity(
        curriculumId: curriculumId,
        stageOrder: stageOrder,
        points: defaultPointsForStage(stageOrder),
      );
      batch.set(
        _doc(curriculumId: curriculumId, stageOrder: stageOrder),
        entry.toFirestore(updatedAt: now),
      );
    }
    await batch.commit().orQueuedOffline;
  }
}
