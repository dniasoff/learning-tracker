/// Reactivity coverage for the CurriculumId-keyed dual-progress provider.
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
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
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
const _curriculum = CurriculumId.mishnayos;

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
  Future<List<StageDefinition>> getStagesByTrack(CurriculumId curriculumId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteStagesForTrack(CurriculumId curriculumId) =>
      throw UnimplementedError();

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
  final completions = <CompletionEntity>[];

  @override
  Future<List<CompletionEntity>> getCompletionsByTier({
    required CompletionTierFilter tier,
    CurriculumId? curriculumId,
    DateTime? since,
    DateTime? until,
  }) async => completions.where((completion) {
    if (curriculumId != null && completion.curriculumId != curriculumId) {
      return false;
    }
    if (since != null && completion.completedAt.isBefore(since)) return false;
    if (until != null && completion.completedAt.isAfter(until)) return false;
    return completion.purgedAt == null;
  }).toList();

  @override
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    CurriculumId curriculumId,
  ) async => completions;

  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async =>
      const [];
}

ProviderContainer _container(
  _ChartData chart,
  Map<String, List<CompletionEntity>> completions,
) => ProviderContainer(
  overrides: [
    activeProfileIdProvider.overrideWith(() => _ActiveProfile()),
    useHebrewTermsProvider.overrideWith(() => _EnglishTerms()),
    activeTracksProvider.overrideWith(
      (ref) => Stream.value([
        CurriculumTrackEntity(
          curriculumId: _curriculum,
          state: 'active',
          stateChangedAt: DateTime.utc(2026, 1, 1),
          activatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]),
    ),
    scopedCurriculumContentProvider.overrideWith(
      (ref, curriculum) async => [
        ContentItem(
          curriculumId: curriculum.storageKey,
          sefariaRef: 'mishnayos_ref',
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
      TrackProgressService(repository: chart, stageRepo: _Stages()),
    ),
    trackCompletionsByProfileProvider.overrideWith((ref) async {
      ref.watch<int>(completionCommittedProvider);
      return completions;
    }),
    trackLedgerEntriesByProfileProvider.overrideWith((ref) async {
      ref.watch<int>(completionCommittedProvider);
      return const <String, List<LearningLedgerEntry>>{};
    }),
    profileProgramsByProfileProvider.overrideWith((ref) async {
      ref.watch<int>(completionCommittedProvider);
      return const <String, ProfileProgramEntity>{};
    }),
  ],
);

CompletionEntity _completion() => CompletionEntity(
  curriculumId: _curriculum,
  sefariaRef: 'mishnayos_ref',
  stageId: 1,
  trackType: 'personal',
  source: CompletionSource.live,
  completedAt: DateTime.utc(2026, 2, 1),
);

void main() {
  test(
    'current-cycle percentage reflects a new completion after a tick',
    () async {
      final chart = _ChartData();
      final completions = <String, List<CompletionEntity>>{};
      final container = _container(chart, completions);
      addTearDown(container.dispose);
      final keepAlive = container.listen(
        trackDualProgressMetricsProvider,
        (_, __) {},
      );
      addTearDown(keepAlive.close);

      final first = await container.read(
        trackDualProgressMetricsProvider.future,
      );
      chart.completions.add(_completion());
      completions[_curriculum.storageKey] = [_completion()];
      container.read(completionCommittedProvider.notifier).increment();
      final second = await container.read(
        trackDualProgressMetricsProvider.future,
      );

      expect(first.single.currentCyclePercentage, 0.0);
      expect(second.single.currentCyclePercentage, 1.0);
    },
  );

  test('lifetime percentage reflects a new completion after a tick', () async {
    final chart = _ChartData();
    final completions = <String, List<CompletionEntity>>{};
    final container = _container(chart, completions);
    addTearDown(container.dispose);
    final keepAlive = container.listen(
      trackDualProgressMetricsProvider,
      (_, __) {},
    );
    addTearDown(keepAlive.close);

    final first = await container.read(trackDualProgressMetricsProvider.future);
    completions[_curriculum.storageKey] = [_completion()];
    container.read(completionCommittedProvider.notifier).increment();
    final second = await container.read(
      trackDualProgressMetricsProvider.future,
    );

    expect(first.single.lifetimePercentage, 0.0);
    expect(second.single.lifetimePercentage, 1.0);
  });
}
