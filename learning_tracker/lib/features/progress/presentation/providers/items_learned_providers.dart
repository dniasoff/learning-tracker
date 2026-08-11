import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/strategies/composite_curriculum_strategy.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_ledger_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';

/// Summary of per-curriculum completion data for the Items Learned /
/// Lifetime View screens.
class CurriculumCompletionSummary {
  const CurriculumCompletionSummary({
    required this.curriculumId,
    required this.learnedLeafCount,
    required this.totalLeafCount,
    required this.tree,
  });

  final CurriculumId curriculumId;
  final int learnedLeafCount;
  final int totalLeafCount;
  final List<LifetimeTreeNode> tree;

  double get percentage =>
      totalLeafCount > 0 ? learnedLeafCount / totalLeafCount : 0.0;
}

// ---------------------------------------------------------------------------
// Testable service functions — used by providers below and by tests directly.
// ---------------------------------------------------------------------------

/// Compute track-achievement curriculum completion summary.
///
/// [trackCompletions] must be the profile's completions for [curriculum] with
/// track-achievement semantics (live + bulkInTrack). Under the Firestore
/// model every document in the `completions` collection already qualifies
/// (`CompletionSource.lifetimeOnly` never enters it — it writes only a
/// `learning_ledger` entry), so the tier-filtered DAO read is now the plain
/// `getCompletionsByCurriculum` call site in the provider, and this function
/// takes the already-fetched list.
///
/// Returns `null` when the curriculum has no content or no track completions.
Future<CurriculumCompletionSummary?> computeItemsLearnedSummary({
  required List<CompletionEntity> trackCompletions,
  required ContentRepository repo,
  required CurriculumId curriculum,
}) async {
  // R8 (OOM): fetch completions FIRST and bail before loading content. A
  // curriculum with no track completions returned null anyway, so doing the
  // cheap read first means the 8 untouched curricula in the aggregate never
  // force-load (and PERMANENTLY cache) their full ~N-item content — the
  // ContentRepository._contentCache growth that OOM-killed the process on a
  // 512 MB heap. Output is provably identical: the only path removed is the
  // wasted materialize-then-return-null on an empty-completions curriculum.
  if (trackCompletions.isEmpty) return null;

  // Load all leaves for this curriculum.
  List<ContentItem> leaves;
  try {
    final content = await repo.getContentForCurriculum(curriculum);
    leaves = content.where((item) => item.isLeaf).toList();
  } catch (_) {
    return null;
  }
  if (leaves.isEmpty) return null;

  final completedRefs = trackCompletions.map((c) => c.sefariaRef).toSet();
  final leafRefs = leaves.map((l) => l.sefariaRef).toSet();
  final learnedCount = completedRefs.intersection(leafRefs).length;

  // Per-leaf provenance for the "Track learning only" view. lifetimeOnly is
  // excluded by the trackAchievement filter so only live and bulkMarked
  // entries appear here.
  final leafProvenance = _trackProvenanceForCurriculum(trackCompletions);

  final heLookup = await _heLabelLookupForCurriculum(repo, curriculum);
  const builder = LifetimeTreeBuilder();
  final tree = builder.buildTree(
    curriculum,
    leaves,
    completedRefs,
    heLabelLookup: heLookup,
    leafProvenance: leafProvenance,
  );

  return CurriculumCompletionSummary(
    curriculumId: curriculum,
    learnedLeafCount: learnedCount,
    totalLeafCount: leaves.length,
    tree: tree,
  );
}

