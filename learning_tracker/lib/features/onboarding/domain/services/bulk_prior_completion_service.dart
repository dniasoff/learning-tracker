import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/content/hierarchy_selection.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_orchestrator.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

export 'package:learning_tracker/core/content/hierarchy_selection.dart';

/// Sentinel [DateTime] used by the bulk-mark-prior flow to stamp completions
/// that represent "learned in the past, not today". Matches
/// [SchedulerEngine.kBulkPriorSentinel].
///
/// Backed by core's [kBulkPriorSentinelMs] (features/ → core/ is a legal
/// import direction; see docs/coding-standards.md Rule 1/Rule 2) — the single
/// source of truth for the expunge query in
/// [BulkPriorCompletionService.expungePriorCompletions].
const kBulkPriorSentinel = Duration(milliseconds: kBulkPriorSentinelMs);

/// True when [completedAt] is the bulk-prior sentinel.
///
/// Compares the moment (not the object) because a sentinel completion that
/// has round-tripped through Firestore (`Timestamp` → local `DateTime`) or
/// Drift comes back with a different `isUtc` flag than the original
/// `DateTime.utc(2000, 1, 1)` — a plain `==` then silently returns false and
/// the prior-completions pre-tick fails. `isAtSameMomentAs` after `toUtc()`
/// is flag-independent.
bool isBulkPriorSentinel(DateTime completedAt) =>
    completedAt.toUtc().isAtSameMomentAs(kBulkPriorSentinelDate);

/// Result of a bulk prior completion operation.
class BulkPriorCompletionResult {
  final int itemCount;
  final int completionCount;
  final String? bookmarkSefariaRef;

  const BulkPriorCompletionResult({
    required this.itemCount,
    required this.completionCount,
    this.bookmarkSefariaRef,
  });
}

/// Service for bulk-marking prior completions during onboarding.
///
/// Resolves hierarchy selections (e.g., "all of Seder Zeraim") into
/// individual leaf items, creates completion records for ALL required stages
/// (learn + every chazara), and sets the bookmark to the first uncompleted
/// item.
///
/// ### B6 — All-stages requirement
/// Under the item-based completion rule (B1) an item is only "done" when
/// completion_events exist for **every** stage the track defines. [execute]
/// therefore looks up the full stage list for the curriculum and unions it
/// with the caller-supplied [stageIds] before writing completions. This
/// guarantees that prior-marked items show 100% completion, not 0%.
///
  /// ### B8 — Expunge API
  /// [expungePriorCompletions] tombstones (sets `purgedAt`) the completion
  /// documents that were created by a prior-marking run for an item. Under
  /// the Firestore schema, provenance lives on the document's `source` field:
  /// a bulk-imported row has `source == bulkInTrack` (its `completedAt` is the
  /// `DateTime.utc(2000, 1, 1)` sentinel written by [execute]); once
  /// [CompletionOrchestrator] upgrades it to real learning its `source`
  /// becomes `live` and it is INVISIBLE to expunge. That reproduces the old
  /// `prior_completion_imports`-table semantics with no second table (that
  /// table is deleted). Agent F (UI layer) calls this method when the user
  /// un-selects a previously bulk-marked item.
class BulkPriorCompletionService {
  final ContentRepository _contentRepository;
  final CompletionRepository _completionRepository;
  final BookmarkRepository _bookmarkRepository;
  final AnalyticsService _analytics;
  final StageDefinitionRepository? _stageRepository;

  /// Post completion-orchestrator lift (`docs/firestore-rewrite-map.md`,
  /// owner decision 1). When set, [execute] routes its bulk-mark write
  /// through [CompletionOrchestrator.bulkMarkComplete] instead of calling
  /// [_completionRepository] directly — required for achievement (siyum)
  /// detection to fire, since the repository no longer does that itself.
  ///
  /// **Optional, not required**, to avoid a breaking constructor change
  /// across this service's ~10 existing test call sites, most of which
  /// exercise dedup/bookmark/expunge behavior and never assert siyum
  /// outcomes. When `null`, [execute] falls back to calling
  /// `_completionRepository.bulkMarkComplete` directly — the storage write
  /// still happens correctly, but the four post-write side effects
  /// (points, streak, siyum, bookmark) do NOT fire, since the repository is
  /// storage-only now. Production wiring (`onboarding_providers.dart`)
  /// always supplies a real orchestrator; only test doubles that do not
  /// care about those side effects may omit it.
  final CompletionOrchestrator? _orchestrator;

