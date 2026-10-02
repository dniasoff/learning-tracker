// Mirror test for `lib/domain/learner_state/default_points.dart`
// (AD-50 default stage ladder; DNI-469 offline points fallback).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/repositories/firestore_point_config_repository.dart';
import 'package:learning_tracker/domain/learner_state/default_points.dart';

void main() {
  test('the ladder is Learn 10, Chazara 1 5, Chazara 2 3, else 1', () {
    expect(
      [for (var s = 0; s <= 5; s++) defaultStagePoints(s)],
      [1, 10, 5, 3, 1, 1],
    );
  });

  test('the data layer resolves the same ladder', () {
    for (var s = 0; s <= 6; s++) {
      expect(defaultPointsForStage(s), defaultStagePoints(s));
    }
  });
}
