import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Provider for CurriculumActivationService
final curriculumActivationServiceProvider =
    Provider<CurriculumActivationService>((ref) {
      final database = ref.watch(appDatabaseProvider);
      final firestoreDataSource = ref.watch(firestoreDataSourceProvider);

      return CurriculumActivationService(
        database: database,
        pushActiveCurricula: firestoreDataSource.pushActiveCurricula,
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
    final curricula = storageKeys
        .map(
          (key) => CurriculumId.values.firstWhere((c) => c.storageKey == key),
        )
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