  /// Cached content items from the last [resolveSelections] call.
  List<ContentItem>? _cachedAllItems;
  CurriculumId? _cachedCurriculumId;

  /// `database` (Drift `UserDatabase`), `syncEngine` (`SyncWriteFacade`) and
  /// `outboxDao` (Drift `OutboxDao`) are NOT parameters here: all three come
  /// from the deleted Drift user DB and the `core/sync` engine, and the
  /// Firestore repositories this service reaches through are profile-scoped by
  /// their collection path and write directly to `cloud_firestore` (which owns
  /// its own offline queueing), so neither a local DB nor an outbox DAO is
  /// part of the `expungePriorCompletions` path any more.
  ///
  /// ⚠️ This is a constructor-signature change vs. the Drift-era wiring: the
  /// `database`, `syncEngine` and `outboxDao` arguments are dropped. The
  /// production provider (`onboarding_providers.dart`) and the bulk-prior test
  /// doubles must drop them too.
  BulkPriorCompletionService({
    required ContentRepository contentRepository,
    required CompletionRepository completionRepository,
    required BookmarkRepository bookmarkRepository,
    AnalyticsService? analytics,
    StageDefinitionRepository? stageRepository,
    CompletionOrchestrator? orchestrator,
  }) : _contentRepository = contentRepository,
       _completionRepository = completionRepository,
       _bookmarkRepository = bookmarkRepository,
       _analytics = analytics ?? const NullAnalyticsService(),
       _stageRepository = stageRepository,
       _orchestrator = orchestrator;

