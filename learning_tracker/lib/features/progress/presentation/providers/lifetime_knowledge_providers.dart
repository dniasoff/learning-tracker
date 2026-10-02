/// Lifetime knowledge Riverpod providers.
///
/// Every learnt number, tree state and chazara count here reads the
/// active learner's [LearnerState] (DNI-474, AD-35 "Reads"): the engine's
/// learnt set and counted learn events. Content (leaves, labels) comes
/// from the bundled ContentIndex; nothing reads completions, the learning
/// ledger or `learning_events`.
///
/// Domain models and the tree layout live in:
/// - `progress/domain/models/lifetime_knowledge.dart` — [LifetimeTreeNode],
///   [CurriculumLifetimeSummary], [TrackDualProgressMetric], [LifetimeTotals]
/// - `progress/domain/services/lifetime_tree_builder.dart` — [LifetimeTreeBuilder]
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/curriculum_overlap_registry.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/calendar_position_providers.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';
import 'package:learning_tracker/features/progress/domain/services/learner_progress.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';
import 'package:learning_tracker/features/progress/presentation/providers/learner_progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_lens_refresh_tick_provider.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
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

/// Thrown when a provider in this file runs with no active learner: there
/// is no [LearnerState] to read (owner ruling D-E: fail loudly rather than
/// serve empty data).
class LifetimeKnowledgeNoActiveProfileException implements Exception {
  const LifetimeKnowledgeNoActiveProfileException();

  @override
  String toString() =>
      'LifetimeKnowledgeNoActiveProfileException: a Lifetime Knowledge '
      'provider was read with no active learner — there is no learner '
      'state to read without one.';
}

/// The active learner's state, or [LifetimeKnowledgeNoActiveProfileException]
/// when no learner is active. Loading while the state pages in.
Future<LearnerState> _requireLearnerState(Ref ref) async {
  final state = await watchActiveLearnerState(ref);
  if (state == null) throw const LifetimeKnowledgeNoActiveProfileException();
  return state;
}

/// The storage keys of [curriculum] and the subset curricula a composite
/// display curriculum unions in (I-4: e.g. Chumash and Nach under Tanach).
Set<String> _withSubsets(CurriculumId curriculum) => {
  curriculum.storageKey,
  for (final subset in subsetsOf(curriculum)) subset.storageKey,
};

/// Per-curriculum lazy lifetime data provider.
///
/// The curriculum's whole ContentIndex tree, marked with the engine's
/// learnt set (plus its subset curricula's learnt leaves, I-4) and each
/// leaf's counted-learning provenance. Returns `null` when the
/// curriculum's content asset is empty so callers can skip it.
final lifetimeDataProvider = FutureProvider.autoDispose
    .family<CurriculumLifetimeSummary?, CurriculumId>((ref, curriculum) async {
      ref.watch(progressLensRefreshTickProvider);
      final state = await _requireLearnerState(ref);
      final repo = ref.watch(contentRepositoryProvider);

      final leaves = await _safeLoadLeaves(repo, curriculum);
      if (leaves == null || leaves.isEmpty) return null;

      final corpus = await ref.watch(progressCorpusProvider(curriculum).future);
      final keys = _withSubsets(curriculum);
      final learnt = learntLeavesFor(
        state,
        curriculum.storageKey,
        subsetIds: keys.difference({curriculum.storageKey}),
        corpus: corpus,
      );
      final provenance = corpus == null
          ? const <String, LifetimeLeafProvenance>{}
          : LifetimeTreeBuilder.provenanceFromActivity(
              leafActivityOf(state, corpus, curricula: keys),
            );
      final heLookup = await _safeHeLabelLookup(repo, curriculum);

      return const LifetimeTreeBuilder().build(
        curriculum: curriculum,
        leaves: leaves,
        learnedRefs: learnt,
        heLabelLookup: heLookup,
        leafProvenance: provenance,
      );
    });

