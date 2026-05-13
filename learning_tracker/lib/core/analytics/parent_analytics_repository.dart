import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';

/// Sole public surface for queries that legitimately read completions across
/// multiple profiles (parent analytics, full data export, sync diff,
/// device restore).
///
/// Direct cross-profile reads from feature code are forbidden — they must
/// go through this interface so the business reason is explicit
/// (DNI-338, Story 25.17; supersedes Story 24.6 scope assertions).
///
/// A custom lint will be added in DNI-386 to forbid imports of the internal
/// cross-profile DAO methods outside [ParentAnalyticsRepositoryImpl].
abstract class ParentAnalyticsRepository {
  /// All completions on the device, across every profile.
  Future<List<Completion>> getAllCompletions({
    required CrossProfileScope scope,
  });

  /// All completions for [curriculumId], across every profile.
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId, {
    required CrossProfileScope scope,
  });

  /// All completions for [sefariaRef], across every profile.
  Future<List<Completion>> getCompletionsForContent(
    String sefariaRef, {
    required CrossProfileScope scope,
  });

  /// All completions in [start]..[end] inclusive, across every profile.
  Future<List<Completion>> getCompletionsByDateRange(
    DateTime start,
    DateTime end, {
    required CrossProfileScope scope,
  });

  /// Whether any completions exist in [start]..[end] inclusive, across every
  /// profile.
  Future<bool> hasCompletionsInDateRange(
    DateTime start,
    DateTime end, {
    required CrossProfileScope scope,
  });

  /// Count of completions for [curriculumId], across every profile.
  Future<int> getAggregateCount(
    String curriculumId, {
    required CrossProfileScope scope,
  });

  /// Track-type breakdown for [curriculumId], across every profile.
  Future<Map<String, int>> getTrackBreakdown(
    String curriculumId, {
    required CrossProfileScope scope,
  });
}

/// Default implementation that delegates to the renamed-internal
/// cross-profile DAO methods on [CompletionDao].
class ParentAnalyticsRepositoryImpl implements ParentAnalyticsRepository {
  ParentAnalyticsRepositoryImpl(this._db);

  final UserDatabase _db;

  @override
  Future<List<Completion>> getAllCompletions({
    required CrossProfileScope scope,
  }) =>
      _db.completionDao.internalGetAllCompletionsCrossProfile(scope: scope);

  @override
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId, {
    required CrossProfileScope scope,
  }) =>
      _db.completionDao.internalGetCompletionsByCurriculumCrossProfile(
        curriculumId,
        scope: scope,
      );

  @override
  Future<List<Completion>> getCompletionsForContent(
    String sefariaRef, {
    required CrossProfileScope scope,
  }) =>
      _db.completionDao.internalGetCompletionsForContentCrossProfile(
        sefariaRef,
        scope: scope,
      );

  @override
  Future<List<Completion>> getCompletionsByDateRange(
    DateTime start,
    DateTime end, {
    required CrossProfileScope scope,
  }) =>
      _db.completionDao.internalGetCompletionsByDateRangeCrossProfile(
        start,
        end,
        scope: scope,
      );

  @override
  Future<bool> hasCompletionsInDateRange(
    DateTime start,
    DateTime end, {
    required CrossProfileScope scope,
  }) =>
      _db.completionDao.internalHasCompletionsInDateRangeCrossProfile(
        start,
        end,
        scope: scope,
      );

  @override
  Future<int> getAggregateCount(
    String curriculumId, {
    required CrossProfileScope scope,
  }) =>
      _db.completionDao.internalGetAggregateCountCrossProfile(
        curriculumId,
        scope: scope,
      );

  @override
  Future<Map<String, int>> getTrackBreakdown(
    String curriculumId, {
    required CrossProfileScope scope,
  }) =>
      _db.completionDao.internalGetTrackBreakdownCrossProfile(
        curriculumId,
        scope: scope,
      );
}
