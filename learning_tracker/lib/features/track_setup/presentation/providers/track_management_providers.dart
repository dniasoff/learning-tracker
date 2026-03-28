import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';

/// Stream provider for active (non-archived) tracks for the current profile.
final activeTracksProvider = StreamProvider<List<CurriculumTrack>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return db.trackDao.watchActiveTracksForProfile(profileId);
});

/// Stream provider for archived tracks for the current profile.
final archivedTracksProvider = StreamProvider<List<CurriculumTrack>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  return db.trackDao.watchArchivedTracksForProfile(profileId);
});
