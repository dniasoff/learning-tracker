/// CurriculumId-keyed regression coverage for the dual-progress provider.
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
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
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

final class _FakeStageRepository implements StageDefinitionRepository {
  @override
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  ) async => [
    StageDefinition(
      curriculumId: curriculumId,
      stageOrder: 1,
      stageName: 'Learn',
      delayDays: 0,
      isDefault: true,
    ),
  ];

  @override
  Future<void> initializeDefaults(CurriculumId curriculumId) =>
      throw UnimplementedError();

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
  Future<List<StageDefinition>> getAllStageDefinitions() =>
      throw UnimplementedError();
}

final class _FakeChartDataRepository implements ChartDataRepository {
  _FakeChartDataRepository(this.completions);

  final List<CompletionEntity> completions;

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
  ) async => completions
      .where((completion) => completion.curriculumId == curriculumId)
      .toList();

  @override
  Future<List<GoalEntity>> getGoals(CurriculumId curriculumId) async =>
      const [];
}

List<ContentItem> _leaves(CurriculumId curriculum) => List.generate(
  5,
  (index) => ContentItem(
    curriculumId: curriculum.storageKey,
    sefariaRef: '${curriculum.storageKey}_ref_$index',
    displayNameEn: 'Item $index',
    displayNameHe: 'פריט $index',
    level1: 'Seder',
    level2: 'Masechta',
    level3: null,
    level4: null,
    isLeaf: true,
    sortOrder: index,
  ),
);

CurriculumTrackEntity _track(
  CurriculumId curriculum, {
  String state = 'active',
}) => CurriculumTrackEntity(
  curriculumId: curriculum,
  state: state,
  stateChangedAt: DateTime.utc(2026, 1, 1),
  activatedAt: DateTime.utc(2026, 1, 1),
);

LearningLedgerEntry _ledgerEntry({required CurriculumId curriculum}) =>
    LearningLedgerEntry(
      ulid: '01ARZ3NDEKTSV4RRFFQ69G5FB0',
      curriculumId: curriculum,
      entryScope: 'level2',
      unitIdentifier: 'Seder|Masechta',
      unitDisplayNameHe: 'פריט',
      unitDisplayNameEn: 'Item',
      trackType: 'personal',
      completedAt: DateTime.utc(2000, 1, 1),
      completionNumber: 1,
      markedBy: _profileId,
      isManual: true,
      source: CompletionSource.lifetimeOnly,
    );

ProviderContainer _container({
  required List<CurriculumTrackEntity> tracks,
  required Map<String, List<CompletionEntity>> completions,
  required Map<String, List<LearningLedgerEntry>> ledger,
}) {
  final chartData = _FakeChartDataRepository(
    completions.values.expand((items) => items).toList(),
  );
  return ProviderContainer(
    overrides: [
      activeProfileIdProvider.overrideWith(() => _ActiveProfile()),
      useHebrewTermsProvider.overrideWith(() => _EnglishTerms()),
      activeTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      scopedCurriculumContentProvider.overrideWith(
        (ref, curriculum) async => _leaves(curriculum),
      ),
      trackProgressServiceProvider.overrideWithValue(
        TrackProgressService(
          repository: chartData,
          stageRepo: _FakeStageRepository(),
        ),
      ),
      trackCompletionsByProfileProvider.overrideWith(
        (ref) async => completions,
      ),
      trackLedgerEntriesByProfileProvider.overrideWith((ref) async => ledger),
      profileProgramsByProfileProvider.overrideWith(
        (ref) async => const <String, ProfileProgramEntity>{},
      ),
    ],
  );
}

void main() {
  test(
    'a lifetime-only scope mark raises lifetimePercentage while current-cycle stays 0%',
    () async {
      final container = _container(
        tracks: [_track(_curriculum)],
        completions: const {},
        ledger: {
          _curriculum.storageKey: [_ledgerEntry(curriculum: _curriculum)],
        },
      );
      addTearDown(container.dispose);
      final keepAlive = container.listen(
        trackDualProgressMetricsProvider,
        (_, __) {},
      );
      addTearDown(keepAlive.close);

      final metric = (await container.read(
        trackDualProgressMetricsProvider.future,
      )).single;

      expect(metric.lifetimePercentage, 1.0);
      expect(metric.currentCyclePercentage, 0.0);
    },
  );

  test('a lifetime-only import for another curriculum does not leak', () async {
    const other = CurriculumId.bavli;
    final container = _container(
      tracks: [_track(_curriculum)],
      completions: const {},
      ledger: {
        other.storageKey: [_ledgerEntry(curriculum: other)],
      },
    );
    addTearDown(container.dispose);
    final keepAlive = container.listen(
      trackDualProgressMetricsProvider,
      (_, __) {},
    );
    addTearDown(keepAlive.close);

    final metric = (await container.read(
      trackDualProgressMetricsProvider.future,
    )).single;

    expect(metric.lifetimePercentage, 0.0);
  });

  test('retired tracks are excluded from the metric list', () async {
    final container = _container(
      tracks: [
        _track(_curriculum),
        _track(CurriculumId.bavli, state: 'retired'),
      ],
      completions: const {},
      ledger: const {},
    );
    addTearDown(container.dispose);
    final keepAlive = container.listen(
      trackDualProgressMetricsProvider,
      (_, __) {},
    );
    addTearDown(keepAlive.close);

    final metrics = await container.read(
      trackDualProgressMetricsProvider.future,
    );

    expect(metrics.map((metric) => metric.curriculumId), [_curriculum]);
  });
}
