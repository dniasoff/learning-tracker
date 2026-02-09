import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';

part 'track_providers.g.dart';

/// Provides the track repository.
@riverpod
TrackRepository trackRepository(Ref ref) {
  final database = ref.watch(appDatabaseProvider);
  final syncEngine = ref.watch(syncEngineProvider);

  return TrackRepositoryImpl(
    database: database,
    syncEngine: syncEngine,
  );
}

/// Provides the list of active tracks for a specific curriculum.
@riverpod
Future<List<TrackType>> activeTracks(
  Ref ref,
  CurriculumId curriculumId,
) async {
  final repository = ref.watch(trackRepositoryProvider);
  return repository.getActiveTracks(curriculumId);
}

/// Checks if a specific track is active for a curriculum.
@riverpod
Future<bool> isTrackActive(
  Ref ref,
  CurriculumId curriculumId,
  TrackType trackType,
) async {
  final repository = ref.watch(trackRepositoryProvider);
  return repository.isTrackActive(curriculumId, trackType);
}
