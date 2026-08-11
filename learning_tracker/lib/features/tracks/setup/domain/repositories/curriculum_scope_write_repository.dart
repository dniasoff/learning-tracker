import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Abstract write-side repository for a curriculum's content-scope
/// selection (which sedarim/masechtos/perakim are in scope for a track --
/// an empty/absent selection means the whole curriculum).
///
/// Read-only access is a separate, not-yet-built concern (no reader existed
/// as of this interface's introduction — every current consumer of scope
/// data reads through other feature-scoped paths). This is the write-capable
/// seam `TrackCreationService` (features/tracks/setup/domain/services/,
/// forbidden by AD-23/AD-28 from reaching the data ring directly) needs for
/// the add-track flow's scope-selection step.
abstract class CurriculumScopeWriteRepository {
  /// Clears every scope selection for [curriculumId] (= track the entire
  /// curriculum).
  Future<void> clearScopes(CurriculumId curriculumId);

  /// Inserts [scopes] (level + value pairs, potentially spanning multiple
  /// distinct levels) for [curriculumId]. Additive — call [clearScopes]
  /// first for full-replace semantics (mirrors the old Drift
  /// clear-then-insert pattern).
  Future<void> insertScopes({
    required CurriculumId curriculumId,
    required List<({int level, String value})> scopes,
  });
}
