import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'parent_track_providers.g.dart';

/// Provides the list of active curricula as [CurriculumId] enums
/// for the parent track management screen.
@riverpod
Future<List<CurriculumId>> parentTrackCurricula(Ref ref) async {
  final db = ref.watch(userDatabaseProvider);
  final keys = await db.activeCurriculumDao.getActiveCurricula();
  return keys
      .map<CurriculumId?>((key) {
        final matches = CurriculumId.values.where((c) => c.storageKey == key);
        return matches.isNotEmpty ? matches.first : null;
      })
      .whereType<CurriculumId>()
      .toList();
}
