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

/// Default point ladder applied when a `(curriculumId, stageOrder)` has no
/// override document — mirrors `FirestoreCompletionPointsAwarder
/// .pointsForStage`'s hardcoded fallback exactly (Learn=10, Chazara1=5,
/// Chazara2=3, else 1). **Nothing is ever seeded from this**: a missing
/// document means "no override, use the ladder" — a seeded row would make
/// this branch permanently dead and silently pin a stale default if the
/// ladder ever changes.
int defaultPointsForStage(int stageOrder) => switch (stageOrder) {
  1 => 10,
  2 => 5,
  3 => 3,
  _ => 1,
};

/// Inclusive bounds on a stored override's `points` value — mirrored by
/// `firestore.rules`' `point_configs` block and `completions.points`' own
/// `<= 100` cap (`CompletionOrchestrator.markComplete` stamps
/// `calculatePoints`'s result straight onto the completion document, so an
/// override above this ceiling would make every completion write for that
/// stage `PERMISSION_DENIED`).
const kMinPointConfigPoints = 1;
const kMaxPointConfigPoints = 100;

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
      _configs
          .where('curriculum_id', isEqualTo: curriculumId.storageKey)
          .orderBy('stage_order')
          .limit(500);

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
  /// `null` if no document exists — callers fall back to their own default
  /// ladder (D-E: configuration-shaped, an absent document is a legitimate
  /// "no override, use the default" signal).
  ///
  /// A document that DOES exist but fails to decode PROPAGATES instead of
  /// returning `null` — unlike [getConfigsForCurriculum]'s list read, which
  /// skips a malformed document among many. A single-doc read has no other
  /// document to fall back to, so swallowing the decode error here would be
  /// indistinguishable from "no override" and silently under-credit the
  /// learner (D-E: this is Branch C, not Branch B).
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
    return pointConfigFromFirestore(data).points;
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

  /// Upserts a single override. Asserts [kMinPointConfigPoints]..
  /// [kMaxPointConfigPoints] client-side so an out-of-range value fails as
  /// a Dart [ArgumentError] at the call site, not an opaque
  /// `PERMISSION_DENIED` from `firestore.rules`' own copy of this bound.
  Future<void> upsertConfig({
    required CurriculumId curriculumId,
    required int stageOrder,
    required int points,
  }) async {
    if (points < kMinPointConfigPoints || points > kMaxPointConfigPoints) {
      throw ArgumentError.value(
        points,
        'points',
        'must be $kMinPointConfigPoints..$kMaxPointConfigPoints',
      );
    }
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

  /// Removes a `(curriculumId, stageOrder)` override so
  /// [defaultPointsForStage]'s ladder resumes governing that stage — the
  /// only honest "restore the default" operation (overwriting the doc with
  /// the ladder's own value would instead permanently pin it, no longer
  /// tracking the ladder if it ever changes).
  Future<void> clearOverride({
    required CurriculumId curriculumId,
    required int stageOrder,
  }) async {
    await _doc(
      curriculumId: curriculumId,
      stageOrder: stageOrder,
    ).delete().orQueuedOffline;
  }
}
