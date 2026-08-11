import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_point_config_repository.dart';
import 'package:learning_tracker/features/gamification/domain/models/point_config.dart';

/// Feature-scoped adapter over [FirestorePointConfigRepository] --
/// presentation/** (point_config_screen.dart) cannot reach
/// `lib/data/firestore/repository_providers.dart` directly (AD-23/AD-28);
/// this file's own path (`.../data/repositories/`) is the sanctioned seam.
///
/// No interface: mirrors `FirestoreStageDefinitionRepositoryAdapter`'s
/// reasoning (its own doc comment) -- greenfield, no Drift twin to stay
/// substitutable with. `PointConfigProvider`
/// (features/gamification/domain/services/points_service.dart) is a
/// separate, confirmed-dead abstraction (zero implementations, zero real
/// callers anywhere in lib/ as of task #4) -- deliberately not implemented
/// here; wiring the screen through it would mean investing in dead code
/// instead of the screen's actual needs (a full config list + a write
/// path, neither of which `PointConfigProvider` exposes).
class FirestorePointConfigRepositoryAdapter {
  FirestorePointConfigRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  Future<List<PointConfigEntity>> getConfigsForCurriculum(
    CurriculumId curriculumId,
  ) async {
    final repo = await _ref.read(firestorePointConfigRepositoryProvider.future);
    if (repo == null) return const [];
    return repo.getConfigsForCurriculum(curriculumId);
  }

  Future<void> upsertConfig({
    required CurriculumId curriculumId,
    required int stageOrder,
    required int points,
  }) async {
    final repo = await _ref.read(firestorePointConfigRepositoryProvider.future);
    if (repo == null) {
      throw StateError(
        'FirestorePointConfigRepositoryAdapter.upsertConfig: '
        'firestorePointConfigRepositoryProvider resolved to null (no '
        'active account, or no active learner profile, yet) — refusing to '
        'silently drop a parent-entered point-value edit.',
      );
    }
    await repo.upsertConfig(
      curriculumId: curriculumId,
      stageOrder: stageOrder,
      points: points,
    );
  }

  Future<void> clearOverride({
    required CurriculumId curriculumId,
    required int stageOrder,
  }) async {
    final repo = await _ref.read(firestorePointConfigRepositoryProvider.future);
    if (repo == null) {
      throw StateError(
        'FirestorePointConfigRepositoryAdapter.clearOverride: '
        'firestorePointConfigRepositoryProvider resolved to null (no '
        'active account, or no active learner profile, yet) — refusing to '
        'silently drop a parent-entered point-value edit.',
      );
    }
    await repo.clearOverride(curriculumId: curriculumId, stageOrder: stageOrder);
  }
}
