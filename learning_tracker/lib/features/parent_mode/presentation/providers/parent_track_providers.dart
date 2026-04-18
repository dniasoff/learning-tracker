import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'parent_track_providers.g.dart';

/// Provides the list of active curricula as [CurriculumId] enums for the
/// currently active profile. Scoped so each profile (parent, child, etc.)
/// sees only its own curricula in parent-mode track management.
@riverpod
Future<List<CurriculumId>> parentTrackCurricula(Ref ref) async {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final keys = await db.activeCurriculumDao.getActiveCurriculaByProfile(
    profileId,
  );
  return keys
      .map<CurriculumId?>((key) {
        final matches = CurriculumId.values.where((c) => c.storageKey == key);
        return matches.isNotEmpty ? matches.first : null;
      })
      .whereType<CurriculumId>()
      .toList();
}