/// Compute lifetime curriculum completion summary (all sources: track
/// completions + ledger-based lifetime/bulk marks).
///
/// [completions] is the profile's completions for [curriculum] and [ledger]
/// its learning-ledger entries. In the Firestore model a `lifetimeOnly` mark
/// writes ONLY a ledger entry (never a `completions` document), so "all
/// sources" is exactly these two lists — the old third Drift surface,
/// `prior_completion_imports`, is gone.
///
/// Delegates to [LifetimeTreeBuilder.computeLearnedLeafRefs] — the SAME
/// algorithm [lifetimeDataProvider] uses — rather than a private
/// reimplementation, so the P0 composite-over-credit guard below (and any
/// future fix to the shared algorithm) applies to both surfaces from one
/// implementation.
///
/// Returns `null` when the curriculum has no content or nothing learned.
Future<CurriculumCompletionSummary?> computeLifetimeViewSummary({
  required List<CompletionEntity> completions,
  required List<LearningLedgerEntry> ledger,
  required ContentRepository repo,
  required CurriculumId curriculum,
}) async {
  // P0 (composite over-credit) READ-TIME guard — mirrors
  // lifetimeDataProvider's guard in lifetime_knowledge_providers.dart. A
  // COMPOSITE curriculum (Tanach) re-parents its source leaves under a
  // SYNTHETIC level1 container (e.g. 'Torah') that exists in no real
  // curriculum. A stray `tanach/level1/'Torah'` ledger row blanket-credits
  // the ENTIRE Torah from a single-book mark — and the v32 migration that
  // deletes it only runs once per account DB, so it cannot be relied on.
  // Defensively DROP any synthetic-container level1 (and its unmark_) row
  // here so the shared learned-refs computation never credits it.
  final rawLedger = ledger.where((e) {
    final scope = e.entryScope.startsWith('unmark_')
        ? e.entryScope.substring('unmark_'.length)
        : e.entryScope;
    if (scope != 'level1') return true;
    return !CompositeCurriculumStrategy.isSyntheticContainerLevel1(
      curriculum.storageKey,
      e.unitIdentifier,
    );
  }).toList();

  // R8 (OOM): if the profile has NEITHER completions NOR ledger rows for this
  // curriculum, computeLearnedLeafRefs below can only return an empty set (it
  // seeds learnedRefs from completedRefs and only grows it via ledger actions),
  // so the original `learnedRefs.isEmpty` guard would have returned null anyway.
  // Bail here — a STRICT SUBSET of that guard — BEFORE force-loading (and
  // PERMANENTLY caching) this curriculum's full content, so the untouched
  // curricula in the aggregate no longer each materialize ~N items into
  // ContentRepository._contentCache (the R8 OOM driver). The
  // completions-nonempty-but-learnedRefs-empty case still falls through to the
  // original guard below, unchanged.
  if (completions.isEmpty && rawLedger.isEmpty) return null;

  // computeLearnedLeafRefs requires ledger entries newest-first by
  // completedAt (first-write-wins tie-break). The Firestore ledger read is
  // doc-id (ULID) ordered, which is NOT completedAt order — a bulk/lifetime
  // entry carries the kBulkPriorSentinelDate, so ULID order would let a
  // sentinel-dated row beat a real one. Re-sort explicitly, exactly as
  // `_computeTrackDualProgressMetric` does for its combined ledger.
  final orderedLedger = [...rawLedger]
    ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

  List<ContentItem> leaves;
  try {
    final content = await repo.getContentForCurriculum(curriculum);
    leaves = content.where((item) => item.isLeaf).toList();
  } catch (_) {
    return null;
  }
  if (leaves.isEmpty) return null;

  const builder = LifetimeTreeBuilder();
  final learnedRefs = builder.computeLearnedLeafRefs(
    leaves: leaves,
    completedRefs: completions.map((c) => c.sefariaRef).toSet(),
    ledgerEntries: orderedLedger,
  );

  if (learnedRefs.isEmpty) return null;

  // Per-leaf provenance for the "All sources" view — includes lifetimeOnly
  // imports and ledger-derived lifetime marks.
  final leafProvenance = _allSourcesProvenanceForCurriculum(
    completions: completions,
    learnedRefs: learnedRefs,
  );

  final heLookup = await _heLabelLookupForCurriculum(repo, curriculum);
  final tree = builder.buildTree(
    curriculum,
    leaves,
    learnedRefs,
    heLabelLookup: heLookup,
    leafProvenance: leafProvenance,
  );

  return CurriculumCompletionSummary(
    curriculumId: curriculum,
    learnedLeafCount: learnedRefs.length,
    totalLeafCount: leaves.length,
    tree: tree,
  );
}

// ---------------------------------------------------------------------------
// Riverpod providers — thin wrappers around the service functions above.
// ---------------------------------------------------------------------------

