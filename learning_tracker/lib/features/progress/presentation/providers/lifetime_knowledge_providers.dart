/// Lifetime knowledge Riverpod providers.
///
/// Domain models and computation logic have been extracted to:
/// - `progress/domain/models/lifetime_knowledge.dart` — [LifetimeTreeNode],
///   [CurriculumLifetimeSummary], [TrackDualProgressMetric], [LifetimeTotals]
/// - `progress/domain/services/lifetime_tree_builder.dart` — [LifetimeTreeBuilder]
///
/// This file re-exports those types for backward compatibility with existing
/// consumers, and provides the Riverpod providers that orchestrate data loading.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/curriculum_overlap_registry.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/calendar_position_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';

// ---------------------------------------------------------------------------
// Re-exports (backward compatibility — consumers continue to import from here)
// ---------------------------------------------------------------------------

export 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart'
    show
        LifetimeNodeState,
        LifetimeTreeNode,
        CurriculumLifetimeSummary,
        TrackDualProgressMetric,
        LifetimeTotals;

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Per-curriculum lazy lifetime data provider.
///
/// Loads lifetime completion data for a single [CurriculumId]. Returns `null`
/// when the curriculum's content asset is missing or empty so callers can skip
/// it without error.
///
/// Keyed by `({int profileId, CurriculumId curriculumId})` so each curriculum
/// is fetched independently and cached/disposed independently.
final lifetimeDataProvider = FutureProvider.autoDispose
    .family<
      CurriculumLifetimeSummary?,
      ({int profileId, CurriculumId curriculumId})
    >((ref, args) async {
      final db = ref.watch(userDatabaseProvider);
      final repo = ref.watch(contentRepositoryProvider);
      final curriculum = args.curriculumId;
      final profileId = args.profileId;

      final leaves = await _safeLoadLeaves(repo, curriculum);
      if (leaves == null) return null;
      if (leaves.isEmpty) return null;

      final completions = await db.completionDao
          .getCompletionsByCurriculumAndProfile(
            curriculum.storageKey,
            profileId,
          );
      final ledger = await db.learningLedgerDao.getEntriesByCurriculum(
        profileId,
        curriculum.storageKey,
      );

      // I-4: Union in completions from subset curricula so that, e.g., a ref
      // completed via a Chumash track is also credited to Tanach. Deduplication
      // is handled by Set semantics — a ref present in both the direct set and a
      // subset set is counted only once.
      final subsets = subsetsOf(curriculum);
      var completedRefs = completions.map((c) => c.sefariaRef).toSet();
      for (final subset in subsets) {
        final subsetCompletions = await db.completionDao
            .getCompletionsByCurriculumAndProfile(subset.storageKey, profileId);
        completedRefs = completedRefs.union(
          subsetCompletions.map((c) => c.sefariaRef).toSet(),
        );
      }

      final heLookup = await _safeHeLabelLookup(repo, curriculum);
      const builder = LifetimeTreeBuilder();

      return builder.build(
        curriculum: curriculum,
        leaves: leaves,
        completedRefs: completedRefs,
        ledgerEntries: ledger,
        heLabelLookup: heLookup,
      );
    });

/// Aggregated lifetime summaries across all active curricula.
///
/// Reads from [lifetimeDataProvider] per curriculum lazily — each curriculum
/// is fetched and cached independently, so a single-curriculum tap only loads
/// that curriculum's data.
final lifetimeSummariesProvider = FutureProvider.autoDispose
    .family<List<CurriculumLifetimeSummary>, int>((ref, profileId) async {
      final results = await Future.wait(
        CurriculumId.values.map(
          (curriculum) => ref.watch(
            lifetimeDataProvider((
              profileId: profileId,
              curriculumId: curriculum,
            )).future,
          ),
        ),
      );
      return results.whereType<CurriculumLifetimeSummary>().toList();
    });

/// Compatibility alias for [lifetimeSummariesProvider].
///
/// Retained so existing callers compile without change. Prefer
/// [lifetimeSummariesProvider] in new code.
///
/// When only a single curriculum is needed, prefer
/// [lifetimeDataProvider] to avoid loading all 9 curricula.
@Deprecated('Use lifetimeSummariesProvider or lifetimeDataProvider instead')
final globalLifetimeCurriculaProvider = lifetimeSummariesProvider;