  /// Resolve hierarchy selections into leaf-level sefariaRefs.
  ///
  /// Each selection can be at any level (seder, masechta, perek, or individual
  /// mishna). Container selections expand to all leaf items within.
  Future<List<ContentItem>> resolveSelections({
    required CurriculumId curriculumId,
    required List<HierarchySelection> selections,
  }) async {
    final allItems = await _contentRepository.getContentForCurriculum(
      curriculumId,
    );
    _cachedAllItems = allItems;
    _cachedCurriculumId = curriculumId;
    final leafItems = allItems.where((item) => item.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final selectedRefs = <String>{};

    for (final selection in selections) {
      // Filter all items matching this selection's hierarchy levels
      final matchingLeaves = leafItems.where((item) {
        if (selection.level1 != null && item.level1 != selection.level1) {
          return false;
        }
        if (selection.level2 != null && item.level2 != selection.level2) {
          return false;
        }
        if (selection.level3 != null && item.level3 != selection.level3) {
          return false;
        }
        if (selection.level4 != null && item.level4 != selection.level4) {
          return false;
        }
        return true;
      });

      for (final item in matchingLeaves) {
        selectedRefs.add(item.sefariaRef);
      }
    }

    return leafItems
        .where((item) => selectedRefs.contains(item.sefariaRef))
        .toList();
  }

  /// Resolve the full ordered list of stage IDs for [curriculumId].
  ///
  /// Returns the IDs sorted by [StageDefinition.stageOrder]. When no
  /// [StageDefinitionRepository] is injected (e.g. in tests that do not need
  /// B6 behaviour) falls back to the [fallback] list (default: `[1]`).
  ///
  /// ### Superseded stages
  /// [StageDefinitionRepository.getStagesForCurriculum] is backed by
  /// [StageDao.getStageDefinitionsByCurriculum], which filters
  /// `supersededAt IS NULL`. Superseded stage rows (left over from a
  /// previous track-edit operation) are therefore excluded here, so no
  /// phantom completions are written for stale stageOrders.
  ///
  /// Note: [StageDefinition] (the domain model) intentionally omits
  /// `supersededAt` — the filtering is enforced at the DAO layer.
  // Returns stageOrder values, not stage_definitions.id PKs.
  Future<List<int>> _allStageOrders(
    CurriculumId curriculumId, {
    List<int> fallback = const [1],
  }) async {
    if (_stageRepository == null) return fallback;
    final stages = await _stageRepository.getStagesForCurriculum(curriculumId);
    if (stages.isEmpty) {
      AppLogger.instance.warning(
        event:
            'BulkPriorCompletionService: no stage definitions found for '
            '$curriculumId — falling back to $fallback',
      );
      return fallback;
    }
    final ordered = [...stages]
      ..sort((a, b) => a.stageOrder.compareTo(b.stageOrder));
    return ordered.map((s) => s.stageOrder).toList();
  }

  /// Execute bulk mark of prior completions.
  ///
  /// B6 fix: ignores the caller-supplied [stageIds] and instead writes one
  /// completion record per (item × track-stage) so that every stage defined
  /// on the track is satisfied. The sentinel timestamp `DateTime.utc(2000,1,1)`
  /// is written to [completedAt] so downstream consumers (scheduler, streak
  /// restorer, items-learned screen) can distinguish these prior-mark records
  /// from genuine learning sessions.
  ///
  /// After writing, sets the bookmark to the first uncompleted item.
  ///
  /// Bulk-mark-prior is always the `bulkInTrack` source (B1 three-tier policy):
  /// engagement (streak + points) is unconditionally suppressed; achievement
  /// (siyumim) and lifetime totals are credited. There is no caller-tunable
  /// gamification flag — a "live" bulk-mark would be a contradiction in terms.
  ///
  /// Always operates on the CURRENTLY OPEN (active) profile — owner decision
  /// 2, `docs/firestore-rewrite-map.md`. This used to take an `int?
  /// profileId` naming a profile other than the session's (the live path was
  /// a parent adding a track for a specific child), but there is no way to
  /// resolve another profile's Firestore identity from a bare Drift int, and
  /// guessing would silently write one child's completions onto another's
  /// document tree, permanently. Removed rather than left in place and
  /// ignored. The one caller that used to pass a real cross-profile id
  /// (`AddTrackFlow` during onboarding, via `_applySelfPacedPriorCompletions`
  /// in `add_track_flow_screen.dart`) still threads a newly-created child's
  /// profile id through `AddTrackFlow.profileId`, but only for post-write
  /// invalidation now — `onboarding_screen.dart`'s `_onProfileCreated`
  /// switches the session's active profile to that child right after
  /// creation, before the add-track step is ever reached, so by the time
  /// this method runs the active profile already matches.
  Future<BulkPriorCompletionResult> execute({
    required CurriculumId curriculumId,
    required List<ContentItem> resolvedItems,

    /// Caller-supplied stage ids — kept for API compatibility but B6 replaces
    /// these with the full track stage list. Pass `[1]` from the UI as before;
    /// the service will union in all remaining stages automatically.
    required List<int> stageIds,
  }) async {
    final sefariaRefs = resolvedItems.map((item) => item.sefariaRef).toList();
    var totalCompletions = 0;

    // B6: determine the full ordered stage list for this track.
    // The configured set (superseded stages filtered at the DAO layer) covers
    // all active stages regardless of what the caller passes.
    final allConfiguredStageIds = await _allStageOrders(
      curriculumId,
      fallback: stageIds,
    );
    // Finding 10: ignore the caller-supplied stageIds; use only the
    // superseded-filtered configured set. The parameter is retained for
    // API compatibility — callers should pass [1] or empty.
    final effectiveStageIds = [...allConfiguredStageIds]..sort();

    // Create completions for each stage. Bulk-mark-prior is the bulkInTrack
    // source (B1 policy): engagement suppressed, achievement credited.
    for (final stageId in effectiveStageIds) {
      final request = BulkCompletionRequest(
        curriculumId: curriculumId.storageKey,
        sefariaRefs: sefariaRefs,
        stageId: stageId,
        trackType: 'personal',
        // profileId omitted — always the active profile now (owner decision
        // 2, see [execute]'s doc comment).
        // Engagement gate: prior-mark NEVER credits streak or points.
        awardGamificationPoints: false,
        // F1 (W7-A): bulk-mark-prior represents the `bulkInTrack` source —
        // engagement is suppressed, but achievement (siyum detection) must
        // fire so a learner who bulk-marks an entire masechta still earns
        // the corresponding unit/aggregate siyum ledger entry.
        creditsAchievement: true,
        completedAt: kBulkPriorSentinelDate, // sentinel: "learned in the past"
      );
      final orchestrator = _orchestrator;
      final completions = orchestrator != null
          ? await orchestrator.bulkMarkComplete(request)
          : await _completionRepository.bulkMarkComplete(request);
      totalCompletions += completions.length;
    }

    // Query DB for all existing completions for this curriculum — profileId
    // omitted, defaults to the active profile (owner decision 2).
    final existingCompletions = await _completionRepository
        .getCompletionsByCurriculum(curriculumId.storageKey);
    final allCompletedRefs = {
      ...sefariaRefs,
      ...existingCompletions.map((c) => c.sefariaRef),
    };

    // Set bookmark to first uncompleted item
    final bookmarkRef = await _findFirstUncompletedItem(
      curriculumId: curriculumId,
      completedRefs: allCompletedRefs,
    );

    if (bookmarkRef != null) {
      await _bookmarkRepository.setBookmark(
        curriculumId: curriculumId,
        sefariaRef: bookmarkRef,
      );
    }

    // Story 27.14 (DNI-390): fire analytics event when bulk-mark-prior completes.
    unawaited(
      _analytics.logBulkMarkPriorUsed(
        itemCount: sefariaRefs.length,
        completionCount: totalCompletions,
      ),
    );

    return BulkPriorCompletionResult(
      itemCount: sefariaRefs.length,
      completionCount: totalCompletions,
      bookmarkSefariaRef: bookmarkRef,
    );
  }

  /// B8 — Tombstone prior-mark completions for an item.
  ///
  /// Identifies the completion documents that a prior-marking run created for
  /// [sefariaRef] and tombstones them (stamps `purged_at`).
  ///
  /// Under the Firestore schema, provenance lives on the document's `source`
  /// field (`docs/firestore-rewrite-map.md`, "RESOLVED: prior-import tier
  /// tracking"): a bulk-imported completion has `source == bulkInTrack`; once
  /// [CompletionOrchestrator] upgrades it to real learning its `source`
  /// becomes `live` and it is INVISIBLE here. That reproduces the deleted
  /// `prior_completion_imports`-table semantics with no second table.
  ///
  /// A prior-marked completion is matched exactly on ALL of:
  ///   - `source == bulkInTrack`
  ///   - `trackType == 'personal'` (prior-marks are always on the personal track)
  ///   - `purgedAt == null` (an already-tombstoned row is left alone)
  ///   - `curriculumId == [curriculumId]`
  ///
  /// C3 invariant: erasure is a TOMBSTONE, never a delete —
  /// `FirestoreCompletionRepository.purgeCompletion` stamps `purged_at`, and
  /// `firestore.rules` sets `allow delete: if false`. Owner rulings D-L / D-M.
  ///
  /// **Tombstone propagation.** Under Drift this step enqueued each tombstone
  /// into a local outbox (`OutboxDao`) so the purge reached Firestore on the
  /// next sync. That outbox is deleted (`core/sync/` gone): the Firestore
  /// repositories write through `cloud_firestore` directly and rely on its own
  /// offline queueing, so no outbox DAO is part of this call path any more.
  ///
  /// **D-M — siyum retraction.** Because [execute] marks prior items with
  /// `creditsAchievement: true`, each one earned a siyum in `learning_ledger`.
  /// Un-ticking must retract that ledger entry alongside the completion, or the
  /// two collections disagree permanently. That path goes through
  /// `FirestoreLearningLedgerRepository.purgeEntry({ulid, purgedAt})`.
  ///
  /// `profileId` is intentionally gone: the Firestore repositories are profile-
  /// scoped by their collection path (`.../learner_profiles/{profileId}/...`),
  /// so the profile is path-scoped, not a parameter (owner decision 2,
  /// `docs/firestore-rewrite-map.md`). The only caller that used to thread a
  /// cross-profile id switched the session's active profile before this runs.
  ///
  /// Agent F (UI layer, `bulk_mark_screen.dart`) calls this when the user
  /// un-selects a previously bulk-marked item so the item reverts to "not
  /// started" status.
  Future<void> expungePriorCompletions({
    required String sefariaRef,
    required CurriculumId curriculumId,
  }) async {
    // ── 1. Identify the bulkInTrack completions to tombstone ─────────────────
    // D-L: reads are profile-scoped to the active profile via
    // `getCompletionsForContentItem` (no `profileId` parameter needed),
    // replacing the Drift path-segment lookup. A row upgraded to `live` by
    // [CompletionOrchestrator] (the B8 upgrade) carries `source == live` and is
    // therefore excluded here and left untouched — provenance is on the
    // document, not a separate import table.
    final candidates =
        await _completionRepository.getCompletionsForContentItem(sefariaRef);
    final toExpunge = candidates
        .where((c) =>
            c.curriculumId == curriculumId &&
            c.trackType == 'personal' &&
            c.source == CompletionSource.bulkInTrack &&
            c.purgedAt == null)
        .toList();

    if (toExpunge.isEmpty) {
      // Nothing to expunge. An empty result is a valid, loud answer (D-E): it
      // means no `bulkInTrack` rows exist for this item — it is NOT a silent
      // "0".
      return;
    }

    // ── 2. Tombstone + retract the siyum each earned (D-L / D-M) ───────────
    // D-E: a path that cannot do its job must fail LOUDLY, never silently no-op.
    //
    // Purging the completion documents (stamping `purged_at` via
    // `FirestoreCompletionRepository.purgeCompletion`) and retracting each siyum
    // (via
    // `FirestoreLearningLedgerRepository.purgeEntry({ulid, purgedAt})`)
    // requires seams the domain's repository interfaces do NOT yet expose — and
    // reaching the Firestore concrete classes directly from this domain service
    // is forbidden by AD-23/AD-28 (domain may not depend on the data-access
    // ring) and infeasible (`FirestoreCompletionRepository` /
    // `FirestoreLearningLedgerRepository` are not Riverpod providers and need
    // `FirebaseFirestore`/`uid`/`profileId`, which Rule 3 confines to
    // `core/sync` + `core/auth`).
    //
    // A silent return here (the Drift-era "if no outbox, log + skip") would
    // leave the bulk-marked completions AND their siyum both alive — a silent
    // `completions` / `learning_ledger` disagreement no gate can catch. Throwing
    // keeps it visible.
    throw UnsupportedError(
      'BulkPriorCompletionService.expungePriorCompletions: located '
      '${toExpunge.length} bulkInTrack completion(s) for '
      '(curriculum=${curriculumId.storageKey}, sefariaRef=$sefariaRef) that '
      'require tombstoning (D-L: purgeCompletion) and siyum retraction '
      '(D-M: purgeEntry), but the domain repository interfaces do not yet '
      'expose either seam. Migration path: (1) add '
      'Future<void> purgeCompletion({required CurriculumId curriculumId, '
      'required String sefariaRef, required int stageId, required DateTime '
      'purgedAt}) to CompletionRepository '
      '(lib/features/learning/domain/repositories/completion_repository.dart), '
      'implemented in FirestoreCompletionRepositoryAdapter '
      '(lib/features/learning/data/repositories/completion_repository_impl.dart) '
      'by delegating to FirestoreCompletionRepository.purgeCompletion '
      '(lib/data/repositories/firestore_completion_repository.dart); (2) add '
      'Future<void> purgeEntry({required String ulid, required DateTime '
      'purgedAt}) to LearningLedgerRepository '
      '(lib/features/learning/domain/repositories/learning_ledger_repository.dart), '
      'implemented in its adapter, and inject a LearningLedgerRepository into '
      'this service so each purged completion can retract the ledger entry it '
      'earned. Until those exist, expunge must fail loud rather than leave '
      'bulk-marked completions and their siyum both alive.',
    );
  }

  /// Find the first uncompleted leaf item in learning order.
  Future<String?> _findFirstUncompletedItem({
    required CurriculumId curriculumId,
    required Set<String> completedRefs,
  }) async {
    final allItems =
        (_cachedCurriculumId == curriculumId && _cachedAllItems != null)
        ? _cachedAllItems!
        : await _contentRepository.getContentForCurriculum(curriculumId);
    final leafItems = allItems.where((item) => item.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final item in leafItems) {
      if (!completedRefs.contains(item.sefariaRef)) {
        return item.sefariaRef;
      }
    }
    return null; // All items completed
  }
}
