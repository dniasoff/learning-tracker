import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

/// Provider for [StageDefinitionRepository], scoped per [CurriculumId].
final stageDefinitionRepositoryProvider =
    Provider.family<StageDefinitionRepository, CurriculumId>((ref, curriculum) {
      final database = ref.watch(userDatabaseProvider);
      final syncFacade = ref.watch(syncWriteFacadeProvider);
      return StageDefinitionRepositoryImpl(
        stageDao: database.stageDao,
        completionDao: database.completionDao,
        // Plan §F Phase 5 deliverable 6 — dedicated stage_definition outbox
        // kind replaces the legacy pushSettings piggyback.
        pushStageDefinitions: syncFacade?.pushStageDefinitions,
      );
    });

/// Global (non-curriculum-scoped) provider for [StageDefinitionRepository].
///
/// Use when the caller has a [trackId] but not a [CurriculumId], or when
/// performing cross-curriculum operations such as data export.
final globalStageRepositoryProvider = Provider<StageDefinitionRepository>((
  ref,
) {
  final database = ref.watch(userDatabaseProvider);
  final syncFacade = ref.watch(syncWriteFacadeProvider);
  return StageDefinitionRepositoryImpl(
    stageDao: database.stageDao,
    completionDao: database.completionDao,
    pushStageDefinitions: syncFacade?.pushStageDefinitions,
  );
});

/// Provider for the list of stages for a curriculum, ordered by stageOrder.
final stageListProvider =
    FutureProvider.family<List<StageDefinition>, CurriculumId>((
      ref,
      curriculum,
    ) async {
      final repository = ref.watch(
        stageDefinitionRepositoryProvider(curriculum),
      );
      return repository.getStagesForCurriculum(curriculum);
    });

/// Notifier that exposes stage mutation operations for a curriculum.
///
/// The [CurriculumId] is captured at construction time (Riverpod 3.x family
/// notifier pattern — arg passed via [AsyncNotifierProvider.family] create fn).
class StageEditorNotifier extends AsyncNotifier<List<StageDefinition>> {
  StageEditorNotifier(this._curriculum);

  final CurriculumId _curriculum;

  @override
  Future<List<StageDefinition>> build() async {
    final repository = ref.watch(
      stageDefinitionRepositoryProvider(_curriculum),
    );
    return repository.getStagesForCurriculum(_curriculum);
  }

  StageDefinitionRepository get _repository =>
      ref.read(stageDefinitionRepositoryProvider(_curriculum));

  Future<void> addStage(
    String name, {
    required int trackId,
    ScheduleSpec schedule = const DelaySchedule(0),
  }) async {
    final profileId = ref.read(activeProfileIdProvider);
    await _repository.addStage(
      _curriculum,
      name,
      profileId: profileId,
      trackId: trackId,
      schedule: schedule,
    );
    ref.invalidate(stageListProvider(_curriculum));
    state = await AsyncValue.guard(
      () => _repository.getStagesForCurriculum(_curriculum),
    );
  }

  Future<void> updateStage(int id, {String? name, int? delayDays}) async {
    await _repository.updateStage(id, name: name, delayDays: delayDays);
    ref.invalidate(stageListProvider(_curriculum));
    state = await AsyncValue.guard(
      () => _repository.getStagesForCurriculum(_curriculum),
    );
  }

  Future<void> deleteStage(int id) async {
    await _repository.deleteStage(id);
    ref.invalidate(stageListProvider(_curriculum));
    state = await AsyncValue.guard(
      () => _repository.getStagesForCurriculum(_curriculum),
    );
  }

  Future<void> reorderStages(List<int> orderedIds) async {
    await _repository.reorderStages(_curriculum, orderedIds);
    ref.invalidate(stageListProvider(_curriculum));
    state = await AsyncValue.guard(
      () => _repository.getStagesForCurriculum(_curriculum),
    );
  }

  Future<void> resetToDefaults({required int trackId}) async {
    final profileId = ref.read(activeProfileIdProvider);
    await _repository.resetToDefaults(
      _curriculum,
      profileId: profileId,
      trackId: trackId,
    );
    ref.invalidate(stageListProvider(_curriculum));
    state = await AsyncValue.guard(
      () => _repository.getStagesForCurriculum(_curriculum),
    );
  }
}

/// Provider for [StageEditorNotifier], scoped per [CurriculumId].
final stageEditorProvider =
    AsyncNotifierProvider.family<
      StageEditorNotifier,
      List<StageDefinition>,
      CurriculumId
    >((curriculum) => StageEditorNotifier(curriculum));
