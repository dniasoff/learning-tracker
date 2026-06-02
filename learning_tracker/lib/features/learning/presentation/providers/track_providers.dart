import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'track_providers.g.dart';

/// Provides the track repository.
@riverpod
TrackRepository trackRepository(Ref ref) {
  final database = ref.watch(userDatabaseProvider);
  final syncFacade = ref.watch(syncWriteFacadeProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  return TrackRepositoryImpl(
    database: database,
    syncEngine: syncFacade,
    activeProfileId: profileId,
  );
}
