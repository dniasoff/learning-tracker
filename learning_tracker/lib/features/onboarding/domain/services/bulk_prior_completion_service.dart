import 'dart:async';

import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/content/hierarchy_selection.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/learning/completion_constants.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/repositories/bookmark_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/completion_repository.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
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
/// documents that were created by a prior-marking run for one or more
/// items (a single caller-supplied batch of `sefariaRef`s, not one call
/// per ref — see the method doc comment's "batched, not per-ref" section).
/// Under the Firestore schema, provenance lives on the document's `source`
/// field: a bulk-imported row has `source == bulkInTrack` (its
/// `completedAt` is the `DateTime.utc(2000, 1, 1)` sentinel written by
/// [execute]); once [CompletionOrchestrator] upgrades it to real learning
/// its `source` becomes `live` and it is INVISIBLE to expunge's
/// tombstone-selection step (the SIYUM-RETRACTION step that follows is a
/// separate filter with a different rule — see the method doc comment).
/// That reproduces the old `prior_completion_imports`-table semantics with
/// no second table (that table is deleted). Agent F (UI layer) calls this
/// method when the user un-selects one or more previously bulk-marked
/// items in a single action.
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

  /// D-M — siyum retraction collaborators. Both optional, mirroring
  /// [_orchestrator]'s precedent, so existing test call sites that never
  /// exercise [expungePriorCompletions]'s real body do not need a
  /// constructor change. Production wiring (`onboarding_providers.dart`)
  /// always supplies both; see [expungePriorCompletions]'s doc comment for
  /// what happens when a caller purges completions without wiring them.
  final CompletionDetectionService? _completionDetectionService;
  final LearningLedgerRepository? _ledgerRepository;

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
    CompletionDetectionService? completionDetectionService,
    LearningLedgerRepository? ledgerRepository,
  }) : _contentRepository = contentRepository,
       _completionRepository = completionRepository,
       _bookmarkRepository = bookmarkRepository,
       _analytics = analytics ?? const NullAnalyticsService(),
       _stageRepository = stageRepository,
       _orchestrator = orchestrator,
       _completionDetectionService = completionDetectionService,
       _ledgerRepository = ledgerRepository;

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

  /// B8 — Tombstone prior-mark completions for one or more items.
  ///
  /// Identifies the completion documents that a prior-marking run created for
  /// any ref in [sefariaRefs] (a single caller-supplied batch, not one call
  /// per ref — see the "Batched, not per-ref" section below) and tombstones
  /// them (stamps `purged_at`).
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
  /// `FirestoreLearningLedgerRepository.purgeEntry({ulid, purgedAt})` — but
  /// ONLY when the affected unit's remaining, non-purged completions no
  /// longer cover it (re-checked via
  /// [CompletionDetectionService.isUnitLimudComplete] AFTER the tombstones
  /// above are written), and only the HIGHEST-`completionNumber` matching
  /// entry is retracted.
  ///
  /// **Retraction is keyed on coverage, not provenance (owner ruling,
  /// 2026-08-11 — supersedes the original D-M text, which was silent on
  /// `source` and got read two contradictory ways by different parts of this
  /// codebase).** The candidate filter below does NOT check `source` at all:
  /// once a unit's remaining, non-purged completions genuinely no longer
  /// cover it, the highest-`completionNumber` non-purged ledger entry for
  /// that unit is retracted regardless of whether it happened to be earned
  /// by a bulk-mark or by live day-to-day learning. A `learning_ledger` entry
  /// represents "this unit was covered as of this `completionNumber`" — once
  /// that stops being true, WHICH action originally triggered the credit is
  /// not a reason to leave a now-false siyum standing. (`LearningLedgerEntry`'s
  /// class doc comment and this repository's `_parseSource` doc comment have
  /// been updated to match — neither claims a `live` entry is unretractable
  /// any more.)
  ///
  /// **The re-earn trapdoor is closed.** Earlier revisions of this method
  /// flagged, but did not fix, a gap where re-ticking every leaf of a unit
  /// whose siyum was retracted here left the siyum permanently invisible:
  /// [CompletionDetectionService] always resolves the SAME deterministic
  /// ulid for a given unit, so re-crediting found the tombstoned doc and
  /// returned it as-is. `FirestoreLearningLedgerRepository.recordCompletion`
  /// now RESTORES a tombstoned doc found at that ulid (clears `purged_at`,
  /// leaves `completedAt`/`completionNumber` untouched — see that method's
  /// doc comment for why) instead of returning it inert, so a
  /// retract-then-re-earn cycle round-trips correctly with no caller-side
  /// change needed here.
  ///
  /// **Batched, not per-ref.** This method takes [sefariaRefs] (plural) and
  /// processes them as ONE pass: every matched completion across every given
  /// ref is tombstoned first, then the DISTINCT set of affected units across
  /// all of them is computed (deduped by `(entryScope, unitIdentifier,
  /// trackType)` — un-ticking two pages of the same masechta in one user
  /// action affects the masechta unit exactly once), and exactly one
  /// coverage-check-and-retract pass runs per distinct unit within THIS call.
  /// `bulk_mark_screen.dart` calls this ONCE per user action with every
  /// un-ticked ref, not once per ref — an earlier revision's "known
  /// concurrency caveat" doc block described N interleaved `Future.wait`-
  /// driven per-ref calls racing the same unit's coverage check; that
  /// specific caller shape is gone. `getLedgerByCurriculumIncludingTombstoned`
  /// is likewise fetched once for the whole batch, not once per unit,
  /// cutting the redundant-reads cost the old concurrent per-ref shape used
  /// to multiply by un-ticked-item count.
  ///
  /// **This does NOT mean overlapping calls are impossible — they are just
  /// benign now.** `bulk_mark_screen.dart` still fires
  /// `unawaited(_expungeRefs(refs))` once per checkbox tap with no
  /// serialization between taps, so two rapid taps CAN still produce two
  /// overlapping `expungePriorCompletions` calls (e.g. un-ticking two
  /// different items of the same masechta in quick succession). Under the
  /// epoch rule this method's retraction step now follows (see the
  /// `candidates`/`highest` logic below), that race is benign rather than
  /// destructive: both overlapping calls target the same true-highest ledger
  /// entry for any unit they both touch, and `purgeEntry` is an idempotent
  /// stamp — a second purge of an already-purged doc, or a second call
  /// finding the true-highest entry already purged and stopping there
  /// (rather than reaching for the next-highest), is a safe no-op either
  /// way. Concurrent taps converge correctly instead of double-damaging
  /// anything; no caller-side serialization was needed to make that true.
  ///
  /// **Retry-safe / resumable.** An empty match for a given ref (nothing left
  /// to tombstone — e.g. a prior call already tombstoned it before throwing
  /// partway through) does NOT short-circuit this method. The content item
  /// and its affected unit(s) are still resolved for EVERY ref in
  /// [sefariaRefs], and the coverage-check-and-retract step still runs for
  /// every distinct affected unit regardless of whether anything was
  /// tombstoned this call — a no-op when the unit is still covered or its
  /// siyum was already retracted. Calling this repeatedly for the same
  /// `(sefariaRefs, curriculumId)` therefore converges correctly instead of
  /// getting stuck after one failed attempt (the failure mode a caller-side
  /// `if (toExpunge.isEmpty) return;` short-circuit used to produce).
  ///
  /// **`trackType` is derived, not hardcoded.** The coverage-check call
  /// passes the `trackType` actually carried by the purged completion(s) for
  /// that unit (falling back to `'personal'` — the only value the
  /// tombstone-selection filter below currently admits — when nothing was
  /// purged for a ref this call). Units are grouped by `(unit, trackType)`,
  /// so if this method ever purges completions across more than one
  /// `trackType` in a single call, each `trackType` gets its own
  /// coverage-check-and-retract pass rather than one call silently deciding
  /// for both.
  ///
  /// `profileId` is intentionally gone: the Firestore repositories are profile-
  /// scoped by their collection path (`.../learner_profiles/{profileId}/...`),
  /// so the profile is path-scoped, not a parameter (owner decision 2,
  /// `docs/firestore-rewrite-map.md`). The only caller that used to thread a
  /// cross-profile id switched the session's active profile before this runs.
  ///
  /// Agent F (UI layer, `bulk_mark_screen.dart`) calls this when the user
  /// un-selects one or more previously bulk-marked items so they revert to
  /// "not started" status.
  Future<void> expungePriorCompletions({
    required List<String> sefariaRefs,
    required CurriculumId curriculumId,
  }) async {
    if (sefariaRefs.isEmpty) return; // nothing requested — a genuine no-op.

    // ── 0. Fail BEFORE mutating anything (D-E, fail-before-mutate) ─────────
    // Checked first, before step 1/2 tombstone ANY completion document. A
    // misconfigured caller (missing collaborators) must fail with the store
    // left untouched — checking this only after the tombstone loop (the
    // earlier shape) would leave completions tombstoned with no way to
    // retract the siyum they were backing, on every single call from that
    // caller, not just some.
    final detectionService = _completionDetectionService;
    final ledgerRepository = _ledgerRepository;
    if (detectionService == null || ledgerRepository == null) {
      // D-E: unconditional — the coverage-check-and-retract step always runs
      // (that is what makes this method retry-safe), so a caller that didn't
      // wire the retraction collaborators is a real gap on every call, not
      // only the ones that happen to tombstone something.
      throw StateError(
        'BulkPriorCompletionService.expungePriorCompletions: no '
        'CompletionDetectionService/LearningLedgerRepository was supplied to '
        'check/retract the siyum(s) affected by (curriculum='
        '${curriculumId.storageKey}, sefariaRefs=$sefariaRefs) (D-M). Wire '
        "both in onboarding_providers.dart's "
        'bulkPriorCompletionServiceProvider.',
      );
    }

    // ── 1. Identify the bulkInTrack completions to tombstone, across ALL
    // given refs ─────────────────────────────────────────────────────────
    // D-L: reads are profile-scoped to the active profile via
    // `getCompletionsForContentItem` (no `profileId` parameter needed),
    // replacing the Drift path-segment lookup. A row upgraded to `live` by
    // [CompletionOrchestrator] (the B8 upgrade) carries `source == live` and is
    // therefore excluded here and left untouched — provenance is on the
    // document, not a separate import table.
    final toExpunge = <CompletionEntity>[];
    for (final sefariaRef in sefariaRefs) {
      final candidates = await _completionRepository
          .getCompletionsForContentItem(sefariaRef);
      toExpunge.addAll(
        candidates.where(
          (c) =>
              c.curriculumId == curriculumId &&
              c.trackType == 'personal' &&
              c.source == CompletionSource.bulkInTrack &&
              c.purgedAt == null,
        ),
      );
    }

    // ── 2. Tombstone every matched completion document (D-L) ───────────────
    final purgedAt = DateTime.now().toUtc();
    for (final c in toExpunge) {
      await _completionRepository.purgeCompletion(
        curriculumId: curriculumId,
        sefariaRef: c.sefariaRef,
        stageId: c.stageId,
        purgedAt: purgedAt,
      );
    }

    // ── 3. Retract the siyum(s) that no longer hold (D-M) ──────────────────
    // Retry-safe (see doc comment): this step runs regardless of whether
    // step 1/2 found anything to tombstone THIS call. Collaborators were
    // already validated in step 0, above, before anything was mutated.

    // Distinct affected units across every ref, keyed by
    // (entryScope, unitIdentifier, trackType) so un-ticking multiple refs
    // that share a unit only checks/retracts that unit once.
    final affectedUnits =
        <
          String,
          ({
            String entryScope,
            String unitIdentifier,
            String level1,
            String? level2,
            String trackType,
          })
        >{};

    for (final sefariaRef in sefariaRefs) {
      final item = await _contentRepository.getContentByRef(
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
      );
      if (item == null) {
        // D-E: even on a retry where nothing was tombstoned this call, being
        // unable to resolve the content item for a ref the caller explicitly
        // asked to expunge must not silently skip retraction for it.
        throw StateError(
          'BulkPriorCompletionService.expungePriorCompletions: '
          'ContentRepository.getContentByRef could not resolve the content '
          'item for sefariaRef=$sefariaRef, so the affected unit(s) for D-M '
          'retraction cannot be determined.',
        );
      }

      // Fix 5: derive trackType from what was actually purged for THIS ref
      // rather than hardcoding a literal — falls back to 'personal' (the
      // only value step 1's filter currently admits) when this ref had
      // nothing to tombstone this call (the retry-safe path).
      final purgedForRef = toExpunge.where((c) => c.sefariaRef == sefariaRef);
      final trackType = purgedForRef.isNotEmpty
          ? purgedForRef.first.trackType
          : 'personal';

      final unitsForItem =
          <
            ({
              String entryScope,
              String unitIdentifier,
              String level1,
              String? level2,
              String trackType,
            })
          >[
            if (item.level2 != null && hasNamedLevel2Unit(curriculumId))
              (
                entryScope: unitScopeFor(curriculumId, level: 2),
                unitIdentifier: item.level2!,
                level1: item.level1,
                level2: item.level2,
                trackType: trackType,
              ),
            (
              entryScope: unitScopeFor(curriculumId, level: 1),
              unitIdentifier: item.level1,
              level1: item.level1,
              level2: null,
              trackType: trackType,
            ),
          ];

      for (final unit in unitsForItem) {
        // Null-byte-separated key (mirrors the composite-key convention
        // FirestoreLearningLedgerRepository._nextCompletionNumber uses) so a
        // unitIdentifier/trackType value can never collide with the
        // delimiter itself.
        affectedUnits['${unit.entryScope}\u0000${unit.unitIdentifier}\u0000'
                '${unit.trackType}'] =
            unit;
      }
    }

    if (affectedUnits.isEmpty) return;

    // Fetched ONCE for the whole batch (Fix 4) — filtered in-memory per unit
    // below, which is safe because distinct units can never share a ledger
    // entry (entries are keyed by (entryScope, unitIdentifier)).
    //
    // Deliberately `getLedgerByCurriculumIncludingTombstoned`, NOT the plain
    // `getLedgerByCurriculum`. The epoch rule below needs to see already-
    // purged entries too (see that method's doc comment) — `getLedgerByCurriculum`
    // makes tombstoned entries invisible by design (D-M), which would make
    // the "already purged, stop here" check below unreachable and silently
    // degrade this back into the non-idempotent bug it exists to fix.
    final ledgerEntries = await ledgerRepository
        .getLedgerByCurriculumIncludingTombstoned(curriculumId);

    for (final unit in affectedUnits.values) {
      final stillCovered = await detectionService.isUnitLimudComplete(
        curriculum: curriculumId,
        level1: unit.level1,
        level2: unit.level2,
        trackType: unit.trackType,
      );
      // `null` (indeterminate — no leaves / no stage definitions found for
      // this unit) must NOT be read as "not covered": that would retract a
      // real siyum on missing/unreadable content data instead of failing
      // loudly (D-E). It also cannot be read as "still covered" (silently
      // stranding a phantom siyum), so it gets its own loud failure.
      if (stillCovered == null) {
        throw StateError(
          'BulkPriorCompletionService.expungePriorCompletions: coverage for '
          'unit (entryScope=${unit.entryScope}, '
          'unitIdentifier=${unit.unitIdentifier}) could not be determined '
          '(no leaf content items or no stage definitions found) — cannot '
          'safely decide whether to retract its siyum (D-M).',
        );
      }
      if (stillCovered) continue; // still covered — nothing to retract.

      // Epoch rule (owner ruling, 2026-08-11 — fixes the non-idempotent
      // retraction a code review caught): the candidate filter here does NOT
      // exclude already-purged entries. It must consider EVERY ledger entry
      // for this unit — purged or not — to find the TRUE highest
      // `completionNumber`, because `completionNumber` is monotonic and
      // counts tombstoned docs too (established when [purgeEntry]/
      // `_nextCompletionNumber` were built). Filtering to `purgedAt == null`
      // first (the old, buggy approach) meant a SECOND call — made while the
      // unit was still uncovered, whether a genuine retry or simply a later
      // unrelated call — would find a NEW "highest surviving" candidate and
      // retract that too, walking down the whole stack of historical entries
      // for the unit across repeated calls. That is exactly what D-M's
      // ruling text warns against: "retracting by unit alone would erase
      // earlier legitimate cycles" (e.g. two manually-marked chazara-cycle
      // entries for the same masechta).
      final candidates =
          ledgerEntries
              .where(
                (e) =>
                    e.entryScope == unit.entryScope &&
                    e.unitIdentifier == unit.unitIdentifier &&
                    e.trackType == unit.trackType,
              )
              .toList()
            ..sort((a, b) => b.completionNumber.compareTo(a.completionNumber));
      if (candidates.isEmpty) continue; // never earned — nothing to retract.

      final highest = candidates.first;
      if (highest.purgedAt != null) {
        // The true-highest entry for this unit is ALREADY purged: an
        // earlier call already handled this coverage-loss epoch. Do NOT
        // reach past it to the next-highest entry — that would be exactly
        // the bug this rule fixes. This makes retraction idempotent: once
        // the highest entry is purged, every subsequent call for this unit
        // (while it remains uncovered) sees it purged and stops here,
        // leaving older, genuinely separate completion cycles untouched.
        continue;
      }

      // Owner ruling: only the HIGHEST-completionNumber entry is retracted,
      // regardless of its `source`. `source` is also irrelevant to WHO
      // originally earned this entry: a manually-marked entry (Lifetime
      // Marking screen, `entryScope` values `'level1'`/`'level2'`) is
      // subject to the same epoch rule as an auto-siyum entry
      // (`entryScope` values from [unitScopeFor]: `'masechta'`, `'seder'`,
      // `'siman'`, `'chelek'`, `'hilchos'`, `'sefer'`) if it ever shares this
      // unit's exact `(entryScope, unitIdentifier, trackType)` key — factual
      // coverage governs, not provenance/origin of the entry (owner
      // principle, stated twice). In practice the two vocabularies above are
      // disjoint (verified by grep across `lib/`: `unitScopeFor` never
      // returns `'level1'`/`'level2'`, and the Lifetime Marking screen never
      // writes anything but `'level${n}'`), so this collision cannot
      // currently occur for any shipped curriculum — this is a defence for
      // the rule's generality, not a currently-reachable case.
      await ledgerRepository.purgeEntry(ulid: highest.ulid, purgedAt: purgedAt);
    }
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