/// Aggregated lifetime summaries across all curricula.
///
/// Reads from [lifetimeDataProvider] per curriculum, so a single-curriculum
/// tap only loads that curriculum's data.
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
/// When only a single curriculum is needed, prefer
/// [lifetimeDataProvider] to avoid loading all 9 curricula.
@Deprecated('Use lifetimeSummariesProvider or lifetimeDataProvider instead')
final globalLifetimeCurriculaProvider = lifetimeSummariesProvider;

/// Profile-wide program-enrollment load for [trackDualProgressMetricsProvider],
/// partitioned by curriculum storage key through the existing adapter seam.
final profileProgramsByProfileProvider =
    FutureProvider.autoDispose<Map<String, ProfileProgramEntity>>((ref) async {
      ref.watch(progressLensRefreshTickProvider);
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
/// * `currentCyclePercentage` — FR-14 goal progress: the engine's distinct
///   learnt count of the curriculum (every source and date state, repeats
///   once) over the learner's scoped leaf count.
/// * `lifetimePercentage` — the engine's learnt leaves (with subset
///   curricula, I-4) over every leaf of the curriculum.
final trackDualProgressMetricsProvider =
    FutureProvider.autoDispose<List<TrackDualProgressMetric>>((ref) async {
      ref.watch(progressLensRefreshTickProvider);
      final state = await _requireLearnerState(ref);
      final useHebrewTerms = domainTermLabelsFromRef(ref).isHebrew;
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
            state: state,
            useHebrewTerms: useHebrewTerms,
            track: track,
            programsByCurriculumFuture: programsByCurriculumFuture,
          ),
        ),
      );

      return results.whereType<TrackDualProgressMetric>().toList();
    });

/// Computes a single track's [TrackDualProgressMetric]. Returns `null` when
/// the track should be skipped (missing content asset or a zero-item
/// scope).
Future<TrackDualProgressMetric?> _computeTrackDualProgressMetric({
  required Ref ref,
  required LearnerState state,
  required bool useHebrewTerms,
  required CurriculumTrackEntity track,
  required Future<Map<String, ProfileProgramEntity>> programsByCurriculumFuture,
}) async {
  final curriculum = track.curriculumId;
  final scopedItems = await ref.watch(
    scopedCurriculumContentProvider(curriculum).future,
  );
  final scopedLeaves = scopedItems.where((item) => item.isLeaf).toList();
  final denominator = scopedLeaves.length;
  if (denominator == 0) return null;

  final key = curriculum.storageKey;
  final distinct = state[key]?.distinctLearnt ?? 0;
  final corpus = await ref.watch(progressCorpusProvider(curriculum).future);
  final lifetimeTotal = corpus?.leaves.length ?? denominator;
  final lifetimeLearnt = learntLeavesFor(
    state,
    key,
    subsetIds: _withSubsets(curriculum).difference({key}),
    corpus: corpus,
  ).length;

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
    currentCyclePercentage: (distinct / denominator).clamp(0.0, 1.0),
    lifetimePercentage: lifetimeTotal == 0
        ? 0.0
        : (lifetimeLearnt / lifetimeTotal).clamp(0.0, 1.0),
    isProgramTrack: enrollment != null,
    todayDueCount: todayDueCount,
    overdueCount: overdueCount,
  );
}

/// Lifetime totals across every curriculum: distinct learnt leaves (the
/// union of the engine's learnt sets, so a leaf shared by overlapping
/// curricula counts once) over distinct leaves.
///
/// Leaves are loaded ONE curriculum at a time (bounded memory, R8 Part B).
final lifetimeTotalsAcrossAllCurriculaProvider =
    FutureProvider.autoDispose<LifetimeTotals>((ref) async {
      ref.watch(progressLensRefreshTickProvider);
      final state = await _requireLearnerState(ref);
      final repo = ref.watch(contentRepositoryProvider);

      final allDistinct = <String>{};
      final learnt = <String>{
        for (final c in state.curricula.values) ...c.learntLeaves,
      };
      final learnedDistinct = <String>{};
      for (final curriculum in CurriculumId.values) {
        final leaves = await _boundedLeavesFor(repo, curriculum);
        if (leaves == null || leaves.isEmpty) continue;
        for (final leaf in leaves) {
          allDistinct.add(leaf.sefariaRef);
          if (learnt.contains(leaf.sefariaRef)) {
            learnedDistinct.add(leaf.sefariaRef);
          }
        }
      }

      return LifetimeTotals(
        learnedSections: learnedDistinct.length,
        totalSections: allDistinct.length,
        totalCurricula: CurriculumId.values.length,
      );
    });

