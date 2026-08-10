/// Unit tests (plain [ProviderContainer], no widget) for
/// [pointConfigDataProvider]'s purity — AUD-gamification-03 / SM-2.
///
/// Before this fix, `pointConfigDataProvider`'s build function seeded
/// missing stage definitions (`StageDefinitionRepository.initializeDefaults`)
/// and missing `PointConfig` rows, then pushed a sync snapshot, all as a
/// side effect of simply being watched/rebuilt. That write/push work now
/// lives exclusively in [PointConfigMaintenanceController.seedMissingDefaultsIfNeeded],
/// invoked explicitly from [PointConfigScreen]'s `initState` — never as a
/// side effect of this read provider.
@Tags(['gamification', 'point_config_data_provider'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/point_config_screen.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/test_database.dart';

/// [SyncWriteFacade] that counts [pushGamificationSettingsSnapshot] calls
/// instead of performing any real push.
class _CountingSyncFacade implements SyncWriteFacade {
  int pushCount = 0;

  @override
  Future<void> pushGamificationSettingsSnapshot() async {
    pushCount++;
  }

  @override
  Future<void> pushUiPreferencesSnapshot() async {}
  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) async {}
  @override
  Future<void> pushSettings(Map<String, dynamic> settings) async {}
  @override
  Future<void> pushGoal(Map<String, dynamic> goal) async {}
  @override
  Future<void> deleteGoal(Map<String, dynamic> payload) async {}
  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {}
  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {}
  @override
  Future<void> deleteLearnerProfile(String profileUlid) async {}
  @override
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  }) async {}
  @override
  Future<void> pushStudyDayConfig(Map<String, dynamic> payload) async {}
  @override
  Future<void> deleteCompletion(String completionId) async {}
  @override
  Future<void> pushProfileProgram(Map<String, dynamic> payload) async {}
}

void main() {
  test(
    'watching pointConfigDataProvider twice (rebuild via invalidate) neither '
    'seeds stage definitions / PointConfig rows for a brand-new track nor '
    'pushes a sync snapshot -- that is now '
    'PointConfigMaintenanceController.seedMissingDefaultsIfNeeded()\'s job, '
    'invoked explicitly, never a side effect of this read provider',
    () async {
      final counting = _CountingSyncFacade();
      final db = inMemoryDb();
      final c = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWithValue(1),
          syncWriteFacadeProvider.overrideWithValue(counting),
        ],
      );
      addTearDown(c.dispose);
      await seedProfileWithIds(db, accountId: 1, profileId: 1);

      // A brand-new active track with NO stage definitions and NO
      // PointConfig rows yet -- exactly the state that used to trigger
      // inline seeding inside the provider's build.
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: 1,
              curriculumId: 'mishnayos',
              stateChangedAt: DateTime.utc(2026, 1, 1),
              activatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      // First watch.
      await c.read(pointConfigDataProvider.future);
      // Force a rebuild (second watch) -- a mutating build would seed/push
      // again here, growing the counters.
      c.invalidate(pointConfigDataProvider);
      await c.read(pointConfigDataProvider.future);

      final stages = await c
          .read(stageDefinitionRepositoryProvider(CurriculumId.mishnayos))
          .getStagesByTrack(trackId);
      expect(
        stages,
        isEmpty,
        reason:
            'a pure pointConfigDataProvider build must never seed stage '
            'definitions as a side effect of being watched',
      );

      final configs = await db.pointConfigDao.getConfigsByCurriculum(
        'mishnayos',
        profileId: 1,
        trackId: trackId,
      );
      expect(
        configs,
        isEmpty,
        reason:
            'a pure pointConfigDataProvider build must never seed PointConfig '
            'rows as a side effect of being watched',
      );

      expect(
        counting.pushCount,
        0,
        reason:
            'a pure pointConfigDataProvider build must never push a sync '
            'snapshot as a side effect of being watched/rebuilt',
      );
    },
  );
}