/// Thrown when [itemsLearnedDataProvider] / [lifetimeViewDataProvider] runs
/// with no active profile.
///
/// The Firestore completions/ledger collections live under
/// `learner_profiles/{profileId}/...` and every read provider here resolves
/// for the ACTIVE profile only — there is no way to read another profile's
/// data from this file. Owner ruling D-E: fail LOUDLY rather than quietly
/// serve stale/empty data.
///
/// AD-24 correction: these providers used to be keyed by an `int profileId`
/// argument, checked against the (String ULID) active profile — comparing
/// an `int` to a `String?` is never equal, so that guard threw
/// unconditionally, on every call, regardless of whether a profile was
/// actually active (confirmed: this file did not even compile — the
/// exception class below assigned that same `String?` to an `int` field).
/// There was never a legitimate "read someone else's profile" case to guard
/// against in the Firestore model — every provider these functions read
/// from is already scoped to the active profile by its collection path —
/// so the argument added a broken check, not a real capability. Removed;
/// these now only guard "no active profile at all".
class ItemsLearnedNoActiveProfileException implements Exception {
  const ItemsLearnedNoActiveProfileException();

  @override
  String toString() =>
      'ItemsLearnedNoActiveProfileException: an Items Learned / Lifetime '
      'View provider was read with no active profile — the Firestore '
      'completions/ledger are scoped to the active profile and there is '
      'nothing to read without one.';
}

/// Guards a provider against running with no active profile (D-E). Watches
/// [activeProfileIdProvider] synchronously so the dependency is registered
/// (and this provider rebuilds on profile switch) before any await.
void _assertActiveProfile(Ref ref) {
  if (ref.watch(activeProfileIdProvider) == null) {
    throw const ItemsLearnedNoActiveProfileException();
  }
}

/// Per-curriculum summary for track-achievement completions only
/// (live + bulkInTrack; excludes lifetimeOnly and ledger-based lifetime marks)
/// for the ACTIVE profile.
final itemsLearnedDataProvider = FutureProvider.autoDispose
    .family<CurriculumCompletionSummary?, CurriculumId>((
      ref,
      curriculumId,
    ) async {
      // ILP-01: recompute whenever a completion is committed so the Items
      // Learned and Lifetime View screens stay live without pull-to-refresh.
      ref.watch<int>(completionCommittedProvider);
      _assertActiveProfile(ref);
      // Capture every provider dependency synchronously, before any await —
      // this autoDispose family is rebuilt on commit and a ref.read/ref.watch
      // after an async gap throws "Cannot use Ref after dispose".
      final completionRepository = ref.watch(completionRepositoryProvider);
      final repo = ref.watch(contentRepositoryProvider);
      final trackCompletions = await completionRepository
          .getCompletionsByCurriculum(curriculumId.storageKey);
      return computeItemsLearnedSummary(
        trackCompletions: trackCompletions,
        repo: repo,
        curriculum: curriculumId,
      );
    });

/// Aggregated track-only summaries across all curricula for the ACTIVE
/// profile.
final itemsLearnedSummariesProvider =
    FutureProvider.autoDispose<List<CurriculumCompletionSummary>>((ref) async {
      final results = await Future.wait(
        CurriculumId.values.map(
          (curriculum) =>
              ref.watch(itemsLearnedDataProvider(curriculum).future),
        ),
      );
      return results.whereType<CurriculumCompletionSummary>().toList();
    });

/// Per-curriculum summary for ALL completions — track completions plus
/// ledger-based lifetime marks — for the ACTIVE profile.
///
/// Delegates to [computeLifetimeViewSummary].
final lifetimeViewDataProvider = FutureProvider.autoDispose
    .family<CurriculumCompletionSummary?, CurriculumId>((
      ref,
      curriculumId,
    ) async {
      // ILP-01: recompute whenever a completion is committed so the Lifetime
      // View screen stays live without pull-to-refresh.
      ref.watch<int>(completionCommittedProvider);
      _assertActiveProfile(ref);
      final completionRepository = ref.watch(completionRepositoryProvider);
      final repo = ref.watch(contentRepositoryProvider);
      final ledgerFuture = ref.watch(
        curriculumLedgerProvider(curriculumId.storageKey).future,
      );
      final completions = await completionRepository.getCompletionsByCurriculum(
        curriculumId.storageKey,
      );
      final ledger = await ledgerFuture;
      return computeLifetimeViewSummary(
        completions: completions,
        ledger: ledger,
        repo: repo,
        curriculum: curriculumId,
      );
    });

/// Aggregated lifetime summaries across all curricula for the ACTIVE
/// profile.
final lifetimeViewSummariesProvider =
    FutureProvider.autoDispose<List<CurriculumCompletionSummary>>((ref) async {
      final results = await Future.wait(
        CurriculumId.values.map(
          (curriculum) =>
              ref.watch(lifetimeViewDataProvider(curriculum).future),
        ),
      );
      return results.whereType<CurriculumCompletionSummary>().toList();
    });

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

