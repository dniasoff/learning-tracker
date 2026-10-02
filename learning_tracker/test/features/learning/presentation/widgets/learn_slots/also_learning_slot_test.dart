// DNI-500 T4 — the also-learning slot renders the sub-track section with
// its top spacing, and nothing at all when there is no sub-track.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/learning/presentation/widgets/learn_slots/also_learning_slot.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';

import '../../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../../helpers/pump_app.dart';

void main() {
  testWidgets('wraps AlsoLearningSection; zero size when absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          ...learnerStateOverrides(scope: null),
          homeSubTracksProvider.overrideWith((ref) => const AsyncData([])),
        ],
        child: const Scaffold(body: Column(children: [AlsoLearningSlot()])),
      ),
    );
    await tester.pumpAndSettle();
    final section = tester.widget<AlsoLearningSection>(
      find.byType(AlsoLearningSection),
    );
    expect(section.topSpacing, AlsoLearningSlot.topSpacing);
    expect(tester.getSize(find.byType(AlsoLearningSlot)).height, 0);
  });
}