/// Header counters for the Lifetime Knowledge screen.
///
///   * **itemsLearned** — distinct learnt leaves (engine learnt sets).
///   * **totalChazaros** — the PRD "chazara" derived count: counted learn
///     events that learnt no leaf for the first time (AD-32).
class LifetimeHeaderCounters {
  const LifetimeHeaderCounters({
    required this.itemsLearned,
    required this.totalChazaros,
  });

  /// Distinct items learned across every source.
  final int itemsLearned;

  /// Counted repeats (chazaros).
  final int totalChazaros;
}

/// Header counters for the Lifetime Knowledge screen — "All sources".
final lifetimeHeaderCountersProvider =
    FutureProvider.autoDispose<LifetimeHeaderCounters>((ref) async {
      final totals = await ref.watch(
        lifetimeTotalsAcrossAllCurriculaProvider.future,
      );
      final state = await _requireLearnerState(ref);
      final corpora = await watchCorpora(ref);
      return LifetimeHeaderCounters(
        itemsLearned: totals.learnedSections,
        totalChazaros: chazaraCount(state, corpusFor: (c) => corpora[c]),
      );
    });

/// Header counters for the Lifetime Knowledge screen — "Track learning
/// only" (F3): learning recorded while tracking (`dated` / `catch_up`),
/// excluding before-tracking marks, matching [itemsLearnedSummariesProvider].
final trackOnlyHeaderCountersProvider =
    FutureProvider.autoDispose<LifetimeHeaderCounters>((ref) async {
      ref.watch(progressLensRefreshTickProvider);
      final state = await _requireLearnerState(ref);
      final corpora = await watchCorpora(ref);
      final tracked = <String>{};
      for (final curriculum in state.curricula.keys) {
        final corpus = corpora[curriculum];
        if (corpus == null) continue;
        for (final MapEntry(:key, :value) in leafActivityOf(
          state,
          corpus,
        ).entries) {
          if (value.trackedEvents > 0) tracked.add(key);
        }
      }
      return LifetimeHeaderCounters(
        itemsLearned: tracked.length,
        totalChazaros: chazaraCount(
          state,
          corpusFor: (c) => corpora[c],
          trackedOnly: true,
        ),
      );
    });

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Loads [curriculum]'s LEAF items for [lifetimeTotalsAcrossAllCurriculaProvider]
/// without permanently retaining them, when the injected [repo] supports the
/// [LifetimeUnionLeafSource] capability (the real [ContentRepositoryImpl] in
/// production). Falls back to [_safeLoadLeaves] for test doubles.
Future<List<ContentItem>?> _boundedLeavesFor(
  ContentRepository repo,
  CurriculumId curriculum,
) async {
  if (repo is LifetimeUnionLeafSource) {
    final leafSource = repo as LifetimeUnionLeafSource;
    try {
      return await leafSource.loadLeavesTransient(curriculum);
    } catch (e, st) {
      // F20/D-E: log the asset failure, then propagate it so the totals
      // provider exposes an error instead of omitting this curriculum.
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
    // F20: log the failure but keep the cold-path empty map so the screen
    // renders without Hebrew labels rather than crashing.
    AppLogger.instance.warning(
      event: 'lifetime_safe_load_failed',
      fields: {'curriculum': curriculum.storageKey, 'phase': 'he_labels'},
      exception: e,
      stackTrace: st,
    );
    return const {};
  }
}
