import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/database/views/completions_view.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/logging/logger.dart';

part 'completion_dao.g.dart';

/// DAO for the completions view (C1).
///
/// All reads are served from [CompletionsView] — a Drift view over
/// [CompletionEvents] filtered by `purgedAt IS NULL`.  The old `completions`
/// table remains in the schema for backward-compatibility with legacy rows but
/// is no longer written to after schema v20.
///
/// Write methods ([insertCompletion], [insertCompletionsBatch]) have been
/// removed.  New completions are written exclusively through
/// [CompletionWriter] which inserts into [CompletionEvents].
@DriftAccessor(views: [CompletionsView])
class CompletionDao extends DatabaseAccessor<UserDatabase>
    with _$CompletionDaoMixin {
  CompletionDao(super.db);

  // ── Private mapping helper ──────────────────────────────────────────────────

  /// Maps a [CompletionsViewData] row to a [Completion] object so callers
  /// keep their existing return types after the completions-table → view
  /// migration (C1).
  ///
  /// `completedAt` is taken from `eventTimestamp` (same instant, different
  /// column name).  `points` defaults to 0 — [PointsService] recalculates
  /// from [PointConfig] rules independently.  `derivedFromEvents` is always
  /// `true` for view rows.
  Completion _fromView(CompletionsViewData v) => Completion(
    id: v.id,
    profileId: v.profileId,
    curriculumId: v.curriculumId,
    sefariaRef: v.sefariaRef,
    stageId: v.stageId,
    trackType: v.trackType,
    trackId: v.trackId ?? 0,
    completedAt: v.eventTimestamp,
    points: v.points,
    derivedFromEvents: true,
  );

  // ── Cross-profile internals (DNI-338) ───────────────────────────────────
  //
  // The public cross-profile methods were deleted in Story 25.17. Callers
  // that legitimately need cross-profile reads now go through
  // [ParentAnalyticsRepository]; its default impl delegates here. These
  // methods are intentionally named `internal…CrossProfile` so that a
  // custom lint (DNI-386) can forbid imports from outside that repository.

  Future<List<Completion>> internalGetAllCompletionsCrossProfile({
    required CrossProfileScope scope,
  }) async {
    _assertCrossProfileScope(scope, 'internalGetAllCompletionsCrossProfile');
    final rows = await select(completionsView).get();
    return rows.map(_fromView).toList();
  }

  Future<Completion?> getCompletionById(int id) async {
    final row = await (select(
      completionsView,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromView(row);
  }

  Future<List<Completion>> internalGetCompletionsByCurriculumCrossProfile(
    String curriculumId, {
    required CrossProfileScope scope,
  }) async {
    _assertCrossProfileScope(scope, 'getCompletionsByCurriculum');
    final rows = await (select(
      completionsView,
    )..where((t) => t.curriculumId.equals(curriculumId))).get();
    return rows.map(_fromView).toList();
  }

  Future<List<Completion>> internalGetCompletionsForContentCrossProfile(
    String sefariaRef, {
    required CrossProfileScope scope,
  }) async {
    _assertCrossProfileScope(scope, 'getCompletionsForContent');
    final rows = await (select(
      completionsView,
    )..where((t) => t.sefariaRef.equals(sefariaRef))).get();
    return rows.map(_fromView).toList();
  }

  // ========== Profile-Scoped Queries ==========

  /// Get all completions for a specific profile.
  Future<List<Completion>> getCompletionsByProfile(int profileId) async {
    final rows = await (select(
      completionsView,
    )..where((t) => t.profileId.equals(profileId))).get();
    return rows.map(_fromView).toList();
  }

  /// Track-only completions for [profileId] — excludes the bulk-mark sentinel
  /// (trackId = 0) at the SQL layer so that lifetime bulk-marked items do not
  /// inflate the ITEMS LEARNED / TASKS DONE counters on the Progress screen.
  Future<List<Completion>> getTrackOnlyCompletionsByProfile(
    int profileId,
  ) async {
    final rows =
        await (select(completionsView)..where(
              (t) => t.profileId.equals(profileId) & t.trackId.isNotValue(0),
            ))
            .get();
    return rows.map(_fromView).toList();
  }

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
          await (select(completionsView)..where(
                (t) => t.profileId.equals(profileId) & t.sefariaRef.isIn(part),
              ))
              .get();
      out.addAll(rows.map(_fromView));
    }
    return out;
  }

  /// Get completions for a curriculum scoped to a specific profile.
  Future<List<Completion>> getCompletionsByCurriculumAndProfile(
    String curriculumId,
    int profileId,
  ) async {
    final rows =
        await (select(completionsView)..where(
              (t) =>
                  t.curriculumId.equals(curriculumId) &
                  t.profileId.equals(profileId),
            ))
            .get();
    return rows.map(_fromView).toList();
  }

  /// Get completions for a content item scoped to a specific profile.
  Future<List<Completion>> getCompletionsForContentAndProfile(
    String sefariaRef,
    int profileId,
  ) async {
    final rows =
        await (select(completionsView)..where(
              (t) =>
                  t.sefariaRef.equals(sefariaRef) &
                  t.profileId.equals(profileId),
            ))
            .get();
    return rows.map(_fromView).toList();
  }

  /// Get the count of distinct sefariaRefs completed for a curriculum by a profile.
  ///
  /// Uses COUNT(DISTINCT sefariaRef) so that completing the same ref at
  /// multiple stages counts once — matching the "distinct ref" numerator used
  /// by [CurriculumProgressService.computeCompletionPercentage] (R5 / N6).
  Future<int> getAggregateCountByProfile(
    String curriculumId,
    int profileId,
  ) async {
    final expr = completionsView.sefariaRef.count(distinct: true);
    final query = selectOnly(completionsView)
      ..addColumns([expr])
      ..where(
        completionsView.curriculumId.equals(curriculumId) &
            completionsView.profileId.equals(profileId),
      );

    final result = await query.getSingle();
    return result.read(expr) ?? 0;
  }

  /// Get track breakdown for a curriculum scoped to a specific profile.
  Future<Map<String, int>> getTrackBreakdownByProfile(
    String curriculumId,
    int profileId,
  ) async {
    final query = selectOnly(completionsView)
      ..addColumns([completionsView.trackType, completionsView.id.count()])
      ..where(
        completionsView.curriculumId.equals(curriculumId) &
            completionsView.profileId.equals(profileId),
      )
      ..groupBy([completionsView.trackType]);

    final results = await query.get();

    final breakdown = <String, int>{};
    for (final row in results) {
      final trackType = row.read(completionsView.trackType);
      final count = row.read(completionsView.id.count());
      if (trackType != null && count != null) {
        breakdown[trackType] = count;
      }
    }

    return breakdown;
  }

  /// Check if a completion exists for a specific profile.
  ///
  /// Queries [completionEvents] directly (not [completionsView]) so that
  /// C3-purged rows are also detected. Querying only the view would return
  /// `false` for purged rows, causing the sync engine to attempt a redundant
  /// re-insert on every pull — the INSERT OR IGNORE would silently no-op
  /// (UNIQUE key exists) but the insertedCount metric would be inflated.
  Future<bool> completionExistsByProfile({
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
    required DateTime completedAt,
    required int profileId,
  }) async {
    final result =
        await (select(completionEvents)
              ..where(
                (t) =>
                    t.curriculumId.equals(curriculumId) &
                    t.sefariaRef.equals(sefariaRef) &
                    t.stageId.equals(stageId) &
                    t.trackType.equals(trackType) &
                    t.eventTimestamp.equals(completedAt) &
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
  ) async {
    final rows =
        await (select(completionsView)..where(
              (t) =>
                  t.eventTimestamp.isBiggerOrEqualValue(start) &
                  t.eventTimestamp.isSmallerOrEqualValue(end) &
                  t.profileId.equals(profileId),
            ))
            .get();
    return rows.map(_fromView).toList();
  }

  /// Check if any completions exist within a date range for a specific profile.
  Future<bool> hasCompletionsInDateRangeByProfile(
    DateTime start,
    DateTime end,
    int profileId,
  ) async {
    final result =
        await (select(completionsView)
              ..where(
                (t) =>
                    t.eventTimestamp.isBiggerOrEqualValue(start) &
                    t.eventTimestamp.isSmallerOrEqualValue(end) &
                    t.profileId.equals(profileId),
              )
              ..limit(1))
            .get();
    return result.isNotEmpty;
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
          await (select(completionsView)..where(
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
          await (select(completionsView)..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculumId) &
                    t.stageId.equals(stageId) &
                    t.trackType.equals(trackType) &
                    t.sefariaRef.isIn(part),
              ))
              .get();
      out.addAll(rows.map(_fromView));
    }
    return out;
  }

  /// Cross-profile: completions in [start]..[end] inclusive.
  Future<List<Completion>> internalGetCompletionsByDateRangeCrossProfile(
    DateTime start,
    DateTime end, {
    required CrossProfileScope scope,
  }) async {
    _assertCrossProfileScope(scope, 'getCompletionsByDateRange');
    final rows =
        await (select(completionsView)..where(
              (t) =>
                  t.eventTimestamp.isBiggerOrEqualValue(start) &
                  t.eventTimestamp.isSmallerOrEqualValue(end),
            ))
            .get();
    return rows.map(_fromView).toList();
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
        await (select(completionsView)
              ..where(
                (t) =>
                    t.eventTimestamp.isBiggerOrEqualValue(start) &
                    t.eventTimestamp.isSmallerOrEqualValue(end),
              )
              ..limit(1))
            .get();
    return result.isNotEmpty;
  }

  /// Check if a completion already exists by composite key.
  ///
  /// Used during sync merge to avoid inserting duplicates (additive merge per D4).
  /// Queries [completionEvents] directly (not [completionsView]) so that C3-purged
  /// rows are also considered existing — the INSERT OR IGNORE UNIQUE constraint
  /// would block a re-insert anyway, and querying the view would falsely report
  /// "not found" for purged rows on every sync pull.
  Future<bool> completionExists({
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
    required DateTime completedAt,
  }) async {
    final result =
        await (select(completionEvents)
              ..where(
                (t) =>
                    t.curriculumId.equals(curriculumId) &
                    t.sefariaRef.equals(sefariaRef) &
                    t.stageId.equals(stageId) &
                    t.trackType.equals(trackType) &
                    t.eventTimestamp.equals(completedAt),
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
    final query = selectOnly(completionsView)
      ..addColumns([completionsView.trackType, completionsView.id.count()])
      ..where(completionsView.curriculumId.equals(curriculumId))
      ..groupBy([completionsView.trackType]);

    final results = await query.get();

    final breakdown = <String, int>{};
    for (final row in results) {
      final trackType = row.read(completionsView.trackType);
      final count = row.read(completionsView.id.count());
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
    final query = selectOnly(completionsView)
      ..addColumns([completionsView.id.count()])
      ..where(completionsView.curriculumId.equals(curriculumId));

    final result = await query.getSingle();
    return result.read(completionsView.id.count()) ?? 0;
  }

  // ========== Review Count Queries (Story 16.4) ==========

  /// Get total review count per item for a curriculum and profile.
  /// Returns Map<sefariaRef, totalCount> via GROUP BY. (AC-2, AC-3)
  Future<Map<String, int>> getReviewCountsByItem(
    String curriculumId,
    int profileId,
  ) async {
    final query = selectOnly(completionsView)
      ..addColumns([completionsView.sefariaRef, completionsView.id.count()])
      ..where(
        completionsView.curriculumId.equals(curriculumId) &
            completionsView.profileId.equals(profileId),
      )
      ..groupBy([completionsView.sefariaRef]);

    final results = await query.get();
    final counts = <String, int>{};
    for (final row in results) {
      final ref = row.read(completionsView.sefariaRef);
      final count = row.read(completionsView.id.count());
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
    final query = selectOnly(completionsView)
      ..addColumns([completionsView.stageId, completionsView.id.count()])
      ..where(
        completionsView.curriculumId.equals(curriculumId) &
            completionsView.sefariaRef.equals(sefariaRef) &
            completionsView.profileId.equals(profileId),
      )
      ..groupBy([completionsView.stageId]);

    final results = await query.get();
    final breakdown = <int, int>{};
    for (final row in results) {
      final stageId = row.read(completionsView.stageId);
      final count = row.read(completionsView.id.count());
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
    final query = selectOnly(completionsView)
      ..addColumns([
        completionsView.sefariaRef,
        completionsView.stageId,
        completionsView.id.count(),
      ])
      ..where(
        completionsView.curriculumId.equals(curriculumId) &
            completionsView.profileId.equals(profileId),
      )
      ..groupBy([completionsView.sefariaRef, completionsView.stageId]);

    final results = await query.get();
    final nested = <String, Map<int, int>>{};
    for (final row in results) {
      final ref = row.read(completionsView.sefariaRef);
      final stageId = row.read(completionsView.stageId);
      final count = row.read(completionsView.id.count());
      if (ref != null && stageId != null && count != null) {
        nested.putIfAbsent(ref, () => {})[stageId] = count;
      }
    }
    return nested;
  }

  // ========== Track-Scoped Queries (Story 20.2) ==========

  /// Get all completions for a specific track.
  Future<List<Completion>> getCompletionsByTrack(int trackId) async {
    final rows = await (select(
      completionsView,
    )..where((t) => t.trackId.equals(trackId))).get();
    return rows.map(_fromView).toList();
  }

  /// Get completions for a track scoped to a specific profile.
  Future<List<Completion>> getCompletionsByTrackAndProfile(
    int trackId,
    int profileId,
  ) async {
    final rows =
        await (select(completionsView)..where(
              (t) => t.trackId.equals(trackId) & t.profileId.equals(profileId),
            ))
            .get();
    return rows.map(_fromView).toList();
  }

  /// Get completions for a track on or after [since] — the current-session
  /// boundary. Used to compute current-cycle progress independently of
  /// completions accumulated in previous learning sessions (before a restore).
  Future<List<Completion>> getCompletionsByTrackAndProfileSince(
    int trackId,
    int profileId,
    DateTime since,
  ) async {
    final rows =
        await (select(completionsView)..where(
              (t) =>
                  t.trackId.equals(trackId) &
                  t.profileId.equals(profileId) &
                  t.eventTimestamp.isBiggerOrEqualValue(since),
            ))
            .get();
    return rows.map(_fromView).toList();
  }

  /// Get completion count for a track scoped to a specific profile.
  Future<int> getAggregateCountByTrack(int trackId, int profileId) async {
    final query = selectOnly(completionsView)
      ..addColumns([completionsView.id.count()])
      ..where(
        completionsView.trackId.equals(trackId) &
            completionsView.profileId.equals(profileId),
      );
    final result = await query.getSingle();
    return result.read(completionsView.id.count()) ?? 0;
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
        await (select(completionsView)
              ..where(
                (t) =>
                    t.trackId.equals(trackId) &
                    t.curriculumId.equals(curriculumId) &
                    t.sefariaRef.equals(sefariaRef) &
                    t.stageId.equals(stageId) &
                    t.eventTimestamp.equals(completedAt),
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
  ) async {
    final rows =
        await (select(completionsView)..where(
              (t) =>
                  t.eventTimestamp.isBiggerOrEqualValue(start) &
                  t.eventTimestamp.isSmallerOrEqualValue(end) &
                  t.trackId.equals(trackId) &
                  t.profileId.equals(profileId),
            ))
            .get();
    return rows.map(_fromView).toList();
  }

  /// Get review counts per item for a track.
  Future<Map<String, int>> getReviewCountsByItemAndTrack(
    int trackId,
    String curriculumId,
    int profileId,
  ) async {
    final query = selectOnly(completionsView)
      ..addColumns([completionsView.sefariaRef, completionsView.id.count()])
      ..where(
        completionsView.trackId.equals(trackId) &
            completionsView.curriculumId.equals(curriculumId) &
            completionsView.profileId.equals(profileId),
      )
      ..groupBy([completionsView.sefariaRef]);

    final results = await query.get();
    final counts = <String, int>{};
    for (final row in results) {
      final ref = row.read(completionsView.sefariaRef);
      final count = row.read(completionsView.id.count());
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
    final query = selectOnly(completionsView)
      ..addColumns([completionsView.stageId, completionsView.id.count()])
      ..where(
        completionsView.trackId.equals(trackId) &
            completionsView.curriculumId.equals(curriculumId) &
            completionsView.sefariaRef.equals(sefariaRef) &
            completionsView.profileId.equals(profileId),
      )
      ..groupBy([completionsView.stageId]);

    final results = await query.get();
    final breakdown = <int, int>{};
    for (final row in results) {
      final stageId = row.read(completionsView.stageId);
      final count = row.read(completionsView.id.count());
      if (stageId != null && count != null) {
        breakdown[stageId] = count;
      }
    }
    return breakdown;
  }

  /// Returns true if any completions reference the given stage ID.
  Future<bool> hasCompletionsForStage(int stageId) async {
    final result =
        await (select(completionsView)
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
    final log = AppLogger.instance;
    if (kDebugMode) {
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
      log.warning(
        event: 'cross_profile_read',
        fields: {'method': method, 'scope': scope.name},
      );
    }
  }
}
