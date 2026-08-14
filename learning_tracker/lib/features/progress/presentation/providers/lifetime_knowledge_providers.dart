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
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/curriculum_overlap_registry.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/strategies/composite_curriculum_strategy.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_tier_filter.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_lens_refresh_tick_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/calendar_position_providers.dart';
import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';
import 'package:learning_tracker/features/tracks/presentation/providers/track_progress_providers.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/profile_program.dart';
import 'package:learning_tracker/features/tracks/setup/presentation/providers/track_management_providers.dart';

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
/// In the Firestore model the `prior_completion_imports` table is gone;
/// bulk-provenance is carried on [CompletionEntity.source] and
/// lifetime-only marks live in the learning ledger ([LearningLedgerEntry]).
/// This class is retained for callers that partition provenance data by
/// curriculum source, computed inline by [completionsByProfileForLifetimeProvider]
/// and the provenance computation in [lifetimeDataProvider].
class PriorImportsForCurriculum {
  const PriorImportsForCurriculum({
    required this.bulkRefs,
    required this.lifetimeRefs,
  });

  /// Sefaria refs with `source = 'bulkInTrack'` on their CompletionEntity.
  final Set<String> bulkRefs;

  /// Sefaria refs that were lifetime-imported. In the Firestore model this is
  /// computed from ledger entries whose `source == CompletionSource.lifetimeOnly`
  /// that expand to leaf-level sefariaRefs via [LifetimeTreeBuilder.computeLearnedLeafRefs].
  final Set<String> lifetimeRefs;
}

/// Thrown when a provider in this file runs with no active profile.
///
/// The Firestore completions/ledger collections live under
/// `learner_profiles/{profileId}/...`, scoped to the active profile by their
/// collection path. There is no way to read another profile's data from these
/// providers. Owner ruling D-E: fail LOUDLY rather than quietly serve
/// stale/empty data. Mirrors `ItemsLearnedNoActiveProfileException` in
/// `items_learned_providers.dart`.
///
/// AD-24 correction (fixed alongside `items_learned_providers.dart`'s
/// identical issue): every provider in this file used to be keyed by an
/// `int profileId` family argument, checked against the (String ULID)
/// active profile — comparing an `int` to a `String?` is never equal, so
/// the old guard threw unconditionally, on every call, regardless of
/// whether a profile was actually active. That made every provider here
/// (including the ones with real Firestore-backed bodies — most of this
/// file was already migrated by an earlier wave) fail at runtime even
/// though the file analyzed clean. There was never a legitimate "read
/// someone else's profile" case to guard against in the Firestore model —
/// every provider these functions read from is already scoped to the
/// active profile by its collection path — so the argument added a broken
/// check, not a real capability. Removed from every provider's signature;
/// this now only guards "no active profile at all".
class LifetimeKnowledgeNoActiveProfileException implements Exception {
  const LifetimeKnowledgeNoActiveProfileException();

  @override
  String toString() =>
      'LifetimeKnowledgeNoActiveProfileException: a Lifetime Knowledge '
      'provider was read with no active profile — the Firestore '
      'completions/ledger are scoped to the active profile and there is '
      'nothing to read without one.';
}

/// Guards a provider against running with no active profile (D-E). Watches
/// [activeProfileIdProvider] synchronously so the dependency is registered
/// (and this provider rebuilds on profile switch) before any await.
void _assertActiveProfile(Ref ref) {
  if (ref.watch(activeProfileIdProvider) == null) {
    throw const LifetimeKnowledgeNoActiveProfileException();
  }
}

