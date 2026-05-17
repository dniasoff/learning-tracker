import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:learning_tracker/core/database/base_dao.dart';
import 'package:learning_tracker/core/database/tables/completions.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/logging/logger.dart';

part 'completion_dao.g.dart';

/// DAO for the completions table.
///
/// Completions are append-only: only insert operations are exposed.
/// No update or delete methods are provided to enforce immutability.
@DriftAccessor(tables: [Completions])
class CompletionDao extends DatabaseAccessor<UserDatabase>
    with
        _$CompletionDaoMixin,
        BaseDao<$CompletionsTable, Completion, UserDatabase> {
  CompletionDao(super.db);

  @override
  TableInfo<$CompletionsTable, Completion> get table => completions;

  @override
  Expression<int> idColumn($CompletionsTable t) => t.id;

  @override
  Expression<int> profileIdColumn($CompletionsTable t) => t.profileId;

  // ── Cross-profile internals (DNI-338) ───────────────────────────────────
  //
  // The public cross-profile methods were deleted in Story 25.17. Callers
  // that legitimately need cross-profile reads now go through
  // [ParentAnalyticsRepository]; its default impl delegates here. These
  // methods are intentionally named `internal…CrossProfile` so that a
  // custom lint (DNI-386) can forbid imports from outside that repository.

  Future<List<Completion>> internalGetAllCompletionsCrossProfile({
    required CrossProfileScope scope,
  }) {
    _assertCrossProfileScope(scope, 'internalGetAllCompletionsCrossProfile');
    return select(completions).get();
  }

  Future<Completion?> getCompletionById(int id) =>
      (select(completions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Completion>> internalGetCompletionsByCurriculumCrossProfile(
    String curriculumId, {
    required CrossProfileScope scope,
  }) {
    _assertCrossProfileScope(scope, 'getCompletionsByCurriculum');
    return (select(
      completions,
    )..where((t) => t.curriculumId.equals(curriculumId))).get();
  }

  Future<List<Completion>> internalGetCompletionsForContentCrossProfile(
    String sefariaRef, {
    required CrossProfileScope scope,
  }) {
    _assertCrossProfileScope(scope, 'getCompletionsForContent');
    return (select(
      completions,
    )..where((t) => t.sefariaRef.equals(sefariaRef))).get();
  }

  // ========== Profile-Scoped Queries ==========

  /// Get all completions for a specific profile.
  Future<List<Completion>> getCompletionsByProfile(int profileId) =>
      (select(completions)..where((t) => t.profileId.equals(profileId))).get();

  /// Completions for [profileId] whose [sefariaRef] is in [refs] (chunked `IN`).
  ///
  /// Used to filter today's daily tasks without loading the full completion
  /// history for the profile.
  Future<List<Completion>> getCompletionsByProfileForSefariaRefs(
    int profileId,
    Set<String> refs,
  ) async {
    if (refs.isEmpty) return [];
    final list = refs.toList();
    final out = <Completion>[];
    for (var i = 0; i < list.length; i += _kInChunkSize) {
      final end = math.min(i + _kInChunkSize, list.length);
      final part = list.sublist(i, end);
      final rows =
          await (select(completions)..where(
                (t) => t.profileId.equals(profileId) & t.sefariaRef.isIn(part),
              ))
              .get();
      out.addAll(rows);
    }
    return out;
  }

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

  /// Get the count of distinct sefariaRefs completed for a curriculum by a profile.
  ///
  /// Uses COUNT(DISTINCT sefariaRef) so that completing the same ref at
  /// multiple stages counts once — matching the "distinct ref" numerator used
  /// by [CurriculumProgressService.computeCompletionPercentage] (R5 / N6).
  Future<int> getAggregateCountByProfile(
    String curriculumId,
    int profileId,
  ) async {
    final expr = completions.sefariaRef.count(distinct: true);
    final query = selectOnly(completions)
      ..addColumns([expr])
      ..where(
        completions.curriculumId.equals(curriculumId) &
            completions.profileId.equals(profileId),
      );

    final result = await query.getSingle();
    return result.read(expr) ?? 0;
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

  /// Insert many rows in one sqlite batch (single round-trip for bulk prior).
  Future<void> insertCompletionsBatch(
    List<CompletionsCompanion> entries,
  ) async {
    if (entries.isEmpty) return;
    await db.batch((batch) {
      for (final entry in entries) {
        batch.insert(completions, entry);
      }
    });
  }

  static const int _kInChunkSize = 400;

  /// Sefaria refs in [sefariaRefs] that already have a completion for this
  /// profile, curriculum, stage, and track (for idempotent bulk prior).
  Future<Set<String>> getExistingSefariaRefsForBulkStage({
    required int profileId,
    required String curriculumId,
    required int stageId,
    required String trackType,
    required List<String> sefariaRefs,
  }) async {
    if (sefariaRefs.isEmpty) return {};
    final out = <String>{};
    for (var i = 0; i < sefariaRefs.length; i += _kInChunkSize) {
      final end = math.min(i + _kInChunkSize, sefariaRefs.length);
      final part = sefariaRefs.sublist(i, end);
      final rows =
          await (select(completions)..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculumId) &
                    t.stageId.equals(stageId) &
                    t.trackType.equals(trackType) &
                    t.sefariaRef.isIn(part),
              ))
              .get();
      for (final r in rows) {
        out.add(r.sefariaRef);
      }
    }
    return out;
  }

  /// Load completion rows for the given keys (chunked `IN` queries).
  Future<List<Completion>> getCompletionsForRefsBulkStage({
    required int profileId,
    required String curriculumId,
    required int stageId,
    required String trackType,
    required List<String> sefariaRefs,
  }) async {
    if (sefariaRefs.isEmpty) return [];
    final out = <Completion>[];
    for (var i = 0; i < sefariaRefs.length; i += _kInChunkSize) {
      final end = math.min(i + _kInChunkSize, sefariaRefs.length);
      final part = sefariaRefs.sublist(i, end);
      final rows =
          await (select(completions)..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculumId) &
                    t.stageId.equals(stageId) &
                    t.trackType.equals(trackType) &
                    t.sefariaRef.isIn(part),
              ))
              .get();
      out.addAll(rows);
    }
    return out;
  }

  /// Cross-profile: completions in [start]..[end] inclusive.
  Future<List<Completion>> internalGetCompletionsByDateRangeCrossProfile(
    DateTime start,
    DateTime end, {
    required CrossProfileScope scope,
  }) {
    _assertCrossProfileScope(scope, 'getCompletionsByDateRange');
    return (select(completions)..where(
          (t) =>
              t.completedAt.isBiggerOrEqualValue(start) &
              t.completedAt.isSmallerOrEqualValue(end),
        ))
        .get();
  }

  /// Cross-profile: any completions in [start]..[end] inclusive.
  Future<bool> internalHasCompletionsInDateRangeCrossProfile(
    DateTime start,
    DateTime end, {
    required CrossProfileScope scope,
  }) async {
    _assertCrossProfileScope(
      scope,
      'internalHasCompletionsInDateRangeCrossProfile',
    );
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

  /// Cross-profile: completion count breakdown by track type.
  Future<Map<String, int>> internalGetTrackBreakdownCrossProfile(
    String curriculumId, {
    required CrossProfileScope scope,
  }) async {
    _assertCrossProfileScope(scope, 'internalGetTrackBreakdownCrossProfile');
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

  /// Cross-profile: total completion count for [curriculumId].
  Future<int> internalGetAggregateCountCrossProfile(
    String curriculumId, {
    required CrossProfileScope scope,
  }) async {
    _assertCrossProfileScope(scope, 'internalGetAggregateCountCrossProfile');
    final query = selectOnly(completions)
      ..addColumns([completions.id.count()])
      ..where(completions.curriculumId.equals(curriculumId));

    final result = await query.getSingle();
    return result.read(completions.id.count()) ?? 0;
  }

  // ========== Review Count Queries (Story 16.4) ==========

  /// Get total review count per item for a curriculum and profile.
  /// Returns Map<sefariaRef, totalCount> via GROUP BY. (AC-2, AC-3)
  Future<Map<String, int>> getReviewCountsByItem(
    String curriculumId,
    int profileId,
  ) async {
    final query = selectOnly(completions)
      ..addColumns([completions.sefariaRef, completions.id.count()])
      ..where(
        completions.curriculumId.equals(curriculumId) &
            completions.profileId.equals(profileId),
      )
      ..groupBy([completions.sefariaRef]);

    final results = await query.get();
    final counts = <String, int>{};
    for (final row in results) {
      final ref = row.read(completions.sefariaRef);
      final count = row.read(completions.id.count());
      if (ref != null && count != null) {
        counts[ref] = count;
      }
    }
    return counts;
  }

  /// Get per-stage breakdown for a single item. (AC-1)
  /// Returns Map<stageId, count> via GROUP BY.
  Future<Map<int, int>> getStageBreakdownByItem(
    String curriculumId,
    String sefariaRef,
    int profileId,
  ) async {
    final query = selectOnly(completions)
      ..addColumns([completions.stageId, completions.id.count()])
      ..where(
        completions.curriculumId.equals(curriculumId) &
            completions.sefariaRef.equals(sefariaRef) &
            completions.profileId.equals(profileId),
      )
      ..groupBy([completions.stageId]);

    final results = await query.get();
    final breakdown = <int, int>{};
    for (final row in results) {
      final stageId = row.read(completions.stageId);
      final count = row.read(completions.id.count());
      if (stageId != null && count != null) {
        breakdown[stageId] = count;
      }
    }
    return breakdown;
  }

  /// Get per-item stage breakdown for all items in a curriculum. (AC-1, AC-3)
  /// Returns Map<sefariaRef, Map<stageId, count>> via GROUP BY.
  Future<Map<String, Map<int, int>>> getReviewCountsWithStageBreakdown(
    String curriculumId,
    int profileId,
  ) async {
    final query = selectOnly(completions)
      ..addColumns([
        completions.sefariaRef,
        completions.stageId,
        completions.id.count(),
      ])
      ..where(
        completions.curriculumId.equals(curriculumId) &
            completions.profileId.equals(profileId),
      )
      ..groupBy([completions.sefariaRef, completions.stageId]);

    final results = await query.get();
    final nested = <String, Map<int, int>>{};
    for (final row in results) {
      final ref = row.read(completions.sefariaRef);
      final stageId = row.read(completions.stageId);
      final count = row.read(completions.id.count());
      if (ref != null && stageId != null && count != null) {
        nested.putIfAbsent(ref, () => {})[stageId] = count;
      }
    }
    return nested;
  }

  // ========== Track-Scoped Queries (Story 20.2) ==========

  /// Get all completions for a specific track.
  Future<List<Completion>> getCompletionsByTrack(int trackId) =>
      (select(completions)..where((t) => t.trackId.equals(trackId))).get();

  /// Get completions for a track scoped to a specific profile.
  Future<List<Completion>> getCompletionsByTrackAndProfile(
    int trackId,
    int profileId,
  ) =>
      (select(completions)..where(
            (t) => t.trackId.equals(trackId) & t.profileId.equals(profileId),
          ))
          .get();

  /// Get completion count for a track scoped to a specific profile.
  Future<int> getAggregateCountByTrack(int trackId, int profileId) async {
    final query = selectOnly(completions)
      ..addColumns([completions.id.count()])
      ..where(
        completions.trackId.equals(trackId) &
            completions.profileId.equals(profileId),
      );
    final result = await query.getSingle();
    return result.read(completions.id.count()) ?? 0;
  }

  /// Check if a completion exists scoped to a specific track.
  Future<bool> completionExistsByTrack({
    required int trackId,
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required DateTime completedAt,
  }) async {
    final result =
        await (select(completions)
              ..where(
                (t) =>
                    t.trackId.equals(trackId) &
                    t.curriculumId.equals(curriculumId) &
                    t.sefariaRef.equals(sefariaRef) &
                    t.stageId.equals(stageId) &
                    t.completedAt.equals(completedAt),
              )
              ..limit(1))
            .get();
    return result.isNotEmpty;
  }

  /// Get completions within a date range for a specific track and profile.
  Future<List<Completion>> getCompletionsByDateRangeAndTrack(
    DateTime start,
    DateTime end,
    int trackId,
    int profileId,
  ) =>
      (select(completions)..where(
            (t) =>
                t.completedAt.isBiggerOrEqualValue(start) &
                t.completedAt.isSmallerOrEqualValue(end) &
                t.trackId.equals(trackId) &
                t.profileId.equals(profileId),
          ))
          .get();

  /// Get review counts per item for a track.
  Future<Map<String, int>> getReviewCountsByItemAndTrack(
    int trackId,
    String curriculumId,
    int profileId,
  ) async {
    final query = selectOnly(completions)
      ..addColumns([completions.sefariaRef, completions.id.count()])
      ..where(
        completions.trackId.equals(trackId) &
            completions.curriculumId.equals(curriculumId) &
            completions.profileId.equals(profileId),
      )
      ..groupBy([completions.sefariaRef]);

    final results = await query.get();
    final counts = <String, int>{};
    for (final row in results) {
      final ref = row.read(completions.sefariaRef);
      final count = row.read(completions.id.count());
      if (ref != null && count != null) {
        counts[ref] = count;
      }
    }
    return counts;
  }

  /// Get per-stage breakdown for a single item scoped to a track.
  Future<Map<int, int>> getStageBreakdownByItemAndTrack(
    int trackId,
    String curriculumId,
    String sefariaRef,
    int profileId,
  ) async {
    final query = selectOnly(completions)
      ..addColumns([completions.stageId, completions.id.count()])
      ..where(
        completions.trackId.equals(trackId) &
            completions.curriculumId.equals(curriculumId) &
            completions.sefariaRef.equals(sefariaRef) &
            completions.profileId.equals(profileId),
      )
      ..groupBy([completions.stageId]);

    final results = await query.get();
    final breakdown = <int, int>{};
    for (final row in results) {
      final stageId = row.read(completions.stageId);
      final count = row.read(completions.id.count());
      if (stageId != null && count != null) {
        breakdown[stageId] = count;
      }
    }
    return breakdown;
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

  // ========== Cross-Profile Scope Guard (DNI-321) ==========

  /// Asserts that [scope] is provided for every cross-profile read.
  ///
  /// In debug builds an [AssertionError] is thrown and the event is logged.
  /// In release builds only the structured warning breadcrumb is written.
  void _assertCrossProfileScope(CrossProfileScope scope, String method) {
    // ignore: unnecessary_null_comparison — future-proofs against nullable callers
    assert(scope != null, 'CrossProfileScope must be provided for $method');
    final log = AppLogger(AppLogger.instance);
    if (kDebugMode) {
      // Stable caller hash: method name → identity integer (no stack-unwinding
      // needed; real stack hash would require dart:developer which is
      // unavailable in release).
      final callerHash = method.hashCode & 0xFFFF;
      log.debug(
        event: 'cross_profile_read',
        fields: {
          'method': method,
          'scope': scope.name,
          'callerHash': callerHash,
        },
      );
    } else {
      // In release mode log a structured breadcrumb as a warning so it surfaces
      // through AppLogger -> Talker -> Crashlytics breadcrumbs.
      log.warning(
        event: 'cross_profile_read',
        fields: {'method': method, 'scope': scope.name},
      );
    }
  }
}