final trackDualProgressMetricsProvider = FutureProvider.autoDispose
    .family<List<TrackDualProgressMetric>, int>((ref, profileId) async {
      final db = ref.watch(userDatabaseProvider);
      final repo = ref.watch(contentRepositoryProvider);
      final tracks = await db.trackDao.getAllForProfile(profileId);

      final metrics = <TrackDualProgressMetric>[];
      for (final track in tracks) {
        final curriculum = CurriculumId.values
            .where((c) => c.storageKey == track.curriculumId)
            .firstOrNull;
        if (curriculum == null) {
          AppLogger.instance.warning(
            'trackDualProgressMetrics: unknown curriculumId key: '
            '"${track.curriculumId}" — skipping',
          );
          continue;
        }
        final leaves = await _safeLoadLeavesForTrack(
          repo,
          db,
          profileId,
          curriculum,
          track.id,
        );
        if (leaves == null) continue;
        final denominator = leaves.length;
        if (denominator == 0) continue;

        final sessionCompletions = await db.completionDao
            .getCompletionsByTrackAndProfileSince(
              track.id,
              profileId,
              track.activatedAt,
            );
        final currentCycleRefs = sessionCompletions
            .map((c) => c.sefariaRef)
            .toSet();
        final currentCyclePct = currentCycleRefs.length / denominator;

        final allTrackCompletions = await db.completionDao
            .getCompletionsByTrackAndProfile(track.id, profileId);
        final trackLedger = await db.learningLedgerDao.getEntriesByTrack(
          track.id,
          profileId,
        );

        const builder = LifetimeTreeBuilder();
        final lifetimeRefs = builder.computeLearnedLeafRefs(
          leaves: leaves,
          completedRefs: allTrackCompletions.map((c) => c.sefariaRef).toSet(),
          ledgerEntries: trackLedger,
        );
        final lifetimePct = lifetimeRefs.length / denominator;

        final enrollment = await db.profileProgramDao
            .getProgramForProfileAndCurriculum(
              profileId,
              curriculum.storageKey,
            );
        int? todayDueCount;
        int? overdueCount;
        if (enrollment != null) {
          try {
            final calendarPos = await ref.read(
              programCalendarPositionProvider(track.id).future,
            );
            final delta = calendarPos.delta;
            overdueCount = delta < 0 ? (-delta - 1).clamp(0, 9999) : 0;
            todayDueCount = delta > 0 ? 0 : 1;
          } catch (_) {
            overdueCount = 0;
            todayDueCount = 0;
          }
        }

        final localizedCurriculum = curriculumLabelTextFromRef(
          ref,
          curriculum: curriculum,
        );
        metrics.add(
          TrackDualProgressMetric(
            trackId: track.id,
            trackLabel: '$localizedCurriculum (${track.trackType})',
            curriculumId: curriculum,
            currentCyclePercentage: currentCyclePct.clamp(0.0, 1.0),
            lifetimePercentage: lifetimePct.clamp(0.0, 1.0),
            isProgramTrack: enrollment != null,
            todayDueCount: todayDueCount,
            overdueCount: overdueCount,
          ),
        );
      }

      return metrics;
    });

final lifetimeTotalsAcrossAllCurriculaProvider = FutureProvider.autoDispose
    .family<LifetimeTotals, int>((ref, profileId) async {
      final summaries = await ref.watch(
        lifetimeSummariesProvider(profileId).future,
      );
      // Build union sets so that a section appearing in N curricula counts once.
      final allDistinct = <String>{};
      final learnedDistinct = <String>{};
      for (final s in summaries) {
        allDistinct.addAll(s.allLeafRefs);
        learnedDistinct.addAll(s.learnedLeafRefs);
      }
      return LifetimeTotals(
        learnedSections: learnedDistinct.length,
        totalSections: allDistinct.length,
        totalCurricula: CurriculumId.values.length,
      );
    });

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

Future<List<ContentItem>?> _safeLoadLeaves(
  ContentRepository repo,
  CurriculumId curriculum,
) async {
  try {
    final content = await repo.getContentForCurriculum(curriculum);
    return content.where((item) => item.isLeaf).toList();
  } catch (_) {
    return null;
  }
}

Future<Map<String, String>> _safeHeLabelLookup(
  ContentRepository repo,
  CurriculumId curriculum,
) async {
  try {
    final content = await repo.getContentForCurriculum(curriculum);
    return LifetimeTreeBuilder.buildHeLabelLookup(content);
  } catch (_) {
    return const {};
  }
}

Future<List<ContentItem>?> _safeLoadLeavesForTrack(
  ContentRepository repo,
  UserDatabase db,
  int profileId,
  CurriculumId curriculum,
  int trackId,
) async {
  var scopes = await db.curriculumScopeDao.getScopesByTrack(trackId);
  if (scopes.isEmpty) {
    final forProfile = await db.curriculumScopeDao.getScopes(
      profileId,
      curriculum,
    );
    scopes = forProfile.where((s) => s.trackId == trackId).toList();
  }
  if (scopes.isEmpty) {
    final forProfile = await db.curriculumScopeDao.getScopes(
      profileId,
      curriculum,
    );
    if (forProfile.isNotEmpty) {
      final allZero = forProfile.every((s) => s.trackId == 0);
      if (allZero) {
        final inCur = (await db.trackDao.getActiveTracksForProfile(
          profileId,
        )).where((t) => t.curriculumId == curriculum.storageKey).toList();
        if (inCur.length == 1 && inCur.single.id == trackId) {
          scopes = forProfile;
        }
      }
    }
  }

  try {
    if (scopes.isEmpty) {
      return _safeLoadLeaves(repo, curriculum);
    }
    final allItems = await repo.getScopedContent(
      curriculumId: curriculum,
      scopeLevel: scopes.first.scopeLevel,
      scopeValues: scopes.map((s) => s.scopeValue).toList(),
    );
    return allItems.where((item) => item.isLeaf).toList();
  } catch (_) {
    return null;
  }
}
