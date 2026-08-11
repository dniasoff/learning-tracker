import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/study_day_config_providers.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';

/// Provider of [CurriculumActivationService], scoped to the active profile.
///
/// The service is constructed from Firestore adapters only — the curriculum
/// track adapter and the study-day config adapter. Each is itself built per
/// active profile by its own provider, so the profile dimension is carried by
/// the repositories' collection paths rather than passed per-call
/// (AD-24/AD-25). No database, sync facade or outbox DAO is involved: that
/// engine is deleted and Firestore owns its own offline queueing.
final curriculumActivationServiceProvider =
    Provider<CurriculumActivationService>((ref) {
  final trackRepository = ref.watch(curriculumTrackRepositoryAdapterProvider);
  final studyDayConfigRepository = ref.watch(
    studyDayConfigRepositoryAdapterProvider,
  );
  return CurriculumActivationService(
    trackRepository: trackRepository,
    studyDayConfigRepository: studyDayConfigRepository,
  );
});

/// Provider for list of active curricula (as enums), scoped to active profile.
final activeCurriculaProvider = FutureProvider<List<CurriculumId>>((ref) async {
  final service = ref.watch(curriculumActivationServiceProvider);
  return service.getActiveCurricula();
});

/// Stream provider for watching active curricula changes for the active profile.
///
/// Reads the underlying Firestore adapter's live stream
/// ([FirestoreCurriculumTrackRepositoryAdapter.watchActiveCurriculumIds]) and
/// projects its `storageKey`s back onto the [CurriculumId] enum, mirroring
/// [CurriculumActivationService.getActiveCurricula]'s resolution. The adapter is
/// already profile-scoped, so no profile id or database handle is read here.
final activeCurriculaStreamProvider = StreamProvider<List<CurriculumId>>((
  ref,
) {
  final adapter = ref.watch(curriculumTrackRepositoryAdapterProvider);
  return adapter.watchActiveCurriculumIds().map((List<String> storageKeys) {
    return storageKeys
        .map<CurriculumId?>((String key) {
          final matches = CurriculumId.values.where((c) => c.storageKey == key);
          if (matches.isNotEmpty) {
            return matches.first;
          }
          AppLogger.instance.warning(
            event:
                'activeCurriculaStreamProvider: unknown curriculum key: $key',
          );
          return null;
        })
        .whereType<CurriculumId>()
        .toList();
  });
});

/// Provider for checking if a specific curriculum is active for the profile.
///
/// Delegates to [FirestoreCurriculumTrackRepositoryAdapter.isActive], which is
/// itself profile-scoped (returns `null`/not-ready state as `false`), so no
/// database handle or profile id is read in this provider.
final isCurriculumActiveProvider = FutureProvider.family<bool, CurriculumId>((
  ref,
  curriculum,
) async {
  final adapter = ref.watch(curriculumTrackRepositoryAdapterProvider);
  return adapter.isActive(curriculum);
});