/// Profile-wide prior-completion-imports load, partitioned by curriculum.
///
/// In the Firestore model the `prior_completion_imports` table is deleted —
/// provenance is carried on `CompletionEntity.source` and
/// `LearningLedgerEntry.source`. This provider computes the `bulkRefs`/`lifetimeRefs`
/// partition from the Firestore collections so the provenance computation in
/// [lifetimeDataProvider] has the data it needs.
///
/// The `completions` collection can only ever hold `live`/`bulkInTrack` rows
/// (a `lifetimeOnly` document is rejected at write time — see
/// `CompletionEntity`'s class doc comment), so `bulkRefs` =
/// sefariaRefs of `bulkInTrack` completions. `lifetimeRefs` is populated from
/// learning-ledger entries whose `source == CompletionSource.lifetimeOnly`
/// that expand to leaf-level sefariaRefs via
/// [LifetimeTreeBuilder.computeLearnedLeafRefs].
final priorImportsByProfileProvider =
    FutureProvider.autoDispose<Map<String, PriorImportsForCurriculum>>((
      ref,
    ) async {
      ref.watch(progressLensRefreshTickProvider);
      ref.watch<int>(completionCommittedProvider);
      _assertActiveProfile(ref);

      final repository = ref.watch(completionRepositoryProvider);
      final ledgerEntries = await ref.watch(learningLedgerProvider.future);

      // Collect ALL completions for the profile by iterating curricula.
      final allCompletions = <CompletionEntity>[];
      for (final curriculum in CurriculumId.values) {
        allCompletions.addAll(
          await repository.getCompletionsByCurriculum(curriculum.storageKey),
        );
      }

      // Partition by (curriculumId, source) in memory.
      final bulk = <String, Set<String>>{};
      final lifetime = <String, Set<String>>{};
      for (final c in allCompletions) {
        switch (c.source) {
          case CompletionSource.bulkInTrack:
            (bulk[c.curriculumId.storageKey] ??= <String>{}).add(c.sefariaRef);
          case CompletionSource.live:
            // live marks are not prior-import rows.
            break;
          case CompletionSource.lifetimeOnly:
            // Should never appear in the completions collection, but if it
            // does, treat it as a lifetime import.
            (lifetime[c.curriculumId.storageKey] ??= <String>{}).add(
              c.sefariaRef,
            );
        }
      }

      // Lifetime-only marks live in the learning ledger, not the completions
      // collection. Ledger entries carry unitIdentifier + entryScope, not
      // sefariaRef, so they cannot be directly classified into a sefariaRef
      // set without leaf-expansion per curriculum. The provenance computation
      // in lifetimeDataProvider handles these via
      // LifetimeTreeBuilder.computeLearnedLeafRefs + ledgerLearnedRefs instead.
      // Here we record the curriculum keys that HAVE lifetime-only ledger
      // entries so callers know the set is non-empty.
      for (final e in ledgerEntries) {
        if (e.source == CompletionSource.lifetimeOnly) {
          // Ledger entries don't carry sefariaRef; their unitIdentifier is
          // scope-bearing (not a bare sefariaRef). We don't add to lifetimeRefs
          // here — lifetimeDataProvider computes ledgerLearnedRefs via
          // computeLearnedLeafRefs which does the leaf expansion.
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
    });

/// Profile-wide completions load for the Lifetime Knowledge feature.
///
/// One Firestore query per curriculum (9 total) replaces the Drift single
/// `getCompletionsByProfile` query. Results are partitioned in-memory by
/// curriculumId. Uses [completionRepositoryProvider] (presentation-legal) —
/// NOT the deleted Drift DAOs.
///
/// Empty entries (a curriculum with no completions) are omitted from the map so
/// callers can use `map[cur]` directly and fall back to empty lists.
final completionsByProfileForLifetimeProvider =
    FutureProvider.autoDispose<Map<String, List<CompletionEntity>>>((
      ref,
    ) async {
      ref.watch(progressLensRefreshTickProvider);
      // D9: also recompute on every completion commit so the dashboard
      // lifetime card (which reads lifetimeTotalsAcrossAllCurricula → this
      // chain) stays live.
      ref.watch<int>(completionCommittedProvider);
      _assertActiveProfile(ref);

      final repository = ref.watch(completionRepositoryProvider);
      final all = <CompletionEntity>[];
      for (final curriculum in CurriculumId.values) {
        all.addAll(
          await repository.getCompletionsByCurriculum(curriculum.storageKey),
        );
      }
      final out = <String, List<CompletionEntity>>{};
      for (final c in all) {
        (out[c.curriculumId.storageKey] ??= <CompletionEntity>[]).add(c);
      }
      return out;
    });

/// Per-curriculum lazy lifetime data provider.
///
/// Loads lifetime completion data for a single [CurriculumId]. Returns `null`
/// when the curriculum's content asset is missing or empty so callers can skip
/// it without error.
///
/// Keyed by [CurriculumId] (the ACTIVE profile) so each curriculum is
/// fetched independently and cached/disposed independently.
final lifetimeDataProvider = FutureProvider.autoDispose
    .family<CurriculumLifetimeSummary?, CurriculumId>((ref, curriculum) async {
      ref.watch(progressLensRefreshTickProvider);
      // D9: recompute on every completion commit (see priorImportsByProfile).
      ref.watch<int>(completionCommittedProvider);
      _assertActiveProfile(ref);

      final repo = ref.watch(contentRepositoryProvider);

      final leaves = await _safeLoadLeaves(repo, curriculum);
      if (leaves == null) return null;
      if (leaves.isEmpty) return null;

      // F13: one profile-wide completions read, partitioned in memory by
      // curriculumId via completionsByProfileForLifetimeProvider.
      final completionsByCurriculum = await ref.watch(
        completionsByProfileForLifetimeProvider.future,
      );
      final completions =
          completionsByCurriculum[curriculum.storageKey] ??
          const <CompletionEntity>[];

      // P0 (composite over-credit) READ-TIME guard. A COMPOSITE curriculum
      // (Tanach) re-parents its source leaves under a SYNTHETIC level1 container
      // (e.g. 'Torah') that exists in no real curriculum. A stray
      // `tanach/level1/'Torah'` ledger row blanket-credits the ENTIRE Torah
      // (~5846) from a single-book mark — and the v32 migration that deletes it
      // only runs once per account DB, so it cannot be relied on (a row that
      // survived an earlier-upgraded DB persists). Defensively DROP any
      // synthetic-container level1 (and its unmark_) row here so the builder
      // never credits it; the real per-book learning still flows in via the
      // subset-ledger union below (by canonical sefariaRef).
      final ledger = _dropSyntheticContainerMarks(
        curriculum.storageKey,
        await ref.watch(curriculumLedgerProvider(curriculum.storageKey).future),
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
            completionsByCurriculum[subset.storageKey] ??
            const <CompletionEntity>[];
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
          final subsetLedger = _dropSyntheticContainerMarks(
            subset.storageKey,
            await ref.watch(curriculumLedgerProvider(subset.storageKey).future),
          );
          if (subsetLedger.isEmpty) continue;
          final subsetCompleted =
              (completionsByCurriculum[subset.storageKey] ??
                      const <CompletionEntity>[])
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

      // Compute learned leaf refs for this curriculum (for provenance +
      // the build step below).
      const builder = LifetimeTreeBuilder();
      final learnedRefs = builder.computeLearnedLeafRefs(
        leaves: leaves,
        completedRefs: completedRefs,
        ledgerEntries: ledger,
      );

      // Per-leaf provenance: compute from CompletionEntity.source + ledger
      // (replacing the deleted prior_completion_imports table).
      // bulkRefs = sefariaRefs of bulkInTrack completions.
      // lifetimeRefs from the old prior_imports table are gone; lifetime-only
      // marks are in the learning ledger and are captured by ledgerLearnedRefs
      // (learned refs NOT present in completions).
      final bulkRefs = completionsToBulkRefs(completions);
      final eventRefs = allEventRefs.toSet();
      final ledgerLearnedRefs = learnedRefs.difference(
        eventRefs.union(bulkRefs),
      );
      final leafProvenance = LifetimeTreeBuilder.computeLeafProvenance(
        completionEventRefs: allEventRefs,
        bulkImportedRefs: bulkRefs,
        lifetimeImportedRefs: const <String>{},
        ledgerLearnedRefs: ledgerLearnedRefs,
      );

      final heLookup = await _safeHeLabelLookup(repo, curriculum);

      return builder.build(
        curriculum: curriculum,
        leaves: leaves,
        completedRefs: completedRefs,
        ledgerEntries: ledger,
        heLabelLookup: heLookup,
        leafProvenance: leafProvenance,
      );
    });

/// Extracts the sefariaRef set of bulkInTrack completions — used by
/// [lifetimeDataProvider]'s provenance computation.
Set<String> completionsToBulkRefs(List<CompletionEntity> completions) {
  return completions
      .where((c) => c.source == CompletionSource.bulkInTrack)
      .map((c) => c.sefariaRef)
      .toSet();
}

/// Aggregated lifetime summaries across all active curricula.
///
/// Reads from [lifetimeDataProvider] per curriculum lazily — each curriculum
/// is fetched and cached independently, so a single-curriculum tap only loads
/// that curriculum's data.
final lifetimeSummariesProvider =
    FutureProvider.autoDispose<List<CurriculumLifetimeSummary>>((ref) async {
      final results = await Future.wait(
        CurriculumId.values.map(
          (curriculum) => ref.watch(lifetimeDataProvider(curriculum).future),
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

/// Profile-wide completions load for [trackDualProgressMetricsProvider],
/// partitioned by the curriculum storage key (the sole track identity).
final trackCompletionsByProfileProvider =
    FutureProvider.autoDispose<Map<String, List<CompletionEntity>>>((
      ref,
    ) async {
      ref.watch(progressLensRefreshTickProvider);
      ref.watch<int>(completionCommittedProvider);
      _assertActiveProfile(ref);
      return ref.watch(completionsByProfileForLifetimeProvider.future);
    });

/// Profile-wide learning-ledger load for [trackDualProgressMetricsProvider],
/// partitioned by the curriculum storage key (the sole track identity).
final trackLedgerEntriesByProfileProvider =
    FutureProvider.autoDispose<Map<String, List<LearningLedgerEntry>>>((
      ref,
    ) async {
      ref.watch(progressLensRefreshTickProvider);
      ref.watch<int>(completionCommittedProvider);
      _assertActiveProfile(ref);
      return ref.watch(ledgerEntriesByCurriculumForProfileProvider.future);
    });

/// Profile-wide learning-ledger load for [trackDualProgressMetricsProvider]'s
/// `lifetimePercentage`, partitioned by curriculum storage key.
///
/// Replaces the deleted `db.learningLedgerDao.getEntriesGroupedByCurriculum()`
/// call with a single [learningLedgerProvider] read + in-memory partition
/// by `curriculumId.storageKey`.
final ledgerEntriesByCurriculumForProfileProvider =
    FutureProvider.autoDispose<Map<String, List<LearningLedgerEntry>>>((
      ref,
    ) async {
      ref.watch(progressLensRefreshTickProvider);
      ref.watch<int>(completionCommittedProvider);
      _assertActiveProfile(ref);
      final all = await ref.watch(learningLedgerProvider.future);
      final out = <String, List<LearningLedgerEntry>>{};
      for (final e in all) {
        (out[e.curriculumId.storageKey] ??= <LearningLedgerEntry>[]).add(e);
      }
      return out;
    });

/// Profile-wide program-enrollment load for [trackDualProgressMetricsProvider],
/// partitioned by curriculum storage key through the existing adapter seam.
final profileProgramsByProfileProvider =
    FutureProvider.autoDispose<Map<String, ProfileProgramEntity>>((ref) async {
      ref.watch(progressLensRefreshTickProvider);
      ref.watch<int>(completionCommittedProvider);
      _assertActiveProfile(ref);
      final repository = ref.watch(profileProgramRepositoryProvider);
      final programs = await Future.wait(
        CurriculumId.values.map((curriculum) async {
          final program = await repository.getProgram(curriculum);
          return (curriculum: curriculum, program: program);
        }),
      );
      return {
        for (final (:curriculum, :program) in programs)
          if (program != null) curriculum.storageKey: program,
      };
    });

/// Per-track dual-progress metrics for the active-track dashboard card.
///
/// Active tracks, completions, ledger entries, and program enrollment are all
/// read through their Firestore-backed presentation providers. The curriculum
/// is the sole track identity.
final trackDualProgressMetricsProvider =
    FutureProvider.autoDispose<List<TrackDualProgressMetric>>((ref) async {
      ref.watch(progressLensRefreshTickProvider);
      ref.watch<int>(completionCommittedProvider);
      _assertActiveProfile(ref);
      final progressService = ref.watch(trackProgressServiceProvider);
      final useHebrewTerms = domainTermLabelsFromRef(ref).isHebrew;
      final completionsByCurriculumFuture = ref.watch(
        trackCompletionsByProfileProvider.future,
      );
      final ledgerByCurriculumFuture = ref.watch(
        trackLedgerEntriesByProfileProvider.future,
      );
      final programsByCurriculumFuture = ref.watch(
        profileProgramsByProfileProvider.future,
      );
      final tracks = (await ref.watch(
        activeTracksProvider.future,
      )).where((track) => track.isActive).toList();

      final results = await Future.wait(
        tracks.map(
          (track) => _computeTrackDualProgressMetric(
            ref: ref,
            progressService: progressService,
            useHebrewTerms: useHebrewTerms,
            track: track,
            completionsByCurriculumFuture: completionsByCurriculumFuture,
            ledgerEntriesByCurriculumFuture: ledgerByCurriculumFuture,
            programsByCurriculumFuture: programsByCurriculumFuture,
          ),
        ),
      );

      return results.whereType<TrackDualProgressMetric>().toList();
    });

/// Computes a single track's [TrackDualProgressMetric], reading the
/// profile-wide batched completions/ledger/program-enrollment maps rather
/// than issuing its own per-track DAO queries. Returns `null` when the track
/// should be skipped (unknown curriculum key, missing content asset, or a
/// zero-item scope) — extracted from [trackDualProgressMetricsProvider] so
/// it can run concurrently across tracks via `Future.wait`.
///
/// Uses the already-batched curriculum-keyed reads, so concurrent tracks do
/// not issue one completion, ledger, or program query per row.
Future<TrackDualProgressMetric?> _computeTrackDualProgressMetric({
  required Ref ref,
  required TrackProgressService progressService,
  required bool useHebrewTerms,
  required CurriculumTrackEntity track,
  required Future<Map<String, List<CompletionEntity>>>
  completionsByCurriculumFuture,
  required Future<Map<String, List<LearningLedgerEntry>>>
  ledgerEntriesByCurriculumFuture,
  required Future<Map<String, ProfileProgramEntity>> programsByCurriculumFuture,
}) async {
  final curriculum = track.curriculumId;
  final scopedItems = await ref.watch(
    scopedCurriculumContentProvider(curriculum).future,
  );
  final leaves = scopedItems.where((item) => item.isLeaf).toList();
  final denominator = leaves.length;
  if (denominator == 0) return null;

  final currentCyclePercentage = await progressService.completionPercent(
    curriculumId: curriculum,
    tier: CompletionTierFilter.trackAchievement,
    totalItems: denominator,
    requireAllStages: false,
    since: track.activatedAt,
  );

  final completionsByCurriculum = await completionsByCurriculumFuture;
  final ledgerByCurriculum = await ledgerEntriesByCurriculumFuture;
  final key = curriculum.storageKey;
  final completions =
      completionsByCurriculum[key] ?? const <CompletionEntity>[];
  final ledgerEntries =
      ledgerByCurriculum[key] ?? const <LearningLedgerEntry>[];

  // The Firestore repositories used by these providers already exclude
  // purged documents. Keep the filter here as a defensive invariant so a
  // future repository implementation cannot resurrect retracted learning.
  final activeCompletions = completions.where((c) => c.purgedAt == null);
  final activeLedgerEntries = ledgerEntries.where((e) => e.purgedAt == null);
  const builder = LifetimeTreeBuilder();
  final lifetimeRefs = builder.computeLearnedLeafRefs(
    leaves: leaves,
    completedRefs: activeCompletions.map((c) => c.sefariaRef).toSet(),
    ledgerEntries: activeLedgerEntries.toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt)),
  );

  final programsByCurriculum = await programsByCurriculumFuture;
  final enrollment = programsByCurriculum[key];
  int? todayDueCount;
  int? overdueCount;
  if (enrollment != null) {
    try {
      final calendarPosition = await ref.read(
        programCalendarPositionProvider(curriculum).future,
      );
      final delta = calendarPosition.delta;
      overdueCount = delta < 0 ? (-delta - 1).clamp(0, 9999) : 0;
      todayDueCount = delta > 0 ? 0 : 1;
    } catch (e, st) {
      AppLogger.instance.warning(
        event: 'track_dual_progress_calendar_position_failed',
        fields: {'curriculum': key},
        exception: e,
        stackTrace: st,
      );
      overdueCount = 0;
      todayDueCount = 0;
    }
  }

  return TrackDualProgressMetric(
    trackLabel: curriculumLabelFor(curriculum, useHebrewTerms: useHebrewTerms),
    curriculumId: curriculum,
    currentCyclePercentage: currentCyclePercentage.clamp(0.0, 1.0),
    lifetimePercentage: (lifetimeRefs.length / denominator).clamp(0.0, 1.0),
    isProgramTrack: enrollment != null,
    todayDueCount: todayDueCount,
    overdueCount: overdueCount,
  );
}

// R8 Part B — memory-bounded header/denominator rewiring.
// (See original doc comment — unchanged.)
final lifetimeTotalsAcrossAllCurriculaProvider =
    FutureProvider.autoDispose<LifetimeTotals>((ref) async {
      ref.watch(progressLensRefreshTickProvider);
      ref.watch<int>(completionCommittedProvider);
      _assertActiveProfile(ref);

      final repo = ref.watch(contentRepositoryProvider);

      // F13-style batching: one profile-wide query each for completions and
      // ledger entries (grouped by curriculumId) instead of one query per
      // curriculum.
      final completionsByCurriculum = await ref.watch(
        completionsByProfileForLifetimeProvider.future,
      );
      final ledgerByCurriculum = await _ledgerByCurriculum(ref);

      const builder = LifetimeTreeBuilder();
      final allDistinct = <String>{};
      final learnedDistinct = <String>{};

      // Process ONE curriculum at a time so at most one curriculum's leaves
      // (two, transiently, for Tanach — the only composite — while its two
      // sources are assembled) are ever held in memory, instead of all 9
      // curricula being permanently cached at once.
      for (final curriculum in CurriculumId.values) {
        final leaves = await _boundedLeavesFor(repo, curriculum);
        if (leaves == null || leaves.isEmpty) continue;

        allDistinct.addAll(leaves.map((l) => l.sefariaRef));

        final key = curriculum.storageKey;
        final completedRefs =
            (completionsByCurriculum[key] ?? const <CompletionEntity>[])
                .map((c) => c.sefariaRef)
                .toSet();
        final ledgerEntries = _dropSyntheticContainerMarks(
          key,
          ledgerByCurriculum[key] ?? const <LearningLedgerEntry>[],
        );

        final learnedRefs = builder.computeLearnedLeafRefs(
          leaves: leaves,
          completedRefs: completedRefs,
          ledgerEntries: ledgerEntries,
        );
        learnedDistinct.addAll(learnedRefs);
      }

      return LifetimeTotals(
        learnedSections: learnedDistinct.length,
        totalSections: allDistinct.length,
        totalCurricula: CurriculumId.values.length,
      );
    });

/// Loads all ledger entries for the profile and partitions them by
/// `curriculumId.storageKey` in memory — the Firestore replacement for the
/// deleted `LearningLedgerDao.getEntriesGroupedByCurriculum()`.
Future<Map<String, List<LearningLedgerEntry>>> _ledgerByCurriculum(
  Ref ref,
) async {
  final all = await ref.watch(learningLedgerProvider.future);
  final out = <String, List<LearningLedgerEntry>>{};
  for (final e in all) {
    (out[e.curriculumId.storageKey] ??= <LearningLedgerEntry>[]).add(e);
  }
  return out;
}

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
/// Reuses [lifetimeTotalsAcrossAllCurriculaProvider] for the items count
/// (deduplicated across overlapping curricula) and reads completion events
/// directly to sum chazaros across all curricula in one pass.
final lifetimeHeaderCountersProvider =
    FutureProvider.autoDispose<LifetimeHeaderCounters>((ref) async {
      // Items learned — reuse the union logic.
      final totals = await ref.watch(
        lifetimeTotalsAcrossAllCurriculaProvider.future,
      );

      // Total chazaros — only REVIEW completion events (stageId > 1).
      // PP-4 fix: the previous `completions.length` counted ALL events,
      // including the initial limud (stageId == 1). A user who has learned
      // but never reviewed therefore saw a non-zero "total chazaros" equal
      // to their learn count — contradicting the per-leaf "Live · 0 chazaros"
      // display. Filtering to stageId > 1 gives the true review count.
      final completionsByCurriculum = await ref.watch(
        completionsByProfileForLifetimeProvider.future,
      );
      final allCompletions = completionsByCurriculum.values.expand((v) => v);

      return LifetimeHeaderCounters(
        itemsLearned: totals.learnedSections,
        totalChazaros: allCompletions.where((c) => c.stageId > 1).length,
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
final trackOnlyHeaderCountersProvider =
    FutureProvider.autoDispose<LifetimeHeaderCounters>((ref) async {
      ref.watch(progressLensRefreshTickProvider);
      ref.watch<int>(completionCommittedProvider);
      _assertActiveProfile(ref);
      // Track-achievement = live + bulkInTrack; lifetimeOnly is excluded at
      // the Firestore read layer. In the Firestore model the `completions`
      // collection can only ever hold `live`/`bulkInTrack` documents (a
      // `lifetimeOnly` document is rejected at write time by
      // CompletionEntity's rules), so ALL completions here are track-achievement
      // eligible. We still assert `c.source.creditsAchievement` for semantic
      // clarity and future-proofing.
      final completionsByCurriculum = await ref.watch(
        completionsByProfileForLifetimeProvider.future,
      );
      final trackCompletions = completionsByCurriculum.values
          .expand((v) => v)
          .where((c) => c.source.creditsAchievement);
      final distinctRefs = trackCompletions.map((c) => c.sefariaRef).toSet();
      // PP-4 fix: count only review events (stageId > 1), not the initial
      // limud, to match the "total chazaros" label semantics.
      return LifetimeHeaderCounters(
        itemsLearned: distinctRefs.length,
        totalChazaros: trackCompletions.where((c) => c.stageId > 1).length,
      );
    });

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Drops any ledger entry marking the SYNTHETIC container `level1` value of a
/// composite curriculum (Tanach's 'Torah'). A blanket mark on that synthetic
/// container would over-credit every leaf beneath it (the whole Torah from a
/// single-book mark) — see the P0 (composite over-credit) note on
/// [lifetimeDataProvider]. Shared by [lifetimeDataProvider] and
/// [lifetimeTotalsAcrossAllCurriculaProvider] so both apply the identical
/// filter. A no-op for every non-composite curriculum (`isSyntheticContainerLevel1`
/// returns `false` when there is no registered strategy for the key).
List<LearningLedgerEntry> _dropSyntheticContainerMarks(
  String curriculumStorageKey,
  List<LearningLedgerEntry> entries,
) {
  return entries.where((e) {
    final scope = e.entryScope.startsWith('unmark_')
        ? e.entryScope.substring('unmark_'.length)
        : e.entryScope;
    if (scope != 'level1') return true;
    return !CompositeCurriculumStrategy.isSyntheticContainerLevel1(
      curriculumStorageKey,
      e.unitIdentifier,
    );
  }).toList();
}

/// Loads [curriculum]'s LEAF items for [lifetimeTotalsAcrossAllCurriculaProvider]
/// without permanently retaining them, when the injected [repo] supports the
/// [LifetimeUnionLeafSource] capability (the real [ContentRepositoryImpl] in
/// production). Falls back to [_safeLoadLeaves] (which goes through
/// [ContentRepository.getContentForCurriculum], filtering `isLeaf`) for test
/// doubles that only implement the base [ContentRepository] interface — those
/// carry no real memory risk (synthetic, tiny fixture content).
Future<List<ContentItem>?> _boundedLeavesFor(
  ContentRepository repo,
  CurriculumId curriculum,
) async {
  if (repo is LifetimeUnionLeafSource) {
    final leafSource = repo as LifetimeUnionLeafSource;
    try {
      return await leafSource.loadLeavesTransient(curriculum);
    } catch (e, st) {
      // F20/D-E: log the asset failure, then propagate it so the achievement
      // totals provider exposes an error instead of omitting this curriculum.
      AppLogger.instance.warning(
        event: 'lifetime_totals_bounded_load_failed',
        fields: {'curriculum': curriculum.storageKey},
        exception: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
  return _safeLoadLeaves(repo, curriculum);
}

Future<List<ContentItem>?> _safeLoadLeaves(
  ContentRepository repo,
  CurriculumId curriculum,
) async {
  try {
    final content = await repo.getContentForCurriculum(curriculum);
    return content.where((item) => item.isLeaf).toList();
  } catch (e, st) {
    // F20/D-E: surface content-asset load failures instead of silently
    // producing an incomplete Lifetime Knowledge tree.
    AppLogger.instance.warning(
      event: 'lifetime_safe_load_failed',
      fields: {'curriculum': curriculum.storageKey, 'phase': 'leaves'},
      exception: e,
      stackTrace: st,
    );
    rethrow;
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
