/// DNI-469 AC-2: the AD-50 amount `point_configs[curriculum, stage ??
/// firstStageOrder]`, else the default stage ladder.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_points_amount_reader.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

import '../../helpers/learner_state_fixtures.dart';

void main() {
  final scope = LearnerScope(ownerUid: 'owner-uid', profileId: profileUlid);
  const profile = 'users/owner-uid/learner_profiles/$profileUlid';
  late FakeFirebaseFirestore firestore;
  late FirestorePointsAmountReader reader;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    reader = FirestorePointsAmountReader(firestore: firestore);
  });

  Future<void> stage(int order, {bool ended = false}) => firestore
      .doc('$profile/stage_definitions/mishnayos_$order')
      .set({
        'curriculum_id': 'mishnayos',
        'stage_order': order,
        if (ended) 'ended_at': DateTime.utc(2026),
      });

  Future<void> config(int order, int points) => firestore
      .doc('$profile/point_configs/mishnayos_$order')
      .set({
        'curriculum_id': 'mishnayos',
        'stage_order': order,
        'points': points,
      });

  test('no stages and no override: first stage 1 → the ladder (10)', () async {
    expect(await reader.pointsAmount(scope, 'mishnayos', null), 10);
    expect(await reader.pointsAmount(scope, 'mishnayos', 2), 5);
    expect(await reader.pointsAmount(scope, 'mishnayos', 3), 3);
  });

  test('stage ?? the lowest live stage order, then its override', () async {
    await stage(1, ended: true);
    await stage(2);
    await stage(3);
    await config(2, 7);
    expect(await reader.pointsAmount(scope, 'mishnayos', null), 7);
    expect(await reader.pointsAmount(scope, 'mishnayos', 3), 3);
    await config(3, 42);
    expect(await reader.pointsAmount(scope, 'mishnayos', 3), 42);
  });

  test('another curriculum\'s override never applies', () async {
    await firestore.doc('$profile/point_configs/other_1').set({
      'curriculum_id': 'other',
      'stage_order': 1,
      'points': 99,
    });
    expect(await reader.pointsAmount(scope, 'mishnayos', 1), 10);
  });
}
