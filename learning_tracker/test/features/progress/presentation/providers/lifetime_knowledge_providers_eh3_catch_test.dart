/// AUD-progress-06 regression coverage for the calendar fallback breadcrumb.
@Tags(['progress'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/calendar_position_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
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

final class _Stages implements StageDefinitionRepository {
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

void main() {
  test(
    'calendar failure is logged before due counts fall back to zero',
    () async {
      AppLogger.instance.talker.cleanHistory();
      final container = ProviderContainer(
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
            TrackProgressService(
              repository: _ChartData(),
              stageRepo: _Stages(),
            ),
          ),
          trackCompletionsByProfileProvider.overrideWith(
            (ref) async => const {},
          ),
          trackLedgerEntriesByProfileProvider.overrideWith(
            (ref) async => const <String, List<LearningLedgerEntry>>{},
          ),
          profileProgramsByProfileProvider.overrideWith(
            (ref) async => {
              _curriculum.storageKey: ProfileProgramEntity(
                curriculumId: _curriculum,
                programId: 1,
                updatedAt: DateTime.utc(2026, 1, 1),
              ),
            },
          ),
          programCalendarPositionProvider(_curriculum).overrideWith(
            (ref) async => throw StateError('calendar test failure'),
          ),
        ],
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

      expect(metric.todayDueCount, 0);
      expect(metric.overdueCount, 0);
      final history = AppLogger.instance.talker.history
          .map((entry) => entry.generateTextMessage())
          .toList();
      expect(
        history.any(
          (message) =>
              message.contains('track_dual_progress_calendar_position_failed'),
        ),
        isTrue,
      );
    },
  );
}
