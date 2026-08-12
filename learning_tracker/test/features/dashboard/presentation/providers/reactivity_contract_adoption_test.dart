/// R5 reactivity-contract adoption — dashboard percentage aggregates.
///
/// Drives [dashboardTrackCompletionPercentageProvider] and
/// [dashboardCompletionPercentageProvider] through the shared
/// `expectRebuildsOn` helper (`test/helpers/reactivity_contract.dart`).
/// Both watch `completionCommittedProvider` so the dashboard's completion
/// bars update live after a completion, without pull-to-refresh.
///
/// Fixture mirrors `dashboard_completion_percentage_test.dart`'s proven
/// `_makeContainer` override set (`scopedItemCountProvider` stubbed per
/// curriculum so no content DB is touched); this is a NEW, additional guard
/// alongside that file's detailed value-level assertions, not a
/// replacement for them.
@Tags(['dashboard', 'riverpod', 'contract'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/firestore_fixtures.dart';
import '../../../../helpers/reactivity_contract.dart';

const _uid = 'dashboard-reactivity-uid';
const _profileId = 'dashboard-reactivity-profile-ulid';
const _curriculum = CurriculumId.mishnayos;

ProviderContainer _makeContainer({
  required FirestoreCompletionRepository completionRepository,
  required FirestoreStageDefinitionRepository stageRepository,
}) => ProviderContainer(
  overrides: [
    firestoreCompletionRepositoryProvider.overrideWith(
      (ref) async => completionRepository,
    ),
    firestoreStageDefinitionRepositoryProvider.overrideWith(
      (ref) async => stageRepository,
    ),
    activeProfileIdProvider.overrideWithValue(_profileId),
    // Stub every curriculum's scoped item count so the test never touches
    // the (heavy) bundled content database — only `_curriculum` has any
    // items, matching the single stage/track seeded below.
    for (final c in CurriculumId.values)
      scopedItemCountProvider(
        c,
      ).overrideWith((ref) => Future.value(c == _curriculum ? 1 : 0)),
  ],
);

Future<void> _recordCompletionAndTick(
  ProviderContainer container,
  FakeFirebaseFirestore firestore,
) async {
  await seedCompletion(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: _curriculum,
    sefariaRef: 'Mishnah Berakhot 1:1',
    stageId: 1,
    trackType: 'personal',
    completedAt: DateTime.utc(2026, 1, 2),
    source: CompletionSource.live,
  );
  container.read(completionCommittedProvider.notifier).increment();
}

Future<
  (
    FakeFirebaseFirestore,
    FirestoreCompletionRepository,
    FirestoreStageDefinitionRepository,
  )
>
_makeFixture() async {
  final firestore = createFakeFirestore(authenticatedUid: _uid);
  final completionRepository = FirestoreCompletionRepository(
    firestore: firestore,
    uid: _uid,
    profileId: _profileId,
  );
  final stageRepository = FirestoreStageDefinitionRepository(
    firestore: firestore,
    uid: _uid,
    profileId: _profileId,
  );
  await seedStageDefinitions(
    firestore,
    uid: _uid,
    profileId: _profileId,
    curriculumId: _curriculum,
    stages: [
      const StageDefinition(
        id: kFirestoreUnmappedStageId,
        curriculumId: _curriculum,
        stageOrder: 1,
        stageName: 'Learned',
        delayDays: 0,
        isDefault: true,
        scheduleType: ScheduleType.delay,
      ),
    ],
  );
  return (firestore, completionRepository, stageRepository);
}

void main() {
  group('dashboard percentage providers rebuild on '
      'completionCommittedProvider', () {
    test('dashboardTrackCompletionPercentageProvider', () async {
      final (firestore, completionRepository, stageRepository) =
          await _makeFixture();
      final container = _makeContainer(
        completionRepository: completionRepository,
        stageRepository: stageRepository,
      );
      addTearDown(container.dispose);

      final before = await container.read(
        dashboardTrackCompletionPercentageProvider(_curriculum).future,
      );
      expect(before, 0.0);

      await expectRebuildsOn(
        container,
        dashboardTrackCompletionPercentageProvider(_curriculum),
        () => _recordCompletionAndTick(container, firestore),
        reason:
            'dashboardTrackCompletionPercentageProvider must watch '
            'completionCommittedProvider so the dashboard bar updates live',
      );

      final after = await container.read(
        dashboardTrackCompletionPercentageProvider(_curriculum).future,
      );
      expect(
        after,
        1.0,
        reason:
            'the seeded completion must change the computed dashboard '
            'percentage, not merely trigger a rebuild notification',
      );
    });

    test('dashboardCompletionPercentageProvider', () async {
      final (firestore, completionRepository, stageRepository) =
          await _makeFixture();
      final container = _makeContainer(
        completionRepository: completionRepository,
        stageRepository: stageRepository,
      );
      addTearDown(container.dispose);

      final before = await container.read(
        dashboardCompletionPercentageProvider(_curriculum).future,
      );
      expect(before, 0.0);

      await expectRebuildsOn(
        container,
        dashboardCompletionPercentageProvider(_curriculum),
        () => _recordCompletionAndTick(container, firestore),
        reason:
            'dashboardCompletionPercentageProvider must watch '
            'completionCommittedProvider so the dashboard bar updates live',
      );

      final after = await container.read(
        dashboardCompletionPercentageProvider(_curriculum).future,
      );
      expect(
        after,
        1.0,
        reason:
            'the seeded completion must change the computed dashboard '
            'percentage, not merely trigger a rebuild notification',
      );
    });
  });
}
