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
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/curriculum_overlap_registry.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/calendar_position_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_lens_refresh_tick_provider.dart';
import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';

// ---------------------------------------------------------------------------
// Re-exports (backward compatibility — consumers continue to import from here)
// ---------------------------------------------------------------------------

export 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart'
    show
        CurriculumLifetimeSummary,
        LifetimeLeafProvenance,
        LifetimeLeafSource,
        LifetimeNodeState,
        LifetimeTotals,
        LifetimeTreeNode,
        TrackDualProgressMetric;

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Partitioned view of `prior_completion_imports` for one curriculum: bulk
/// refs and lifetime refs as separate sets.
///
/// Built by [priorImportsByProfileProvider] in one go for the whole profile,
/// then handed out per-curriculum to provenance computations.
class PriorImportsForCurriculum {
  const PriorImportsForCurriculum({
    required this.bulkRefs,
    required this.lifetimeRefs,
  });

  /// Sefaria refs with `source = 'bulkInTrack'`.
  final Set<String> bulkRefs;

  /// Sefaria refs with `source = 'lifetimeOnly'`.
  final Set<String> lifetimeRefs;
}

/// Profile-wide prior-completion-imports load, partitioned by curriculum.
///
/// Performs **one** SQL query against `prior_completion_imports` for the
/// entire profile and returns a `{curriculumId → PriorImportsForCurriculum}`
/// map. Replaces the per-curriculum + per-subset queries that previously ran
/// inside [lifetimeDataProvider] (F13 — N+1 fix).
///
/// Empty entries (a curriculum with no imports) are omitted from the map so
/// callers can use `map[cur]` directly and fall back to empty sets.
final priorImportsByProfileProvider = FutureProvider.autoDispose
    .family<Map<String, PriorImportsForCurriculum>, int>(
      name: 'priorImportsByProfileProvider',
      (ref, profileId) async {
        ref.watch(progressLensRefreshTickProvider);
        // D9: also recompute on every completion commit so the dashboard
        // lifetime card (which reads lifetimeTotalsAcrossAllCurricula → this
        // chain) stays live. progressLensRefreshTick is bumped ONLY by the
        // Progress-hub pull-to-refresh, so without this a dashboard/reader mark
        // left the lifetime totals stale until the user pulled to refresh.
        ref.watch<int>(completionCommittedProvider);
        final db = ref.watch(userDatabaseProvider);
        final rows = await (db.select(
          db.priorCompletionImports,
        )..where((t) => t.profileId.equals(profileId))).get();

        // Partition by (curriculumId, source) in memory.
        final bulk = <String, Set<String>>{};
        final lifetime = <String, Set<String>>{};
        for (final row in rows) {
          switch (row.source) {
            case 'bulkInTrack':
              (bulk[row.curriculumId] ??= <String>{}).add(row.sefariaRef);
            case 'lifetimeOnly':
              (lifetime[row.curriculumId] ??= <String>{}).add(row.sefariaRef);
          }
        }

        final out = <String, PriorImportsForCurriculum>{};
        final cKeys = {...bulk.keys, ...lifetime.keys};
        for (final c in cKeys) {
          out[c] = PriorImportsForCurriculum(
            bulkRefs: bulk[c] ?? const <String>{},
            lifetimeRefs: lifetime[c] ?? const <String>{},
          );
        }
        return out;
      },
    );

