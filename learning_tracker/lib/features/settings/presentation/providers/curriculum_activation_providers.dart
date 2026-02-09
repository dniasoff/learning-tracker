import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

/// Provider for the curriculum activation service
final curriculumActivationServiceProvider =
    Provider<CurriculumActivationService>((ref) {
      final database = ref.watch(appDatabaseProvider);
      final firestoreDataSource = ref.watch(firestoreDataSourceProvider);
      return CurriculumActivationService(
        database: database,
        firestoreDataSource: firestoreDataSource,
      );
    });

/// Provider for the list of active curricula
///
/// This is a stream that updates whenever the database changes.
final activeCurriculaProvider = StreamProvider<List<CurriculumId>>((ref) {
  final db = ref.watch(appDatabaseProvider);

  // Watch the database for changes
  return db.activeCurriculumDao.select(db.activeCurricula).watch().map((rows) {
    return rows
        .map(
          (row) => CurriculumId.values.firstWhere(
            (c) => c.storageKey == row.curriculumId,
          ),
        )
        .toList();
  });
});

/// Provider to check if a specific curriculum is active
final isCurriculumActiveProvider = FutureProvider.family<bool, CurriculumId>((
  ref,
  curriculum,
) async {
  final service = ref.watch(curriculumActivationServiceProvider);
  return service.isActive(curriculum);
});