Future<Map<String, String>> _heLabelLookupForCurriculum(
  ContentRepository repo,
  CurriculumId curriculum,
) async {
  try {
    final content = await repo.getContentForCurriculum(curriculum);
    final out = <String, String>{};
    for (final it in content) {
      if (it.isLeaf) continue;
      final key = [
        it.level1,
        it.level2,
        it.level3,
        it.level4,
      ].where((s) => s != null && s.isNotEmpty).join('|');
      if (key.isEmpty) continue;
      if (it.displayNameHe.isEmpty) continue;
      out[key] = it.displayNameHe;
    }
    return out;
  } catch (_) {
    return const {};
  }
}

/// Computes per-leaf provenance for the "Track learning only" tier.
///
/// The Drift-era `prior_completion_imports` table is gone: a completion's
/// provenance now lives on the document itself as [CompletionEntity.source]
/// (`'live'` vs `'bulkInTrack'`), so this is a pure in-memory pass over
/// [trackCompletions] — no query, and no separate bulk-import read. Maps
/// each completion's ref to [LifetimeLeafSource.live] unless a bulkInTrack
/// row exists — then it's [LifetimeLeafSource.bulkMarked].
Map<String, LifetimeLeafProvenance> _trackProvenanceForCurriculum(
  List<CompletionEntity> trackCompletions,
) {
  // B8 upgrade semantics preserved: the old writer DELETED the import row on
  // upgrade; the Firestore writer flips `source` to `live` on the document.
  // Either way an upgraded ref is absent from this set and reads as `live`.
  final bulkRefs = trackCompletions
      .where((c) => c.source == CompletionSource.bulkInTrack)
      .map((c) => c.sefariaRef)
      .toSet();

  // Count events per ref so live entries can show "Live · N chazaros".
  final eventCount = <String, int>{};
  for (final c in trackCompletions) {
    eventCount[c.sefariaRef] = (eventCount[c.sefariaRef] ?? 0) + 1;
  }

  final out = <String, LifetimeLeafProvenance>{};
  for (final entry in eventCount.entries) {
    final ref = entry.key;
    final count = entry.value;
    if (bulkRefs.contains(ref)) {
      out[ref] = LifetimeLeafProvenance(
        source: LifetimeLeafSource.bulkMarked,
        chazarosCount: count,
      );
    } else {
      out[ref] = LifetimeLeafProvenance(
        source: LifetimeLeafSource.live,
        chazarosCount: count,
      );
    }
  }
  return out;
}

/// Computes per-leaf provenance for the "All sources" tier.
///
/// Mirrors [LifetimeTreeBuilder.computeLeafProvenance] semantics. The Drift
/// `prior_completion_imports` surface is gone, so the two import sets come
/// from where the data actually lives now: [CompletionEntity.source] for
/// bulk marks, and the ledger for lifetime marks. Ref learned exclusively via
/// the ledger (a `lifetimeOnly` mark, or a scope mark expanded to leaves)
/// flow through [ledgerLearnedRefs], which
/// [LifetimeTreeBuilder.computeLeafProvenance] classifies as
/// `lifetimeImported` with `chazarosCount = 0`.
Map<String, LifetimeLeafProvenance> _allSourcesProvenanceForCurriculum({
  required List<CompletionEntity> completions,
  required Set<String> learnedRefs,
}) {
  final eventRefs = completions.map((c) => c.sefariaRef).toSet();
  final bulkRefs = completions
      .where((c) => c.source == CompletionSource.bulkInTrack)
      .map((c) => c.sefariaRef)
      .toSet();

  // Ledger-only refs: any ref in [learnedRefs] not covered by completions.
  // These are the lifetimeOnly marks (which never enter the completions
  // collection) plus scope marks expanded to leaves.
  final ledgerOnly = learnedRefs.difference(eventRefs.union(bulkRefs));

  return LifetimeTreeBuilder.computeLeafProvenance(
    completionEventRefs: completions.map((c) => c.sefariaRef).toList(),
    bulkImportedRefs: bulkRefs,
    lifetimeImportedRefs: const {},
    ledgerLearnedRefs: ledgerOnly,
  );
}