/// Profile-wide completions load for the Lifetime Knowledge feature.
///
/// One query per profile (vs one query per curriculum + one per subset under
/// the legacy code path). Results are partitioned in-memory by curriculumId.
/// F13 — N+1 fix.
final completionsByProfileForLifetimeProvider = FutureProvider.autoDispose
    .family<Map<String, List<Completion>>, int>(
      name: 'completionsByProfileForLifetimeProvider',
      (ref, profileId) async {
        ref.watch(progressLensRefreshTickProvider);
        // D9: recompute on every completion commit (see priorImportsByProfile).
        ref.watch<int>(completionCommittedProvider);
        final db = ref.watch(userDatabaseProvider);
        final all = await db.completionDao.getCompletionsByProfile(profileId);
        final out = <String, List<Completion>>{};
        for (final c in all) {
          (out[c.curriculumId] ??= <Completion>[]).add(c);
        }
        return out;
      },
    );

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

      // F13: one profile-wide completions read, partitioned in memory by
      // curriculumId. Replaces the per-curriculum + per-subset SELECTs.
      final completionsByCurriculum = await ref.watch(
        completionsByProfileForLifetimeProvider(profileId).future,
      );
      final completions =
          completionsByCurriculum[curriculum.storageKey] ??
          const <Completion>[];
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
      // Track every event ref (including duplicates) for the chazaros count.
      final allEventRefs = <String>[...completions.map((c) => c.sefariaRef)];
      for (final subset in subsets) {
        final subsetCompletions =
            completionsByCurriculum[subset.storageKey] ?? const <Completion>[];
        completedRefs = completedRefs.union(
          subsetCompletions.map((c) => c.sefariaRef).toSet(),
        );
        allEventRefs.addAll(subsetCompletions.map((c) => c.sefariaRef));
      }

      // P0 (composite-credit) fix: completions are unioned across subsets above,
      // but LIFETIME LEDGER marks were NOT — a lifetime mark made in the
      // standalone Chumash UI (e.g. sefer Bereishis) credited only the `chumash`
      // curriculum and never propagated to its superset Tanach, while a mark made
      // in the Tanach UI used Tanach's synthetic `Torah`-shifted hierarchy.
      //
      // We bridge the two by computing each subset's learned leaf refs from the
      // subset's OWN leaves + OWN ledger (its native, collision-safe hierarchy)
      // and unioning the resulting canonical `sefariaRef`s into [completedRefs].
      // Because a leaf carries the SAME sefariaRef in every curriculum it belongs
      // to, a single Bereishis mark — made via Chumash or via Tanach→Torah —
      // credits exactly Bereishis's leaves in the composite, so the Tanach total
      // matches the standalone Chumash total. Set semantics keep each ref counted
      // once regardless of how many paths reach it.
      if (subsets.isNotEmpty) {
        const subsetBuilder = LifetimeTreeBuilder();
        for (final subset in subsets) {
          final subsetLeaves = await _safeLoadLeaves(repo, subset);
          if (subsetLeaves == null || subsetLeaves.isEmpty) continue;
          final subsetLedger = await db.learningLedgerDao
              .getEntriesByCurriculum(profileId, subset.storageKey);
          if (subsetLedger.isEmpty) continue;
          final subsetCompleted =
              (completionsByCurriculum[subset.storageKey] ??
                      const <Completion>[])
                  .map((c) => c.sefariaRef)
                  .toSet();
          final subsetLearned = subsetBuilder.computeLearnedLeafRefs(
            leaves: subsetLeaves,
            completedRefs: subsetCompleted,
            ledgerEntries: subsetLedger,
          );
          completedRefs = completedRefs.union(subsetLearned);
        }
      }

      // Per-leaf provenance: read all imports for this profile in one query
      // (coalesced via [priorImportsByProfileProvider]) and partition by
      // (curriculumId, source). We classify each leaf by the strongest source
      // seen — live wins over bulk, bulk wins over lifetimeOnly, lifetimeOnly
      // wins over ledger-only.
      //
      // **Contract relied on for the upgrade case (live event for an existing
      // bulk row):** when a live completion event commits against a natural
      // key already present in `prior_completion_imports`, the writer DELETES
      // the import row (see `CompletionWriter._upgradePriorMarkRow` →
      // `PriorCompletionImportDao.deleteImport`). After the delete, the ref
      // is no longer in [bulkRefs]/[lifetimeRefs], so `computeLeafProvenance`
      // correctly returns `LifetimeLeafSource.live` for that ref.
      final imports = await ref.watch(
        priorImportsByProfileProvider(profileId).future,
      );
      final bulkRefs = <String>{};
      final lifetimeRefs = <String>{};
      for (final cur in [curriculum, ...subsets]) {
        final perCur = imports[cur.storageKey];
        if (perCur == null) continue;
        bulkRefs.addAll(perCur.bulkRefs);
        lifetimeRefs.addAll(perCur.lifetimeRefs);
      }

      // Per-leaf event count (for the chazaros number on live entries). The
      // (bulkRefs, lifetimeRefs) sets passed here already reflect upgrades —
      // see contract comment above. No further reconciliation is needed.
      final leafProvenance = LifetimeTreeBuilder.computeLeafProvenance(
        completionEventRefs: allEventRefs,
        bulkImportedRefs: bulkRefs,
        lifetimeImportedRefs: lifetimeRefs,
      );

      final heLookup = await _safeHeLabelLookup(repo, curriculum);
      const builder = LifetimeTreeBuilder();

      return builder.build(
        curriculum: curriculum,
        leaves: leaves,
        completedRefs: completedRefs,
        ledgerEntries: ledger,
        heLabelLookup: heLookup,
        leafProvenance: leafProvenance,
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

/// Per-track dual-progress metrics for the active-track dashboard card.
///
/// Returns a list of [TrackDualProgressMetric], one per active track, each
/// containing two progress percentages:
///
/// **[TrackDualProgressMetric.currentCyclePercentage]** — the time-gated
/// single-ref percentage: fraction of items with any completion since
/// `track.activatedAt` (resets on track re-activation). Labelled
/// "Since reactivation" in the UI.
///
/// **[TrackDualProgressMetric.lifetimePercentage]** — the fraction of items
/// the user has ever encountered, computed by [LifetimeTreeBuilder] across
/// all completion sources (live + bulk-prior + lifetime imports).
///
/// **Why these differ from [dashboardTrackCompletionPercentageProvider]:**
///
/// [dashboardTrackCompletionPercentageProvider] answers "how complete is this
/// track overall, across all time and all completion sources?" — a multi-stage
/// gate, all-time calculation.
///
/// [currentCyclePercentage] here answers "how many distinct items has the user
/// touched since the track was last activated?" — a time-gated, single-ref
/// presence check. It intentionally reads zero for users who completed items
/// before the current `activatedAt` (e.g. after re-importing a track).
///
/// See also: [dashboardTrackCompletionPercentageProvider]
/// (dashboard_providers.dart).
final trackDualProgressMetricsProvider = FutureProvider.autoDispose
    .family<List<TrackDualProgressMetric>, int>((ref, profileId) async {
      // Rebuild when a live completion is committed so the dashboard card
      // reflects new activity immediately (mirrors the watch in
      // dashboardTrackCompletionPercentageProvider). Fix 3 — DNI L1+L2.
      ref.watch<int>(completionCommittedProvider);

      final db = ref.watch(userDatabaseProvider);
      final repo = ref.watch(contentRepositoryProvider);
      // Capture every ref-backed dependency synchronously, before any await:
      // this autoDispose provider is rebuilt rapidly on the dashboard and a
      // `ref.read`/`ref.watch` after an async gap throws "Cannot use Ref after
      // dispose", failing the whole metric list.
      final progressSvc = ref.read(trackProgressServiceProvider);
      final useHebrewTerms = domainTermLabelsFromRef(ref).isHebrew;
      final tracks = await db.trackDao.getAllForProfile(profileId);

      final metrics = <TrackDualProgressMetric>[];
      for (final track in tracks) {
        final curriculum = CurriculumId.values
            .where((c) => c.storageKey == track.curriculumId)
            .firstOrNull;
        if (curriculum == null) {
          AppLogger.instance.warning(
            event:
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

        // Layer 3 migration: use TrackProgressService with trackAchievement tier.
        // since: track.activatedAt preserves the time-gated "this cycle" semantics.
        // requireAllStages: false matches the old distinct-refs-only count.
        // trackAchievement excludes lifetimeOnly rows (correct per B1 policy).
        final currentCyclePct = await progressSvc.completionPercent(
          trackId: track.id,
          profileId: profileId,
          tier: CompletionTierFilter.trackAchievement,
          totalItems: denominator,
          requireAllStages: false,
          since: track.activatedAt,
        );

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

        final localizedCurriculum = curriculumLabelFor(
          curriculum,
          useHebrewTerms: useHebrewTerms,
        );
        metrics.add(
          TrackDualProgressMetric(
            trackId: track.id,
            // W3.22: trackType dropped — label is just the curriculum name.
            trackLabel: localizedCurriculum,
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

/// Header counters for the Lifetime Knowledge screen.
///
/// Two numbers:
///   * **itemsLearned** — distinct sefariaRefs ever touched by the profile,
///     across every curriculum and every completion source (live + bulk
///     + lifetimeOnly + ledger-derived). Mirrors the union semantics of
///     [lifetimeTotalsAcrossAllCurriculaProvider].
///   * **totalChazaros** — total count of completion event rows for the
///     profile. Every event (limud or chazara) increments the counter.
///     Ledger-only marks contribute zero (no event row exists for them).
class LifetimeHeaderCounters {
  const LifetimeHeaderCounters({
    required this.itemsLearned,
    required this.totalChazaros,
  });

  /// Distinct items learned across every source (lifetime-tier union).
  final int itemsLearned;

  /// Total completion-event rows (every limud + every chazara).
  final int totalChazaros;
}

/// Header counters for the Lifetime Knowledge screen — "All sources" branch.
///
/// Reuses [lifetimeSummariesProvider] for the items count (deduplicated
/// across overlapping curricula) and reads completion events directly to sum
/// chazaros across all curricula in one query.
final lifetimeHeaderCountersProvider = FutureProvider.autoDispose
    .family<LifetimeHeaderCounters, int>((ref, profileId) async {
      // Items learned — reuse the union logic.
      final totals = await ref.watch(
        lifetimeTotalsAcrossAllCurriculaProvider(profileId).future,
      );

      // Total chazaros — only REVIEW completion events (stageId > 1).
      // PP-4 fix: the previous `completions.length` counted ALL events,
      // including the initial limud (stageId == 1). A user who has learned
      // but never reviewed therefore saw a non-zero "total chazaros" equal
      // to their learn count — contradicting the per-leaf "Live · 0 chazaros"
      // display. Filtering to stageId > 1 gives the true review count.
      final db = ref.watch(userDatabaseProvider);
      final completions = await db.completionDao.getCompletionsByProfile(
        profileId,
      );

      return LifetimeHeaderCounters(
        itemsLearned: totals.learnedSections,
        totalChazaros: completions.where((c) => c.stageId > 1).length,
      );
    });

/// Header counters for the Lifetime Knowledge screen — "Track learning only"
/// branch (F3).
///
/// Mirrors [lifetimeHeaderCountersProvider] but applies the
/// [CompletionTierFilter.trackAchievement] filter so the counts exclude
/// lifetimeOnly imports. The toggle on the screen switches between the two
/// providers so the displayed numbers stay consistent with the body
/// (per-curriculum tree).
///
/// `itemsLearned` is the cardinality of distinct sefariaRefs in the filtered
/// set (the SAME data surface the body's `itemsLearnedSummariesProvider`
/// uses); `totalChazaros` counts every event row in the filtered set.
final trackOnlyHeaderCountersProvider = FutureProvider.autoDispose
    .family<LifetimeHeaderCounters, int>((ref, profileId) async {
      final db = ref.watch(userDatabaseProvider);
      // Track-achievement = live + bulkInTrack; lifetimeOnly is excluded at
      // the SQL layer via NOT EXISTS / EXISTS predicates on
      // prior_completion_imports. See [CompletionDao.getCompletionsByTier].
      final completions = await db.completionDao.getCompletionsByTier(
        profileId: profileId,
        tier: CompletionTierFilter.trackAchievement,
      );
      final distinctRefs = completions.map((c) => c.sefariaRef).toSet();
      // PP-4 fix: count only review events (stageId > 1), not the initial
      // limud, to match the "total chazaros" label semantics.
      return LifetimeHeaderCounters(
        itemsLearned: distinctRefs.length,
        totalChazaros: completions.where((c) => c.stageId > 1).length,
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
  } catch (e, st) {
    // F20: surface content-asset load failures so a missing/corrupt asset is
    // diagnosable instead of silently producing an empty Lifetime Knowledge
    // tree. Return null on the cold path so callers skip the curriculum.
    AppLogger.instance.warning(
      event: 'lifetime_safe_load_failed',
      fields: {'curriculum': curriculum.storageKey, 'phase': 'leaves'},
      exception: e,
      stackTrace: st,
    );
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
  } catch (e, st) {
    // F20: as above — log the failure but keep the cold-path empty map so
    // the screen renders without Hebrew labels rather than crashing.
    AppLogger.instance.warning(
      event: 'lifetime_safe_load_failed',
      fields: {'curriculum': curriculum.storageKey, 'phase': 'he_labels'},
      exception: e,
      stackTrace: st,
    );
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
