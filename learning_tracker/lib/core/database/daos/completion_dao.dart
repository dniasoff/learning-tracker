import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/tables/completions.dart';

part 'completion_dao.g.dart';

/// DAO for the completions table.
///
/// Completions are append-only: only insert operations are exposed.
/// No update or delete methods are provided to enforce immutability.
@DriftAccessor(tables: [Completions])
class CompletionDao extends DatabaseAccessor<AppDatabase>
    with _$CompletionDaoMixin {
  CompletionDao(super.db);

  Future<List<Completion>> getAllCompletions() => select(completions).get();

  Future<Completion?> getCompletionById(int id) =>
      (select(completions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Completion>> getCompletionsByCurriculum(String curriculumId) =>
      (select(
        completions,
      )..where((t) => t.curriculumId.equals(curriculumId))).get();

  Future<List<Completion>> getCompletionsForContent(String sefariaRef) =>
      (select(
        completions,
      )..where((t) => t.sefariaRef.equals(sefariaRef))).get();

  // ========== Profile-Scoped Queries ==========

  /// Get all completions for a specific profile.
  Future<List<Completion>> getCompletionsByProfile(int profileId) =>
      (select(completions)..where((t) => t.profileId.equals(profileId))).get();

  /// Get completions for a curriculum scoped to a specific profile.
  Future<List<Completion>> getCompletionsByCurriculumAndProfile(
    String curriculumId,
    int profileId,
  ) =>
      (select(completions)..where(
            (t) =>
                t.curriculumId.equals(curriculumId) &
                t.profileId.equals(profileId),
          ))
          .get();

  /// Get completions for a content item scoped to a specific profile.
  Future<List<Completion>> getCompletionsForContentAndProfile(
    String sefariaRef,
    int profileId,
  ) =>
      (select(completions)..where(
            (t) =>
                t.sefariaRef.equals(sefariaRef) & t.profileId.equals(profileId),
          ))
          .get();

  /// Get completion count for a curriculum scoped to a specific profile.
  Future<int> getAggregateCountByProfile(
    String curriculumId,
    int profileId,
  ) async {
    final query = selectOnly(completions)
      ..addColumns([completions.id.count()])
      ..where(
        completions.curriculumId.equals(curriculumId) &
            completions.profileId.equals(profileId),
      );

    final result = await query.getSingle();
    return result.read(completions.id.count()) ?? 0;
  }

  /// Get track breakdown for a curriculum scoped to a specific profile.
  Future<Map<String, int>> getTrackBreakdownByProfile(
    String curriculumId,
    int profileId,
  ) async {
    final query = selectOnly(completions)
      ..addColumns([completions.trackType, completions.id.count()])
      ..where(
        completions.curriculumId.equals(curriculumId) &
            completions.profileId.equals(profileId),
      )
      ..groupBy([completions.trackType]);

    final results = await query.get();

    final breakdown = <String, int>{};
    for (final row in results) {
      final trackType = row.read(completions.trackType);
      final count = row.read(completions.id.count());
      if (trackType != null && count != null) {
        breakdown[trackType] = count;
      }
    }

    return breakdown;
  }

  /// Check if a completion exists for a specific profile.
  Future<bool> completionExistsByProfile({
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
    required DateTime completedAt,
    required int profileId,
  }) async {
    final result =
        await (select(completions)
              ..where(
                (t) =>
                    t.curriculumId.equals(curriculumId) &
                    t.sefariaRef.equals(sefariaRef) &
                    t.stageId.equals(stageId) &
                    t.trackType.equals(trackType) &
                    t.completedAt.equals(completedAt) &
                    t.profileId.equals(profileId),
              )
              ..limit(1))
            .get();
    return result.isNotEmpty;
  }

  /// Get completions within a date range scoped to a specific profile.
  Future<List<Completion>> getCompletionsByDateRangeAndProfile(
    DateTime start,
    DateTime end,
    int profileId,
  ) =>
      (select(completions)..where(
            (t) =>
                t.completedAt.isBiggerOrEqualValue(start) &
                t.completedAt.isSmallerOrEqualValue(end) &
                t.profileId.equals(profileId),
          ))
          .get();

  /// Check if any completions exist within a date range for a specific profile.
  Future<bool> hasCompletionsInDateRangeByProfile(
    DateTime start,
    DateTime end,
    int profileId,
  ) async {
    final result =
        await (select(completions)
              ..where(
                (t) =>
                    t.completedAt.isBiggerOrEqualValue(start) &
                    t.completedAt.isSmallerOrEqualValue(end) &
                    t.profileId.equals(profileId),
              )
              ..limit(1))
            .get();
    return result.isNotEmpty;
  }

  /// Insert a completion record. This is the only write operation allowed.
  Future<int> insertCompletion(CompletionsCompanion entry) =>
      into(completions).insert(entry);

  /// Get completions within a date range.
  Future<List<Completion>> getCompletionsByDateRange(
    DateTime start,
    DateTime end,
  ) =>
      (select(completions)..where(
            (t) =>
                t.completedAt.isBiggerOrEqualValue(start) &
                t.completedAt.isSmallerOrEqualValue(end),
          ))
          .get();

  /// Check if any completions exist within a date range.
  Future<bool> hasCompletionsInDateRange(DateTime start, DateTime end) async {
    final result =
        await (select(completions)
              ..where(
                (t) =>
                    t.completedAt.isBiggerOrEqualValue(start) &
                    t.completedAt.isSmallerOrEqualValue(end),
              )
              ..limit(1))
            .get();
    return result.isNotEmpty;
  }

  /// Check if a completion already exists by composite key.
  ///
  /// Used during sync merge to avoid inserting duplicates (additive merge per D4).
  Future<bool> completionExists({
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
    required DateTime completedAt,
  }) async {
    final result =
        await (select(completions)
              ..where(
                (t) =>
                    t.curriculumId.equals(curriculumId) &
                    t.sefariaRef.equals(sefariaRef) &
                    t.stageId.equals(stageId) &
                    t.trackType.equals(trackType) &
                    t.completedAt.equals(completedAt),
              )
              ..limit(1))
            .get();
    return result.isNotEmpty;
  }

  /// Get completion count breakdown by track type for a curriculum.
  ///
  /// Returns a map of track type keys to completion counts.
  /// Includes counts from deactivated tracks (historical data preserved).
  Future<Map<String, int>> getTrackBreakdown(String curriculumId) async {
    final query = selectOnly(completions)
      ..addColumns([completions.trackType, completions.id.count()])
      ..where(completions.curriculumId.equals(curriculumId))
      ..groupBy([completions.trackType]);

    final results = await query.get();

    final breakdown = <String, int>{};
    for (final row in results) {
      final trackType = row.read(completions.trackType);
      final count = row.read(completions.id.count());
      if (trackType != null && count != null) {
        breakdown[trackType] = count;
      }
    }

    return breakdown;
  }

  /// Get total completion count for a curriculum across all tracks.
  ///
  /// Returns the sum of all completions regardless of track type.
  Future<int> getAggregateCount(String curriculumId) async {
    final query = selectOnly(completions)
      ..addColumns([completions.id.count()])
      ..where(completions.curriculumId.equals(curriculumId));

    final result = await query.getSingle();
    return result.read(completions.id.count()) ?? 0;
  }

  /// Returns true if any completions reference the given stage ID.
  Future<bool> hasCompletionsForStage(int stageId) async {
    final result =
        await (select(completions)
              ..where((t) => t.stageId.equals(stageId))
              ..limit(1))
            .get();
    return result.isNotEmpty;
  }
}
