/// Regression coverage for profile-wide CurriculumId-keyed batching.
@Tags(['progress'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';
import 'package:learning_tracker/features/tracks/presentation/providers/track_progress_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

const _profileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const _curricula = [
  CurriculumId.mishnayos,
  CurriculumId.chumash,
  CurriculumId.bavli,
];

final class _ActiveProfile extends ActiveProfileId {
  @override
  String? build() => _profileId;
}

final class _EnglishTerms extends UseHebrewTerms {
  @override
  bool build() => false;
}

final class _Stages implements StageDefinitionRepository {
  @override
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  ) async => [
    StageDefinition(
      id: -1,
      curriculumId: curriculumId,
      stageOrder: 1,
      stageName: 'Learn',
      delayDays: 0,
      isDefault: true,
    ),
  ];

  @override
  Future<void> initializeDefaults(
    CurriculumId curriculumId, {
    required int profileId,
    required int trackId,
  }) => throw UnimplementedError();

  @override
  Future<void> replaceStagesForCurriculum(
    CurriculumId curriculumId,
    List<StageDefinition> stages,
  ) => throw UnimplementedError();

  @override
  Future<void> resetToDefaults(CurriculumId curriculumId) =>
      throw UnimplementedError();

  @override
  Future<bool> hasCompletionsForStage(int stageId) =>
      throw UnimplementedError();

  @override
  Future<List<StageDefinition>> getStagesByTrack(int trackId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteStagesForTrack(int trackId) => throw UnimplementedError();

  @override
  Future<void> pushStagesForTrack({
    required int trackId,
    required CurriculumId curriculumId,
  }) => throw UnimplementedError();

  @override
  Future<List<StageDefinition>> getAllStageDefinitions() =>
      throw UnimplementedError();
}

final class _ChartData implements ChartDataRepository {
  @override
  Future<List<CompletionEntity>> getCompletionsByTier({
    required CompletionTierFilter tier,
    CurriculumId? curriculumId,
    DateTime? since,
    DateTime? until,
  }) async => const [];

  @override
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    CurriculumId curriculumId,
  ) async => const [];

  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async =>
      const [];
}

final class _Counts {
  int completions = 0;
  int ledger = 0;
  int programs = 0;
}

CurriculumTrackEntity _track(CurriculumId curriculum) => CurriculumTrackEntity(
  curriculumId: curriculum,
  state: 'active',
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

ProviderContainer _container(
  _Counts counts, {
  Map<String, List<CompletionEntity>>? completions,
}) => ProviderContainer(
  overrides: [
    activeProfileIdProvider.overrideWith(() => _ActiveProfile()),
    useHebrewTermsProvider.overrideWith(() => _EnglishTerms()),
    activeTracksProvider.overrideWith(
      (ref) => Stream.value(_curricula.map(_track).toList()),
    ),
    scopedCurriculumContentProvider.overrideWith(
      (ref, curriculum) async => [
        ContentItem(
          curriculumId: curriculum.storageKey,
          sefariaRef: '${curriculum.storageKey}_ref',
          displayNameEn: 'Item',
          displayNameHe: 'פריט',
          level1: 'Seder',
          level2: 'Masechta',
          level3: null,
          level4: null,
          isLeaf: true,
          sortOrder: 0,
        ),
      ],
    ),
    trackProgressServiceProvider.overrideWithValue(
      TrackProgressService(repository: _ChartData(), stageRepo: _Stages()),
    ),
    trackCompletionsByProfileProvider.overrideWith((ref) async {
      counts.completions++;
      ref.watch<int>(completionCommittedProvider);
      return completions ?? const <String, List<CompletionEntity>>{};
    }),
    trackLedgerEntriesByProfileProvider.overrideWith((ref) async {
      counts.ledger++;
      ref.watch<int>(completionCommittedProvider);
      return const {};
    }),
    profileProgramsByProfileProvider.overrideWith((ref) async {
      counts.programs++;
      ref.watch<int>(completionCommittedProvider);
      return const <String, ProfileProgramEntity>{};
    }),
  ],
);

void main() {
  test('three active tracks share each profile-wide provider build', () async {
    final counts = _Counts();
    final container = _container(counts);
    addTearDown(container.dispose);
    final keepAlive = container.listen(
      trackDualProgressMetricsProvider,
      (_, __) {},
    );
    addTearDown(keepAlive.close);

    final metrics = await container.read(
      trackDualProgressMetricsProvider.future,
    );

    expect(metrics, hasLength(_curricula.length));
    expect(counts.completions, 1);
    expect(counts.ledger, 1);
    expect(counts.programs, 1);
  });

  test(
    'the provider remains recomputable after a completion commit tick',
    () async {
      final counts = _Counts();
      final completions = <String, List<CompletionEntity>>{};
      final container = _container(counts, completions: completions);
      addTearDown(container.dispose);
      final subscription = container.listen(
        trackDualProgressMetricsProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);

      final first = await container.read(
        trackDualProgressMetricsProvider.future,
      );
      completions[CurriculumId.mishnayos.storageKey] = [
        CompletionEntity(
          curriculumId: CurriculumId.mishnayos,
          sefariaRef: 'mishnayos_ref',
          stageId: 1,
          trackType: 'personal',
          source: CompletionSource.live,
          completedAt: DateTime.utc(2026, 2, 1),
        ),
      ];
      container.read(completionCommittedProvider.notifier).increment();
      final second = await container.read(
        trackDualProgressMetricsProvider.future,
      );

      expect(second, hasLength(first.length));
      expect(second.first.lifetimePercentage, 1.0);
      expect(counts.completions, 2);
      expect(counts.ledger, 2);
      expect(counts.programs, 2);
    },
  );
}
