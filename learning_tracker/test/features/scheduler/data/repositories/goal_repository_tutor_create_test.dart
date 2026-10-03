// Story 1.24 (DNI-486) AC-1: a tutor's FIRST goal on a track (Track
// detail "Set goal" with no goal yet) is the governed `tutorUpsertGoal`
// callable after the tutor preflight — never a client write into the
// talmid's tree. A refused preflight writes nothing.

@Tags(['tutor_mode'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_governed_writes.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';

import '../../../../helpers/tutoring/tutor_learning_harness.dart';

void main() {
  late TutorHarness h;
  late ProviderContainer container;

  ProviderContainer tutored(TutorHarness harness) => ProviderContainer(
    overrides: [
      ...tutoredOverrides(selection: harness.selection),
      tutorGovernedWritesProvider.overrideWith((ref) async => harness.governed),
    ],
  );

  tearDown(() {
    container.dispose();
    h.dispose();
  });

  test('a tutor creates a goal through ONE tutorUpsertGoal call carrying the '
      'new goal doc', () async {
    h = TutorHarness();
    container = tutored(h);

    final created = await container
        .read(goalRepositoryProvider)
        .createGoal(
          curriculumId: CurriculumId.mishnayos,
          paceTarget: const PacePeriodTarget(rate: 2, period: 'per_week'),
          description: 'Seder Moed',
          paceGranularity: 'mishna',
        );

    expect(h.invoker.calls.map((c) => c.fn), ['tutorUpsertGoal']);
    final args = h.invoker.calls.single.args;
    expect(args['goalId'], created.firestoreId);
    expect(args['ownerUid'], tutorFixtureOwnerUid);
    expect(args['grantId'], tutorFixtureGrantId);
    expect(args['actionId'], isA<String>());
    final data = args['goalData'] as Map<String, dynamic>;
    expect(data, created.toFirestore());
    expect(created.curriculumId, CurriculumId.mishnayos);
    expect(created.goalType, 'pace');
    expect(created.paceValue, 2);
    expect(created.description, 'Seder Moed');
  });

  test('a refused preflight (no editing access) creates nothing', () async {
    h = TutorHarness(canEditLearning: false);
    container = tutored(h);

    await expectLater(
      container
          .read(goalRepositoryProvider)
          .createGoal(curriculumId: CurriculumId.mishnayos),
      throwsA(isA<TutorGovernedWriteException>()),
    );
    expect(h.invoker.calls, isEmpty);
  });
}
