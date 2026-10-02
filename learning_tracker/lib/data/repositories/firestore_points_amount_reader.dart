/// The AD-50 points amount for an owner capture (DNI-469):
/// `point_configs[curriculum, stage ?? firstStageOrder]`, else the default
/// stage ladder — the same resolution `writeWithChangeLog`'s
/// `resolvePointsAmounts` makes for tutor writes.
///
/// Reads are collection QUERIES, not single-document gets: offline, a
/// query answers from the local cache instead of failing, so capture stays
/// fully offline (`prd-deviations` #14). An uncached curriculum resolves
/// to the default ladder, exactly like an absent override.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:learning_tracker/data/repositories/firestore_point_config_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';

/// Firestore [PointsAmountReader] over the learner's `stage_definitions`
/// and `point_configs`.
final class FirestorePointsAmountReader implements PointsAmountReader {
  /// Creates the reader over an account-scoped [firestore] handle.
  FirestorePointsAmountReader({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profile(LearnerScope scope) =>
      _firestore
          .collection('users')
          .doc(scope.ownerUid)
          .collection('learner_profiles')
          .doc(scope.profileId);

  @override
  Future<int> pointsAmount(
    LearnerScope scope,
    String curriculumId,
    int? stage,
  ) async {
    final profile = _profile(scope);
    final order = stage ?? await _firstStageOrder(profile, curriculumId);
    final configs = await profile
        .collection('point_configs')
        .where('curriculum_id', isEqualTo: curriculumId)
        .get();
    for (final doc in configs.docs) {
      final data = doc.data();
      final points = data['points'];
      if (data['stage_order'] == order && points is int && points >= 1) {
        return points;
      }
    }
    return defaultPointsForStage(order);
  }

  /// The lowest live `stage_order` of [curriculumId], or 1 when none is
  /// configured (as the server resolves it).
  Future<int> _firstStageOrder(
    DocumentReference<Map<String, dynamic>> profile,
    String curriculumId,
  ) async {
    final stages = await profile
        .collection('stage_definitions')
        .where('curriculum_id', isEqualTo: curriculumId)
        .get();
    int? lowest;
    for (final doc in stages.docs) {
      final data = doc.data();
      final order = data['stage_order'];
      final live = data['ended_at'] == null && !data.containsKey('synced_at');
      if (live && order is int && (lowest == null || order < lowest)) {
        lowest = order;
      }
    }
    return lowest ?? 1;
  }
}
