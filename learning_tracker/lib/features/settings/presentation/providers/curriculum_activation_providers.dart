import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/track_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Provider for CurriculumActivationService, scoped to the active profile.
final curriculumActivationServiceProvider =
    Provider<CurriculumActivationService>((ref) {
      final database = ref.watch(userDatabaseProvider);
      final syncFacade = ref.watch(syncWriteFacadeProvider);
      final trackRepository = ref.watch(trackRepositoryProvider);
      final profileId = ref.watch(activeProfileIdProvider);

      return CurriculumActivationService(
        database: database,
        pushCurriculumTrack: syncFacade?.pushCurriculumTrack,
        trackRepository: trackRepository,
        profileId: profileId,
      );
    });

/// Provider for list of active curricula (as enums), scoped to active profile.
final activeCurriculaProvider = FutureProvider<List<CurriculumId>>((ref) async {
  final service = ref.watch(curriculumActivationServiceProvider);
  return service.getActiveCurricula();
});

/// Stream provider for watching active curricula changes for the active profile.
final activeCurriculaStreamProvider = StreamProvider<List<CurriculumId>>((
  ref,
) async* {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  await for (final storageKeys
      in database.activeCurriculumDao.watchActiveCurriculaByProfile(
        profileId,
      )) {
    final curricula = storageKeys
        .map<CurriculumId?>((key) {
          final matches = CurriculumId.values.where((c) => c.storageKey == key);
          if (matches.isNotEmpty) {
            return matches.first;
          }
          AppLogger.instance.warning(
            event: 'activeCurriculaStreamProvider: unknown curriculum key: $key',
          );
          return null;
        })
        .whereType<CurriculumId>()
        .toList();
    yield curricula;
  }
});

/// Provider for checking if a specific curriculum is active for the profile.
final isCurriculumActiveProvider = FutureProvider.family<bool, CurriculumId>((
  ref,
  curriculum,
) async {
  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return database.activeCurriculumDao.isActiveForProfile(curriculum, profileId);
});
