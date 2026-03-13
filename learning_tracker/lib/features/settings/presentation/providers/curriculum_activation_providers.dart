import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/track_providers.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Provider for CurriculumActivationService
final curriculumActivationServiceProvider =
    Provider<CurriculumActivationService>((ref) {
      final database = ref.watch(appDatabaseProvider);
      final firestoreDataSource = ref.watch(firestoreDataSourceProvider);
      final trackRepository = ref.watch(trackRepositoryProvider);

      return CurriculumActivationService(
        database: database,
        pushActiveCurricula: firestoreDataSource.pushActiveCurricula,
        trackRepository: trackRepository,
      );
    });

/// Provider for list of active curricula (as enums)
final activeCurriculaProvider = FutureProvider<List<CurriculumId>>((ref) async {
  final service = ref.watch(curriculumActivationServiceProvider);
  return service.getActiveCurricula();
});

/// Stream provider for watching active curricula changes
final activeCurriculaStreamProvider = StreamProvider<List<CurriculumId>>((
  ref,
) async* {
  final database = ref.watch(appDatabaseProvider);

  await for (final storageKeys
      in database.activeCurriculumDao.watchActiveCurricula()) {
    // Map each storage key to a CurriculumId, skipping unknown keys with a
    // warning rather than crashing. This handles the case where a curriculum
    // was removed from the enum but still exists in an old database.
    final curricula = storageKeys
        .map<CurriculumId?>((key) {
          final matches = CurriculumId.values.where(
            (c) => c.storageKey == key,
          );
          if (matches.isNotEmpty) {
            return matches.first;
          }
          AppLogger.instance.warning(
            'activeCurriculaStreamProvider: unknown curriculum key: $key',
          );
          return null;
        })
        .whereType<CurriculumId>()
        .toList();
    yield curricula;
  }
});

/// Provider for checking if a specific curriculum is active
final isCurriculumActiveProvider = FutureProvider.family<bool, CurriculumId>((
  ref,
  curriculum,
) async {
  final database = ref.watch(appDatabaseProvider);
  return database.activeCurriculumDao.isActive(curriculum);
});
